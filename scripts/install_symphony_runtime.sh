#!/usr/bin/env bash
set -euo pipefail

SERVICE_USER="${SERVICE_USER:-symphony}"
STATE_ROOT="${STATE_ROOT:-/var/lib/symphony}"

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

workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT

cd "$workspace"
symphony-playwright install-browser firefox
mkdir -p .playwright
cat >.playwright/cli.config.json <<'JSON'
{
  "browser": {
    "browserName": "firefox"
  }
}
JSON
symphony-playwright open "data:text/html,<title>playwright-cli-ok</title><button>ok</button>" >/dev/null
if ! symphony-playwright snapshot >/dev/null 2>&1; then
  find .playwright-cli -type f -name 'page-*.yml' | grep -q .
fi
symphony-playwright close-all >/dev/null 2>&1 || true
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

runuser -l "$SERVICE_USER" -c 'export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin"; symphony-browser-smoke'

runuser -l "$SERVICE_USER" -c 'export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin"; node --version; npm --version; go version; playwright-cli --version; symphony-playwright --version'
