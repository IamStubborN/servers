#!/usr/bin/env bash
set -euo pipefail

SERVICE_USER="${SERVICE_USER:-symphony}"
STATE_ROOT="${STATE_ROOT:-/var/lib/symphony}"
BROWSER_HEALTH_FILE="${BROWSER_HEALTH_FILE:-$STATE_ROOT/browser-runtime-health.env}"

dnf install -y firefox libX11-xcb

install -d -m 0755 -o "$SERVICE_USER" -g "$SERVICE_USER" "$STATE_ROOT/.config/mise"
cat >"$STATE_ROOT/.config/mise/config.toml" <<'EOF'
[tools]
go = "latest"
node = "24"
python = "3.12"
"npm:@playwright/cli" = "0.1.15"
EOF
chown "$SERVICE_USER:$SERVICE_USER" "$STATE_ROOT/.config/mise/config.toml"
runuser -l "$SERVICE_USER" -c 'export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin"; mise install --yes'

cat >/usr/local/bin/symphony-playwright <<EOF
#!/usr/bin/env bash
set -euo pipefail

if [[ -z "\${XDG_CACHE_HOME:-}" && ! -w "\$PWD" ]]; then
  export XDG_CACHE_HOME="$STATE_ROOT/.cache/xdg"
else
  export XDG_CACHE_HOME="\${XDG_CACHE_HOME:-\$PWD/.cache}"
fi
export PLAYWRIGHT_BROWSERS_PATH="\${PLAYWRIGHT_BROWSERS_PATH:-$STATE_ROOT/.cache/ms-playwright}"

mkdir -p "\$XDG_CACHE_HOME" "\$PLAYWRIGHT_BROWSERS_PATH"
exec playwright-cli "\$@"
EOF
chmod 0755 /usr/local/bin/symphony-playwright

cat >/usr/local/bin/symphony-browser-smoke <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

STATE_ROOT="${STATE_ROOT:-/var/lib/symphony}"
SERVICE_USER="${SERVICE_USER:-symphony}"
HEALTH_FILE="${BROWSER_HEALTH_FILE:-$STATE_ROOT/browser-runtime-health.env}"
workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT
wrapper_health="unknown"
config_health="unknown"
screenshot_health="unknown"
video_health="unknown"
snapshot_health="unknown"

write_health() {
  result="$1"
  reason="$2"
  tmp="$(mktemp)"
  {
    printf "result='%s'\n" "$result"
    printf "reason='%s'\n" "$(printf '%s' "$reason" | sed "s/'/'\\\\''/g")"
    printf "browser='firefox'\n"
    printf "wrapper='symphony-playwright'\n"
    printf "wrapper_health='%s'\n" "$wrapper_health"
    printf "firefox_config_health='%s'\n" "$config_health"
    printf "screenshot_health='%s'\n" "$screenshot_health"
    printf "video_health='%s'\n" "$video_health"
    printf "snapshot_fallback_health='%s'\n" "$snapshot_health"
    printf "recorded_at='%s'\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } >"$tmp"
  install -D -m 0644 "$tmp" "$HEALTH_FILE"
  rm -f "$tmp"
}

trap 'status=$?; if [ "$status" -ne 0 ]; then write_health failed "browser smoke failed with exit $status"; fi; rm -rf "$workspace"; exit "$status"' EXIT

cd "$workspace"
symphony-playwright install-browser firefox
wrapper_health="passed"
mkdir -p artifacts/proof/SMOKE
mkdir -p .playwright
cat >.playwright/cli.config.json <<'JSON'
{
  "browser": {
    "browserName": "firefox"
  }
}
JSON
grep -q '"browserName": "firefox"' .playwright/cli.config.json
config_health="passed"
session="symphony-browser-smoke"
symphony-playwright -s="$session" open "data:text/html,<title>playwright-cli-ok</title><button>ok</button>" >/dev/null
symphony-playwright -s="$session" video-start artifacts/proof/SMOKE/walkthrough.webm >/dev/null
symphony-playwright -s="$session" video-show-actions >/dev/null
symphony-playwright -s="$session" screenshot --filename artifacts/proof/SMOKE/screenshot.png --full-page >/dev/null
if ! symphony-playwright -s="$session" snapshot >/dev/null 2>&1; then
  find .playwright-cli -type f -name 'page-*.yml' | grep -q .
fi
snapshot_health="passed"
symphony-playwright -s="$session" video-stop >/dev/null
test -s artifacts/proof/SMOKE/screenshot.png
screenshot_health="passed"
test -s artifacts/proof/SMOKE/walkthrough.webm
video_health="passed"
symphony-playwright -s="$session" close >/dev/null 2>&1 || true
symphony-playwright close-all >/dev/null 2>&1 || true
write_health passed "browser smoke passed"
EOF
chmod 0755 /usr/local/bin/symphony-browser-smoke

cat >/usr/local/bin/symphony-playwright-config <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

mkdir -p .playwright
cat >.playwright/cli.config.json <<'JSON'
{
  "browser": {
    "browserName": "firefox"
  }
}
JSON
EOF
chmod 0755 /usr/local/bin/symphony-playwright-config

runuser -l "$SERVICE_USER" -c "export STATE_ROOT='$STATE_ROOT' BROWSER_HEALTH_FILE='$BROWSER_HEALTH_FILE' PATH=\"\$HOME/.local/bin:\$HOME/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin\"; symphony-browser-smoke"

runuser -l "$SERVICE_USER" -c 'export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin"; node --version; npm --version; go version; playwright-cli --version; symphony-playwright --version'
