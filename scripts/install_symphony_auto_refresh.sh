#!/usr/bin/env bash
set -euo pipefail

SERVICE_USER="${SERVICE_USER:-symphony}"
SERVICE_NAME="${SERVICE_NAME:-symphony.service}"
STATE_ROOT="${STATE_ROOT:-/var/lib/symphony}"

cat >/usr/local/bin/symphony-agent-flow-refresh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SERVICE_USER="${SERVICE_USER:-symphony}"
SERVICE_NAME="${SERVICE_NAME:-symphony.service}"
STATE_ROOT="${STATE_ROOT:-/var/lib/symphony}"
LOCK_FILE="${LOCK_FILE:-/run/symphony-agent-flow-refresh.lock}"
STATUS_FILE="${STATUS_FILE:-$STATE_ROOT/agent-flow-refresh-status.env}"
RESTART_IF_IDLE=false
RESTART_AFTER_UPDATE=true

for arg in "$@"; do
  case "$arg" in
    --restart-if-idle)
      RESTART_IF_IDLE=true
      ;;
    --no-restart)
      RESTART_AFTER_UPDATE=false
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
current="unknown"
target="unknown"

log() {
  printf 'symphony-agent-flow-refresh: %s\n' "$*"
}

quote_status_value() {
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
}

write_status() {
  result="$1"
  reason="$2"
  status_current="${3:-$current}"
  status_target="${4:-$target}"
  tmp="$(mktemp)"
  {
    printf "result='%s'\n" "$(quote_status_value "$result")"
    printf "reason='%s'\n" "$(quote_status_value "$reason")"
    printf "agent_flow_root='%s'\n" "$(quote_status_value "$AGENT_FLOW_ROOT")"
    printf "agent_flow_ref='%s'\n" "$(quote_status_value "$AGENT_FLOW_REF")"
    printf "agent_flow_commit='%s'\n" "$(quote_status_value "$status_current")"
    printf "target_commit='%s'\n" "$(quote_status_value "$status_target")"
    printf "restart_required='%s'\n" "$(quote_status_value "$RESTART_AFTER_UPDATE")"
    printf "service_name='%s'\n" "$(quote_status_value "$SERVICE_NAME")"
    printf "recorded_at='%s'\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } >"$tmp"
  install -D -m 0644 -o "$SERVICE_USER" -g "$SERVICE_USER" "$tmp" "$STATUS_FILE"
  rm -f "$tmp"
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
    write_status "deferred" "active agent is running; restart deferred: $reason"
    return 0
  fi

  log "restarting $SERVICE_NAME ($reason)"
  if ! systemctl restart "$SERVICE_NAME"; then
    write_status "failed" "service restart failed: $reason"
    exit 0
  fi
  write_status "success" "$reason"
}

(
  flock -n 9 || {
    log "another refresh is already running"
    exit 0
  }

  if [ ! -d "$AGENT_FLOW_ROOT/.git" ]; then
    log "$AGENT_FLOW_ROOT is not a git checkout; asking service restart to run symphony-sync"
    write_status "skipped" "missing agent-flow checkout" "unknown" "unknown"
    restart_when_idle "missing agent-flow checkout"
    exit 0
  fi

  git_as_service config --global --add safe.directory "$AGENT_FLOW_ROOT" || true

  if git_as_service -C "$AGENT_FLOW_ROOT" remote get-url origin >/dev/null 2>&1; then
    git_as_service -C "$AGENT_FLOW_ROOT" remote set-url origin "$AGENT_FLOW_REPO_URL"
  else
    git_as_service -C "$AGENT_FLOW_ROOT" remote add origin "$AGENT_FLOW_REPO_URL"
  fi

  if ! git_as_service -C "$AGENT_FLOW_ROOT" fetch --prune origin "$AGENT_FLOW_REF"; then
    current="$(git_as_service -C "$AGENT_FLOW_ROOT" rev-parse HEAD 2>/dev/null || printf unknown)"
    write_status "failed" "fetch failed; keeping last-known-good checkout" "$current" "unknown"
    exit 0
  fi

  current="$(git_as_service -C "$AGENT_FLOW_ROOT" rev-parse HEAD)"
  target="$(git_as_service -C "$AGENT_FLOW_ROOT" rev-parse FETCH_HEAD)"

  if [ "$current" = "$target" ]; then
    if [ "$RESTART_IF_IDLE" = true ]; then
      restart_when_idle "bootstrap requested"
    else
      log "already current at $current"
      if [ -f "$STATUS_FILE" ] && grep -q "^result='failed'$" "$STATUS_FILE" && grep -q "service restart failed" "$STATUS_FILE"; then
        restart_when_idle "retry after failed restart"
      else
        write_status "already-current" "no restart requested"
      fi
    fi
    exit 0
  fi

  if has_active_agents; then
    log "update pending $current -> $target; active agent is running"
    write_status "deferred" "update pending; active agent is running"
    exit 0
  fi

  log "updating $AGENT_FLOW_ROOT $current -> $target"
  if ! git_as_service -C "$AGENT_FLOW_ROOT" clean -fd; then
    write_status "failed" "clean failed; keeping last-known-good checkout"
    exit 0
  fi
  if ! git_as_service -C "$AGENT_FLOW_ROOT" checkout -B "$AGENT_FLOW_REF" "$target"; then
    write_status "failed" "checkout failed; keeping last-known-good checkout"
    exit 0
  fi
  if ! git_as_service -C "$AGENT_FLOW_ROOT" reset --hard "$target"; then
    git_as_service -C "$AGENT_FLOW_ROOT" checkout -B "$AGENT_FLOW_REF" "$current" >/dev/null 2>&1 || true
    git_as_service -C "$AGENT_FLOW_ROOT" reset --hard "$current" >/dev/null 2>&1 || true
    write_status "failed" "reset failed; keeping last-known-good checkout"
    exit 0
  fi
  chown -R "$SERVICE_USER:$SERVICE_USER" "$AGENT_FLOW_ROOT"
  current="$target"
  if [ "$RESTART_AFTER_UPDATE" = true ]; then
    restart_when_idle "agent-flow updated"
  else
    write_status "success" "agent-flow updated; restart not requested"
  fi
) 9>"$LOCK_FILE"
EOF

chmod 0755 /usr/local/bin/symphony-agent-flow-refresh

cat >/usr/local/bin/symphony-promote-ready-wave <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ -f /etc/symphony/env ]; then
  set -a
  . /etc/symphony/env
  set +a
fi

AGENT_FLOW_ROOT="${AGENT_FLOW_ROOT:-/opt/agent-flow}"
PROMOTE_LIMIT="${READY_WAVE_PROMOTE_LIMIT:-4}"

if [ ! -x "$AGENT_FLOW_ROOT/scripts/promote-ready-wave.py" ]; then
  echo "symphony-promote-ready-wave: missing $AGENT_FLOW_ROOT/scripts/promote-ready-wave.py" >&2
  exit 0
fi

exec "$AGENT_FLOW_ROOT/scripts/promote-ready-wave.py" --apply --quiet --limit "$PROMOTE_LIMIT"
EOF

chmod 0755 /usr/local/bin/symphony-promote-ready-wave

cat >/etc/systemd/system/symphony-agent-flow-refresh.service <<EOF
[Unit]
Description=Refresh Agent Flow and restart Symphony when idle
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
Environment=SERVICE_USER=$SERVICE_USER
Environment=SERVICE_NAME=$SERVICE_NAME
Environment=STATE_ROOT=$STATE_ROOT
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

cat >/etc/systemd/system/symphony-promote-ready-wave.service <<EOF
[Unit]
Description=Promote unblocked Linear issues into the Symphony ready queue
Wants=network-online.target
After=network-online.target
ConditionPathExists=/etc/symphony/env

[Service]
Type=oneshot
User=$SERVICE_USER
Group=$SERVICE_USER
EnvironmentFile=/etc/symphony/env
Environment=PATH=/var/lib/symphony/.local/bin:/var/lib/symphony/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/local/bin/symphony-promote-ready-wave
EOF

cat >/etc/systemd/system/symphony-promote-ready-wave.timer <<'EOF'
[Unit]
Description=Periodically promote ready Linear issues for Symphony

[Timer]
OnBootSec=3min
OnUnitActiveSec=1min
RandomizedDelaySec=15s
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now symphony-agent-flow-refresh.timer
systemctl enable --now symphony-promote-ready-wave.timer
