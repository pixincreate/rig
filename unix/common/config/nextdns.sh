#!/bin/bash

set -e

setup_nextdns() {
    local config_id="${1:-}"
    local device_name="${2:-$(hostname -s)}"

    echo "Configuring NextDNS"

    if [[ -z "$config_id" ]] && [[ -n "${RIG_NEXTDNS_ID:-}" ]]; then
        config_id="$RIG_NEXTDNS_ID"
        echo "[INFO] Using NextDNS config ID from RIG_NEXTDNS_ID"
    fi

    if [[ -z "$config_id" ]]; then
        echo "[INFO] Get your NextDNS configuration ID from: https://my.nextdns.io"
        read -r -p "Enter your NextDNS config ID (or press Enter to skip): " config_id

        if [[ -z "$config_id" ]]; then
            echo "[INFO] No NextDNS config ID provided, skipping"
            return 0
        fi
    fi

    if [[ ! "$config_id" =~ ^[a-zA-Z0-9]{6}$ ]]; then
        echo "[ERROR] Invalid NextDNS config ID format"
        echo "[ERROR] Expected format: 6 alphanumeric characters (e.g., abc123)"
        return 1
    fi

    # NextDNS device names may only contain a-z, A-Z, 0-9, and -. Spaces are encoded as --.
    device_name=${device_name// /--}
    if [[ ! "$device_name" =~ ^[a-zA-Z0-9-]+$ ]]; then
        echo "[ERROR] Invalid NextDNS device name: $device_name"
        echo "[ERROR] Only a-z, A-Z, 0-9, and - are allowed"
        return 1
    fi

    case "$OSTYPE" in
    linux*)
        setup_nextdns_systemd_resolved "$config_id" "$device_name"
        ;;
    darwin*)
        setup_nextdns_macos_cli "$config_id" "$device_name"
        ;;
    *)
        echo "[ERROR] Unsupported OS: $OSTYPE"
        return 1
        ;;
    esac
}

setup_nextdns_systemd_resolved() {
    local config_id="$1"
    local device_name="$2"
    local endpoint="${device_name}-${config_id}.dns.nextdns.io"

    echo "[INFO] Configuring NextDNS via systemd-resolved"
    echo "[INFO] Device name: $device_name"
    echo "[INFO] Endpoint: $endpoint"

    if ! command -v resolvectl &>/dev/null; then
        echo "[ERROR] resolvectl not found. Is systemd-resolved installed?"
        return 1
    fi

    local resolved_dir="/etc/systemd/resolved.conf.d"
    local resolved_conf="$resolved_dir/nextdns.conf"

    if [[ $EUID -eq 0 ]]; then
        mkdir -p "$resolved_dir"
        cat >"$resolved_conf" <<EOF
[Resolve]
DNS=45.90.28.0#${endpoint}
DNS=2a07:a8c0::#${endpoint}
DNS=45.90.30.0#${endpoint}
DNS=2a07:a8c1::#${endpoint}
DNSOverTLS=yes
FallbackDNS=
EOF
        systemctl restart systemd-resolved
    else
        if command -v sudo &>/dev/null; then
            sudo mkdir -p "$resolved_dir"
            sudo tee "$resolved_conf" >/dev/null <<EOF
[Resolve]
DNS=45.90.28.0#${endpoint}
DNS=2a07:a8c0::#${endpoint}
DNS=45.90.30.0#${endpoint}
DNS=2a07:a8c1::#${endpoint}
DNSOverTLS=yes
FallbackDNS=
EOF
            sudo systemctl restart systemd-resolved
        else
            echo "[ERROR] This command requires root privileges"
            return 1
        fi
    fi

    echo "[SUCCESS] NextDNS configured via systemd-resolved"
    echo "[INFO] Verify with: resolvectl status"
}

setup_nextdns_macos_cli() {
    local config_id="$1"
    local device_name="$2"

    echo "[INFO] macOS detected. Using NextDNS CLI."

    if ! command -v nextdns &>/dev/null; then
        echo "[ERROR] nextdns command not found"
        echo "[INFO] Install with: brew install nextdns/tap/nextdns"
        return 1
    fi

    echo "[INFO] Installing NextDNS CLI with config ID: $config_id"
    echo "[INFO] Device name will be reported as: $device_name"

    if [[ $EUID -eq 0 ]]; then
        nextdns install -config "$config_id" -setup-router=false -report-client-info=true -log-queries=false -auto-activate
    else
        if command -v sudo &>/dev/null; then
            sudo nextdns install -config "$config_id" -setup-router=false -report-client-info=true -log-queries=false -auto-activate
        else
            echo "[ERROR] This command requires root privileges"
            return 1
        fi
    fi

    echo "[SUCCESS] NextDNS CLI configured with ID: $config_id"
}
