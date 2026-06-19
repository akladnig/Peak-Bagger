#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

log "Preparing local production setup"
ensure_prerequisites
ensure_certificate
ensure_hosts_entry
ensure_apache_modules
install_apache_vhost
install_launch_agent
restart_launch_agent
restart_apache
verify_health

log "Setup complete"
