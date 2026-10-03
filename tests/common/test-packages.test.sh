#!/bin/bash
# Unit tests for unix/common/helpers/packages.sh and the pkg commands.
# Uses stub rpm/dnf/sudo so it runs on any machine.

section "packages.sh stub environment"
STUB_BIN="$(mktemp -d)"
PACKAGES_DIR="$(mktemp -d)"
STATE="$STUB_BIN/installed.state"
touch "$STATE"
export PATH="$STUB_BIN:$PATH"
export RIG_PLATFORM=fedora
export PACKAGES_DIR

# rpm -q NAME: succeeds iff NAME is in the state file
cat >"$STUB_BIN/rpm" <<EOF
#!/bin/bash
[[ "\$1" == "-q" ]] && grep -qxF "\$2" "$STATE"
EOF

# dnf repoquery --userinstalled: report state as explicitly-installed packages
cat >"$STUB_BIN/dnf" <<EOF
#!/bin/bash
if [[ "\$1" == "repoquery" ]]; then
  cat "$STATE"
  exit 0
fi
op=""
pkg=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    install) op=install ;;
    remove|erase) op=remove ;;
    -y|--best|--allowerasing|-q) ;;
    *) pkg="\$1" ;;
  esac
  shift
done
if [[ "\$op" == "install" ]]; then
  echo "\$pkg" >> "$STATE"
else
  grep -Fxv "\$pkg" "$STATE" > "$STATE.tmp" || true
  mv "$STATE.tmp" "$STATE"
fi
EOF

printf '#!/bin/bash\nexec "$@"\n' >"$STUB_BIN/sudo"
# no-op npm/cargo: keeps the drift reverse scan hermetic (no real manager data)
printf '#!/bin/bash\nexit 0\n' >"$STUB_BIN/npm"
printf '#!/bin/bash\ncase "$1" in install) exit 1 ;; *) exit 0 ;; esac\n' >"$STUB_BIN/cargo"
chmod +x "$STUB_BIN/rpm" "$STUB_BIN/dnf" "$STUB_BIN/sudo" "$STUB_BIN/npm" "$STUB_BIN/cargo"

PKG_ADD="$RIG_REPO/unix/common/libexec/rig-pkg-add"
PKG_REMOVE="$RIG_REPO/unix/common/libexec/rig-pkg-remove"

section "rig pkg-add updates list AND system"
assert_success "pkg-add base hello" bash "$PKG_ADD" base hello
assert_success "hello recorded in base.packages" grep -qxF "hello" "$PACKAGES_DIR/base.packages"
assert_success "hello installed via backend" grep -qxF "hello" "$STATE"

bash "$PKG_ADD" base hello &>/dev/null || true
assert_success "re-add does not duplicate list entry" test "$(grep -cxF hello "$PACKAGES_DIR/base.packages")" -eq 1

assert_success "dev alias writes development.packages" bash "$PKG_ADD" dev devtool
assert_success "devtool recorded in development.packages" grep -qxF "devtool" "$PACKAGES_DIR/development.packages"

section "rig pkg-remove updates system AND list"
assert_success "pkg-remove base hello" bash "$PKG_REMOVE" base hello
assert_failure "hello uninstalled via backend" grep -qxF "hello" "$STATE"
assert_failure "hello removed from base.packages" grep -qxF "hello" "$PACKAGES_DIR/base.packages"

section "type validation"
INVALID_OUTPUT=$(bash "$PKG_ADD" bogus pkg 2>&1 || true)
assert_output_contains "rejects unknown type" "Unknown package type" echo "$INVALID_OUTPUT"

section "hostile package names are rejected"
BAD_OUTPUT=$(bash "$PKG_ADD" base --refresh 2>&1 || true)
assert_output_contains "rejects flag-like name" "Invalid package name" echo "$BAD_OUTPUT"
assert_failure "flag-like name not written to list" grep -Fqx -- "--refresh" "$PACKAGES_DIR/base.packages"

section "invalid platform rejected"
PLAT_OUTPUT=$(RIG_PLATFORM=../../etc bash -c "source '$RIG_REPO/unix/common/helpers/platform.sh'; source '$RIG_REPO/unix/common/helpers/packages.sh'; pkg_platform" 2>&1 || true)
assert_output_contains "pkg_platform whitelists platform" "Invalid platform" echo "$PLAT_OUTPUT"

section "rig drift detects declared-but-missing"
printf '# a comment\n\ninstalled-thing\nmissing-thing\n' >"$PACKAGES_DIR/base.packages"
echo "installed-thing" >"$STATE"
DRIFT_OUTPUT=$(NON_INTERACTIVE=true bash "$RIG_REPO/unix/common/libexec/rig-drift" 2>&1) && DRIFT_RC=0 || DRIFT_RC=$?
assert_output_contains "reports drift section" "Drift report (fedora)" echo "$DRIFT_OUTPUT"
assert_output_contains "names missing package" "missing-thing" echo "$DRIFT_OUTPUT"
assert_success "dry run exits nonzero when drifted" test "$DRIFT_RC" -ne 0
assert_output_not_contains "dry run does not converge" "Converging" echo "$DRIFT_OUTPUT"

echo "installed-thing" >"$STATE"
echo "devtool" >>"$STATE"
printf '# a comment\n\ninstalled-thing\n' >"$PACKAGES_DIR/base.packages"
DRIFT_CLEAN=$(NON_INTERACTIVE=true bash "$RIG_REPO/unix/common/libexec/rig-drift" 2>&1) && DRIFT_CLEAN_RC=0 || DRIFT_CLEAN_RC=$?
assert_output_contains "clean system reports no drift" "No drift" echo "$DRIFT_CLEAN"
assert_success "clean system exits zero" test "$DRIFT_CLEAN_RC" -eq 0

section "drift reverse scan: installed-but-undeclared"
printf 'installed-thing\n' >"$PACKAGES_DIR/base.packages"
echo "installed-thing" >"$STATE"
echo "sneaky-extra" >>"$STATE" # present on system, absent from list
EXTRA_OUTPUT=$(NON_INTERACTIVE=true bash "$RIG_REPO/unix/common/libexec/rig-drift" 2>&1) && EXTRA_RC=0 || EXTRA_RC=$?
assert_output_contains "reports undeclared section" "[undeclared in base]" echo "$EXTRA_OUTPUT"
assert_output_contains "names the undeclared package" "sneaky-extra" echo "$EXTRA_OUTPUT"
assert_failure "undeclared packages make drift nonzero" test "$EXTRA_RC" -eq 0
assert_output_not_contains "reverse scan never uninstalls" "Removing" echo "$EXTRA_OUTPUT"
echo "installed-thing" >"$STATE" # restore clean state

section "setup module mapping"
MAP_CMD="source '$RIG_REPO/unix/common/helpers/platform.sh'; source '$RIG_REPO/unix/common/helpers/packages.sh'"
assert_output_eq "development maps to packaging/base" "base" bash -c "$MAP_CMD; pkg_setup_module development"
assert_output_eq "base maps to its own module" "base" bash -c "$MAP_CMD; pkg_setup_module base"
assert_output_eq "flatpak maps to its own module" "flatpak" bash -c "$MAP_CMD; pkg_setup_module flatpak"

rm -rf "$STUB_BIN" "$PACKAGES_DIR"
unset PACKAGES_DIR RIG_PLATFORM
PATH="${PATH#"$STUB_BIN:"}"
