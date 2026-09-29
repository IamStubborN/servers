# Infrastructure with OpenTofu

OpenTofu modules for an Oracle Cloud runner and a Cloudflare Tunnel, with reusable Cloudflare and Hetzner modules. Deployment credentials and service addresses are supplied privately.

## Local configuration

Install the versions in `.mise.toml`, copy `.env.example` to `.env`, and copy `backend.hcl.example` to `backend.hcl`. Replace example values with your private deployment values. You can instead put non-environment inputs in a local `deployment.auto.tfvars.json` file. These files, private keys, state, plans, and `.private/` are ignored by Git; protect them with permissions appropriate for credentials.

Required deployment inputs include `vaultwarden_hostname` and `agent_flow_repo_url`. The latter must also be set as `AGENT_FLOW_REPO_URL` when manually bootstrapping the application runtime. Real repository URLs and DNS names do not belong in tracked defaults.

```sh
mise install
mise run check
mise run init
set -a
. ./.env
set +a
scripts/ci_plan.sh
```

`ci_plan.sh` returns `0` for no changes, `2` for a proposed change, and `1` on failure. It never applies a plan. Raw diagnostics, plan files, and any JSON representation stay under `.private/`; terminal output contains only a summary. Inspect private diagnostics locally, and do not publish them as CI artifacts.

Validation uses `.terraform-validate/` so it does not discard the backend initialized under `.terraform/`.

## CI/CD

Pushes and pull requests run formatting, OpenTofu validation, workflow validation, and planning-script regression tests without deployment credentials. Manual workflow dispatch defaults to **plan only**. A non-empty plan fails that verification run and makes no infrastructure changes.

Applying infrastructure requires an explicit manual `apply=true` dispatch from `main`. That run applies only its saved plan. There is no automatic replacement of terminated instances and no automatic runtime bootstrap. Review infrastructure changes before selecting this option. A plan-only verification does not prove that a future apply will succeed.

Provider and backend credentials are GitHub Actions secrets. The additional deployment secrets are `VAULTWARDEN_HOSTNAME` and `AGENT_FLOW_REPO_URL`. OCI instance provisioning and application bootstrap are separate operations; the private runtime secrets used by `scripts/ci_bootstrap_symphony.sh` are needed only for an explicitly requested bootstrap.

## Existing deployments

Keep the same backend, resource addresses, credentials, hostname, and application repository URL when moving deployment configuration out of source control. Run a plan before changing infrastructure. A source-code privacy cleanup should not require applying resource changes.
