#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_PROD_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROXY_ROOT="$(cd "$LOCAL_PROD_DIR/.." && pwd)"
HOME_DIR="$HOME"

readonly SCRIPT_DIR
readonly LOCAL_PROD_DIR
readonly PROXY_ROOT
readonly HOME_DIR

readonly HOSTNAME="tiles.peakbagger.com"
readonly PROXY_PORT="8080"
readonly CERT_DIR="$LOCAL_PROD_DIR/certs"
readonly CERT_FILE="$CERT_DIR/$HOSTNAME.pem"
readonly KEY_FILE="$CERT_DIR/$HOSTNAME-key.pem"
readonly APACHE_HTTPD_CONF="/private/etc/apache2/httpd.conf"
readonly APACHE_VHOST_TARGET="/private/etc/apache2/other/$HOSTNAME.conf"
readonly APACHE_VHOST_TEMPLATE="$LOCAL_PROD_DIR/apache/tiles.peakbagger.com.conf"
readonly LAUNCH_AGENT_LABEL="com.peakbagger.slovenia-topo-proxy"
readonly LAUNCH_AGENT_TEMPLATE="$LOCAL_PROD_DIR/launchd/$LAUNCH_AGENT_LABEL.plist"
readonly LAUNCH_AGENT_TARGET="$HOME_DIR/Library/LaunchAgents/$LAUNCH_AGENT_LABEL.plist"
readonly PROXY_HEALTH_URL="http://127.0.0.1:$PROXY_PORT/slovenia-topo/16/35325/23389.png"
readonly HOSTNAME_HEALTH_URL="https://$HOSTNAME/slovenia-topo/16/35325/23389.png"
readonly SOURCE_PROXY_ROOT="/Users/adrian/Development/mapping/peak_bagger/proxy/slovenia-topo-proxy"
readonly SOURCE_HOME="/Users/adrian"

log() {
  printf '[slovenia-topo] %s\n' "$*"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

ensure_prerequisites() {
  require_command mkcert
  require_command dart
  require_command apachectl
  require_command curl
  require_command perl
}

render_template() {
  local src="$1"
  local dest="$2"

  perl -0pe "s#\Q$SOURCE_PROXY_ROOT\E#$PROXY_ROOT#g; s#\Q$SOURCE_HOME\E#$HOME_DIR#g" "$src" > "$dest"
}

ensure_certificate() {
  mkdir -p "$CERT_DIR"
  if [[ -f "$CERT_FILE" && -f "$KEY_FILE" ]]; then
    log "Using existing certificate in $CERT_DIR"
    return
  fi

  log "Generating local certificate for $HOSTNAME"
  mkcert -cert-file "$CERT_FILE" -key-file "$KEY_FILE" "$HOSTNAME"
}

ensure_hosts_entry() {
  if grep -Eq '(^|[[:space:]])127\.0\.0\.1[[:space:]]+tiles\.peakbagger\.com($|[[:space:]])' /etc/hosts; then
    log "Hosts entry already present"
    return
  fi

  log "Adding $HOSTNAME to /etc/hosts"
  printf '127.0.0.1 %s\n' "$HOSTNAME" | sudo tee -a /etc/hosts >/dev/null
}

ensure_apache_modules() {
  log "Ensuring Apache proxy and SSL modules are enabled"
  sudo cp "$APACHE_HTTPD_CONF" "$APACHE_HTTPD_CONF.peakbagger-backup" 2>/dev/null || true
  sudo perl -0pi -e 's/^#LoadModule proxy_module libexec\/apache2\/mod_proxy\.so$/LoadModule proxy_module libexec\/apache2\/mod_proxy.so/m' "$APACHE_HTTPD_CONF"
  sudo perl -0pi -e 's/^#LoadModule proxy_http_module libexec\/apache2\/mod_proxy_http\.so$/LoadModule proxy_http_module libexec\/apache2\/mod_proxy_http.so/m' "$APACHE_HTTPD_CONF"
  sudo perl -0pi -e 's/^#LoadModule ssl_module libexec\/apache2\/mod_ssl\.so$/LoadModule ssl_module libexec\/apache2\/mod_ssl.so/m' "$APACHE_HTTPD_CONF"
}

install_apache_vhost() {
  log "Installing Apache vhost to $APACHE_VHOST_TARGET"
  local tmp
  tmp="$(mktemp)"
  render_template "$APACHE_VHOST_TEMPLATE" "$tmp"
  sudo install -m 644 "$tmp" "$APACHE_VHOST_TARGET"
  rm -f "$tmp"
}

install_launch_agent() {
  log "Installing launch agent to $LAUNCH_AGENT_TARGET"
  mkdir -p "$(dirname "$LAUNCH_AGENT_TARGET")"
  local tmp
  tmp="$(mktemp)"
  render_template "$LAUNCH_AGENT_TEMPLATE" "$tmp"
  install -m 644 "$tmp" "$LAUNCH_AGENT_TARGET"
  rm -f "$tmp"
}

restart_launch_agent() {
  log "Restarting launch agent $LAUNCH_AGENT_LABEL"
  launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT_TARGET" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT_TARGET"
}

restart_apache() {
  log "Restarting Apache"
  sudo apachectl -k restart || sudo apachectl start
}

verify_health() {
  log "Checking proxy health"
  curl --fail --silent --show-error --head --max-time 60 "$PROXY_HEALTH_URL" >/dev/null
  log "Checking hostname health"
  curl --fail --silent --show-error --head --max-time 60 "$HOSTNAME_HEALTH_URL" >/dev/null
  log "Local production setup is healthy"
}
