#!/bin/bash

set -eEuo pipefail

# Apply all system configurations

log_section "System Configuration"

run_logged "$RIG_INSTALL/config/system.sh"
run_logged "$RIG_INSTALL/config/appimage.sh"
run_logged "$RIG_INSTALL/config/firmware.sh"
run_logged "$RIG_INSTALL/config/git.sh"
run_logged "$RIG_INSTALL/config/services.sh"
run_logged "$RIG_INSTALL/config/keepass.sh"
run_logged "$RIG_INSTALL/config/multimedia.sh"
run_logged "$RIG_INSTALL/config/performance.sh"
run_logged "$RIG_INSTALL/config/hibernation.sh"
run_logged "$RIG_INSTALL/config/hardware/all.sh"
run_logged "$RIG_INSTALL/config/nextdns.sh"
run_logged "$RIG_INSTALL/config/secureboot.sh"
run_logged "$RIG_INSTALL/config/kde.sh"

log_success "All system configurations applied"
