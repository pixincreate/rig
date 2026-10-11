#!/bin/bash
# KeePass database sync to Filen through rclone bisync, driven by systemd units.
#
# This module installs two user units and nothing else:
#   keepass-filen-sync.service  runs rclone bisync
#   keepass-filen-sync.path     starts the service when the database folder changes
#
# The machine-specific values are NOT in this repository. They are read from an
# untracked file, ~/.config/rig/keepass.local.json:
#
#   {
#     "mountpoint": "/path/to/mount",
#     "dir": "/path/to/database/dir",
#     "db": "keepass.kdbx",
#     "remote": "filen:vault",
#     "local_backup_dir": "/path/to/local/backups",
#     "remote_backup_dir": "filen:backups"
#   }
#
# The rclone remote must exist before this module runs. It holds the
# credentials. This module never reads or writes rclone.conf.
#
# Without that local file the module stops with a warning, because a wrong path
# here could delete a real database.

echo "Configuring KeePass <-> Filen sync"

values_dir="$(expand_path "$(get_config '.directories.config')")/rig"
local_values="$values_dir/keepass.local.json"

if [[ ! -f $local_values ]]; then
  log_warning "Missing $local_values"
  log_warning "Create it with mountpoint, dir, db, remote and the two backup dirs"
  log_warning "Skipped KeePass <-> Filen sync"
  return 0
fi

mountpoint="$(jq -r '.mountpoint // empty' "$local_values" 2>/dev/null || true)"
db_dir="$(jq -r '.dir // empty' "$local_values" 2>/dev/null || true)"
db_name="$(jq -r '.db // empty' "$local_values" 2>/dev/null || true)"
remote="$(jq -r '.remote // empty' "$local_values" 2>/dev/null || true)"
local_backup_dir="$(jq -r '.local_backup_dir // empty' "$local_values" 2>/dev/null || true)"
remote_backup_dir="$(jq -r '.remote_backup_dir // empty' "$local_values" 2>/dev/null || true)"

if [[ -z $mountpoint || -z $db_dir || -z $db_name || -z $remote || -z $local_backup_dir || -z $remote_backup_dir ]]; then
  log_warning "Incomplete values in $local_values"
  log_warning "Required keys: mountpoint, dir, db, remote, local_backup_dir, remote_backup_dir"
  log_warning "Skipped KeePass <-> Filen sync"
  return 0
fi

user_systemd_dir="$(expand_path "$(get_config '.directories.config')")/systemd/user"
mkdir -p "$user_systemd_dir"

service_unit="$user_systemd_dir/keepass-filen-sync.service"
tee "$service_unit" > /dev/null <<EOF
[Unit]
Description=Sync KeePass database with Filen (rclone bisync)
Documentation=https://rclone.org/bisync/
# Never mistake an unmounted vault for a deleted database: if the mountpoint is
# not mounted, or the database is missing, the unit is skipped instead of run.
ConditionPathIsMountPoint=$mountpoint
ConditionPathExists=$db_dir/$db_name
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
# flock serialises runs. The unit starts at login and from the path unit, so the
# lock stops two runs from overlapping.
#
# --include matches the database and any bisync conflict copy, so a conflict is
# visible on both sides instead of stranded on one.
#
# --force is required because bisync aborts when every file on a side changed,
# which is always true for a one-file sync. The dangerous case, an empty or
# unreachable remote, is still blocked by bisync's own "empty current listing"
# check, which --force does not bypass.
#
# A version that gets replaced or deleted is archived under the backup dirs.
ExecStart=/usr/bin/flock -w 60 %t/keepass-filen-sync.lock \\
    /usr/bin/rclone bisync $db_dir $remote \\
    --include=${db_name%.kdbx}*.kdbx \\
    --backup-dir1=$local_backup_dir/last \\
    --backup-dir2=$remote_backup_dir/last \\
    --force \\
    --log-level=INFO
Nice=10
IOSchedulingClass=idle

[Install]
WantedBy=default.target
EOF
chmod 0644 "$service_unit"

path_unit="$user_systemd_dir/keepass-filen-sync.path"
tee "$path_unit" > /dev/null <<EOF
[Unit]
Description=Sync the KeePass database with Filen when the database folder changes

[Path]
# KeePassXC saves with QSaveFile: it writes a temporary file and renames it over
# the database. A watch on the database file itself would die with that rename,
# so watch the folder instead. Every save, and every sync that writes, starts
# one run of the service.
PathChanged=$db_dir
Unit=keepass-filen-sync.service

[Install]
WantedBy=default.target
EOF
chmod 0644 "$path_unit"

log_info "Wrote $service_unit"
log_info "Wrote $path_unit"

if cmd_exists systemctl; then
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable --now keepass-filen-sync.path 2>/dev/null ||
    log_warning "Enable keepass-filen-sync.path after login"
  systemctl --user enable --now keepass-filen-sync.service 2>/dev/null ||
    log_warning "Enable keepass-filen-sync.service after login"
fi

log_success "KeePass <-> Filen sync configured"
