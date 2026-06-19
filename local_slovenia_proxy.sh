#!/usr/bin/env bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
proxy_dir="$script_dir/proxy/slovenia-topo-proxy"
proxy_port="${SLOVENIA_TOPO_PROXY_PORT:-8080}"
proxy_health_url="http://127.0.0.1:${proxy_port}/slovenia-topo/ping"
proxy_log_path="$script_dir/.dart_tool/slovenia_topo_proxy.log"
proxy_pid_path="$script_dir/.dart_tool/slovenia_topo_proxy.pid"

proxy_is_ready() {
  local status
  status="$(curl -s -o /dev/null -w '%{http_code}' "$proxy_health_url" || true)"
  [ "$status" = "400" ]
}

proxy_pid() {
  if [ ! -f "$proxy_pid_path" ]; then
    return 1
  fi

  local pid
  pid="$(tr -d '[:space:]' < "$proxy_pid_path")"
  if [ -z "$pid" ]; then
    return 1
  fi

  printf '%s\n' "$pid"
}

managed_proxy_is_running() {
  local pid
  pid="$(proxy_pid)" || return 1
  kill -0 "$pid" 2>/dev/null
}

forget_proxy_pid() {
  rm -f "$proxy_pid_path"
}

start_managed_proxy() {
  mkdir -p "$script_dir/.dart_tool"

  if managed_proxy_is_running; then
    printf 'Slovenia proxy already running with PID %s\n' "$(proxy_pid)"
    return 0
  fi

  forget_proxy_pid

  if proxy_is_ready; then
    printf 'Using existing unmanaged Slovenia proxy on port %s\n' "$proxy_port"
    return 0
  fi

  (
    cd "$proxy_dir"
    PORT="$proxy_port" dart run bin/server.dart
  ) >"$proxy_log_path" 2>&1 &

  local pid="$!"
  printf '%s\n' "$pid" > "$proxy_pid_path"

  for _ in {1..30}; do
    if proxy_is_ready; then
      printf 'Started Slovenia proxy on port %s (PID %s)\n' "$proxy_port" "$pid"
      return 0
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      forget_proxy_pid
      printf 'Slovenia proxy exited early. Check %s\n' "$proxy_log_path" >&2
      return 1
    fi
    sleep 0.5
  done

  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi
  forget_proxy_pid
  printf 'Slovenia proxy did not become ready. Check %s\n' "$proxy_log_path" >&2
  return 1
}

stop_managed_proxy() {
  if ! managed_proxy_is_running; then
    forget_proxy_pid
    if proxy_is_ready; then
      printf 'A Slovenia proxy is running on port %s, but it is not managed by this repo helper.\n' "$proxy_port" >&2
      return 1
    fi
    printf 'No managed Slovenia proxy is running.\n'
    return 0
  fi

  local pid
  pid="$(proxy_pid)"
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  forget_proxy_pid
  printf 'Stopped Slovenia proxy (PID %s)\n' "$pid"
}
