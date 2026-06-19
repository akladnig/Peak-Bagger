#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

log "Refreshing installed configs and restarting services"
ensure_prerequisites
install_apache_vhost
install_launch_agent
restart_launch_agent
restart_apache
verify_health

log "Restart complete"
