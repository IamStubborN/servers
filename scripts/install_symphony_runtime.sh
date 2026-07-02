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

cat >/usr/local/bin/symphony-browser-smoke <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT

cd "$workspace"
playwright-cli install-browser firefox
mkdir -p .playwright
cat >.playwright/cli.config.json <<'JSON'
{
  "browser": {
    "browserName": "firefox"
  }
}
JSON
playwright-cli open "data:text/html,<title>playwright-cli-ok</title><button>ok</button>"
playwright-cli snapshot >/dev/null
playwright-cli close-all
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

runuser -l "$SERVICE_USER" -c 'export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin"; node --version; npm --version; go version; playwright-cli --version'
