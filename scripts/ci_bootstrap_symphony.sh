#!/usr/bin/env bash
set -euo pipefail

required_env=(
  OCI_SSH_PRIVATE_KEY
  SYMPHONY_CODEX_AUTH_JSON_B64
  SYMPHONY_GITHUB_SSH_PRIVATE_KEY
  SYMPHONY_GITHUB_TOKEN
  SYMPHONY_LINEAR_API_KEY
)

for name in "${required_env[@]}"; do
  if [ -z "${!name:-}" ]; then
    echo "Missing required environment variable: $name" >&2
    exit 1
  fi
done

public_ip="$(tofu output -raw oracle_public_ip)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

decode_base64() {
  if base64 --decode >/dev/null 2>&1 <<<""; then
    base64 --decode
  else
    base64 -D
  fi
}

shell_quote() {
  printf "%q" "$1"
}

printf "%s\n" "$OCI_SSH_PRIVATE_KEY" >"$tmp_dir/opc_ssh_key"
chmod 600 "$tmp_dir/opc_ssh_key"

printf "%s" "$SYMPHONY_CODEX_AUTH_JSON_B64" | decode_base64 >"$tmp_dir/codex-auth.json"
printf "%s\n" "$SYMPHONY_GITHUB_SSH_PRIVATE_KEY" >"$tmp_dir/symphony-github-key"
chmod 600 "$tmp_dir/symphony-github-key"

{
  printf "LINEAR_API_KEY=%s\n" "$(shell_quote "$SYMPHONY_LINEAR_API_KEY")"
  printf "GH_TOKEN=%s\n" "$(shell_quote "$SYMPHONY_GITHUB_TOKEN")"
  printf "GITHUB_TOKEN=%s\n" "$(shell_quote "$SYMPHONY_GITHUB_TOKEN")"
  printf "AGENT_FLOW_REPO_URL=git@github.com:AttentionWorld/agent-flow.git\n"
  printf "AGENT_FLOW_REF=main\n"
  printf "AGENT_FLOW_ROOT=/opt/agent-flow\n"
  printf "SYMPHONY_REPO_URL=https://github.com/openai/symphony.git\n"
  printf "SYMPHONY_REF=main\n"
  printf "SYMPHONY_WORKSPACE_ROOT=/var/lib/symphony/workspaces\n"
  printf "CODEX_HOME=/var/lib/symphony/.codex\n"
  printf "GIT_SSH_COMMAND=%s\n" "$(shell_quote "ssh -i /var/lib/symphony/.ssh/id_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new")"
} >"$tmp_dir/symphony.env"

ssh_opts=(
  -i "$tmp_dir/opc_ssh_key"
  -o BatchMode=yes
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR
  -o ServerAliveInterval=30
  -o ConnectTimeout=10
)

scp "${ssh_opts[@]}" \
  "$tmp_dir/symphony.env" \
  "$tmp_dir/codex-auth.json" \
  "$tmp_dir/symphony-github-key" \
  "scripts/install_symphony_runtime.sh" \
  "opc@$public_ip:/tmp/"

ssh "${ssh_opts[@]}" "opc@$public_ip" "bash -s" <<'REMOTE'
set -euo pipefail

sudo cloud-init status --wait

if ! command -v gh >/dev/null 2>&1; then
  sudo dnf install -y dnf-plugins-core
  sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
  sudo dnf install -y gh
fi

sudo install -m 0755 -o root -g root /tmp/install_symphony_runtime.sh /usr/local/bin/symphony-install-runtime
sudo SERVICE_USER=symphony STATE_ROOT=/var/lib/symphony /usr/local/bin/symphony-install-runtime

sudo install -d -m 0750 -o root -g symphony /etc/symphony
sudo install -m 0640 -o root -g symphony /tmp/symphony.env /etc/symphony/env

sudo install -d -m 0700 -o symphony -g symphony /var/lib/symphony/.codex
sudo install -m 0600 -o symphony -g symphony /tmp/codex-auth.json /var/lib/symphony/.codex/auth.json

sudo install -d -m 0700 -o symphony -g symphony /var/lib/symphony/.ssh
sudo install -m 0600 -o symphony -g symphony /tmp/symphony-github-key /var/lib/symphony/.ssh/id_ed25519
sudo -u symphony -H bash -lc 'ssh-keygen -y -f /var/lib/symphony/.ssh/id_ed25519 > /var/lib/symphony/.ssh/id_ed25519.pub'
sudo -u symphony -H bash -lc 'ssh-keyscan -H github.com > /var/lib/symphony/.ssh/known_hosts 2>/dev/null'
sudo chmod 0644 /var/lib/symphony/.ssh/id_ed25519.pub /var/lib/symphony/.ssh/known_hosts

rm -f /tmp/symphony.env /tmp/codex-auth.json /tmp/symphony-github-key /tmp/install_symphony_runtime.sh

sudo systemctl daemon-reload
sudo systemctl restart symphony.service

for _ in $(seq 1 90); do
  if systemctl is-active --quiet symphony.service; then
    break
  fi
  sleep 5
done

if ! systemctl is-active --quiet symphony.service; then
  sudo journalctl -u symphony.service -n 160 --no-pager | sed -E \
    -e 's/(lin_api_)[A-Za-z0-9]+/\1<redacted>/g' \
    -e 's/(github_pat_)[A-Za-z0-9_]+/\1<redacted>/g' \
    -e 's/(gh[opsu]_[A-Za-z0-9_]+)/<redacted-github-token>/g'
  exit 1
fi

sudo -u symphony -H bash -lc 'set -euo pipefail; cd /var/lib/symphony; export CODEX_HOME=/var/lib/symphony/.codex; export PATH=/var/lib/symphony/.local/bin:/var/lib/symphony/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin; codex login status'
sudo -u symphony -H bash -lc 'set -euo pipefail; cd /var/lib/symphony; export PATH=/var/lib/symphony/.local/bin:/var/lib/symphony/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin; set -a; . /etc/symphony/env; set +a; gh api user >/dev/null'
sudo -u symphony -H bash -lc 'set -euo pipefail; cd /var/lib/symphony; export PATH=/var/lib/symphony/.local/bin:/var/lib/symphony/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin; rm -rf /tmp/agent-flow-bootstrap-smoke; git clone --depth 1 git@github.com:AttentionWorld/agent-flow.git /tmp/agent-flow-bootstrap-smoke >/dev/null; test -d /tmp/agent-flow-bootstrap-smoke/.git; rm -rf /tmp/agent-flow-bootstrap-smoke'
sudo -u symphony -H bash -lc 'set -euo pipefail; cd /var/lib/symphony; export PATH=/var/lib/symphony/.local/bin:/var/lib/symphony/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin; node --version >/dev/null; npm --version >/dev/null; go version >/dev/null; playwright-cli --version >/dev/null; rm -rf /tmp/playwright-config-smoke; mkdir -p /tmp/playwright-config-smoke; cd /tmp/playwright-config-smoke; symphony-playwright-config; grep -q firefox .playwright/cli.config.json; cd /var/lib/symphony; rm -rf /tmp/playwright-config-smoke; symphony-browser-smoke'
sudo ss -ltn | grep -q '127.0.0.1:4097'

echo "Symphony bootstrap complete."
REMOTE
