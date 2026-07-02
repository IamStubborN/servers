#!/usr/bin/env bash
set -euo pipefail

SERVICE_USER="${SERVICE_USER:-symphony}"
SERVICE_NAME="${SERVICE_NAME:-symphony.service}"

cat >/usr/local/bin/symphony-agent-flow-refresh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SERVICE_USER="${SERVICE_USER:-symphony}"
SERVICE_NAME="${SERVICE_NAME:-symphony.service}"
LOCK_FILE="${LOCK_FILE:-/run/symphony-agent-flow-refresh.lock}"
RESTART_IF_IDLE=false

for arg in "$@"; do
  case "$arg" in
    --restart-if-idle)
      RESTART_IF_IDLE=true
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

if [ -f /etc/symphony/env ]; then
  set -a
  . /etc/symphony/env
  set +a
fi

AGENT_FLOW_ROOT="${AGENT_FLOW_ROOT:-/opt/agent-flow}"
AGENT_FLOW_REF="${AGENT_FLOW_REF:-main}"
AGENT_FLOW_REPO_URL="${AGENT_FLOW_REPO_URL:-git@github.com:AttentionWorld/agent-flow.git}"
SERVICE_HOME="$(getent passwd "$SERVICE_USER" | cut -d: -f6)"

log() {
  printf 'symphony-agent-flow-refresh: %s\n' "$*"
}

run_as_service() {
  runuser -u "$SERVICE_USER" -- env HOME="$SERVICE_HOME" "$@"
}

git_as_service() {
  run_as_service git "$@"
}

has_active_agents() {
  systemctl is-active --quiet "$SERVICE_NAME" || return 1
  pgrep -u "$SERVICE_USER" -f 'codex .*app-server' >/dev/null 2>&1
}

restart_when_idle() {
  reason="$1"

  if has_active_agents; then
    log "deferred restart: active agent is running ($reason)"
    return 0
  fi

  log "restarting $SERVICE_NAME ($reason)"
  systemctl restart "$SERVICE_NAME"
}

(
  flock -n 9 || {
    log "another refresh is already running"
    exit 0
  }

  if [ ! -d "$AGENT_FLOW_ROOT/.git" ]; then
    log "$AGENT_FLOW_ROOT is not a git checkout; asking service restart to run symphony-sync"
    restart_when_idle "missing agent-flow checkout"
    exit 0
  fi

  git_as_service config --global --add safe.directory "$AGENT_FLOW_ROOT" || true

  if git_as_service -C "$AGENT_FLOW_ROOT" remote get-url origin >/dev/null 2>&1; then
    git_as_service -C "$AGENT_FLOW_ROOT" remote set-url origin "$AGENT_FLOW_REPO_URL"
  else
    git_as_service -C "$AGENT_FLOW_ROOT" remote add origin "$AGENT_FLOW_REPO_URL"
  fi

  git_as_service -C "$AGENT_FLOW_ROOT" fetch --prune origin "$AGENT_FLOW_REF"

  current="$(git_as_service -C "$AGENT_FLOW_ROOT" rev-parse HEAD)"
  target="$(git_as_service -C "$AGENT_FLOW_ROOT" rev-parse FETCH_HEAD)"

  if [ "$current" = "$target" ]; then
    if [ "$RESTART_IF_IDLE" = true ]; then
      restart_when_idle "bootstrap requested"
    else
      log "already current at $current"
    fi
    exit 0
  fi

  if has_active_agents; then
    log "update pending $current -> $target; active agent is running"
    exit 0
  fi

  log "updating $AGENT_FLOW_ROOT $current -> $target"
  git_as_service -C "$AGENT_FLOW_ROOT" checkout -B "$AGENT_FLOW_REF" "$target"
  git_as_service -C "$AGENT_FLOW_ROOT" reset --hard "$target"
  chown -R "$SERVICE_USER:$SERVICE_USER" "$AGENT_FLOW_ROOT"
  restart_when_idle "agent-flow updated"
) 9>"$LOCK_FILE"
EOF

chmod 0755 /usr/local/bin/symphony-agent-flow-refresh

cat >/etc/systemd/system/symphony-agent-flow-refresh.service <<EOF
[Unit]
Description=Refresh Agent Flow and restart Symphony when idle
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
Environment=SERVICE_USER=$SERVICE_USER
Environment=SERVICE_NAME=$SERVICE_NAME
ExecStart=/usr/local/bin/symphony-agent-flow-refresh
EOF

cat >/etc/systemd/system/symphony-agent-flow-refresh.timer <<'EOF'
[Unit]
Description=Periodically refresh Agent Flow for Symphony

[Timer]
OnBootSec=2min
OnUnitActiveSec=2min
RandomizedDelaySec=30s
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now symphony-agent-flow-refresh.timer
