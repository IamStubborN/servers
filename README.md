# Infrastructure with OpenTofu

OpenTofu modules for shared Oracle Cloud networking and a Cloudflare Tunnel, with reusable Cloudflare and Hetzner modules. Deployment credentials and service addresses are supplied privately.

## Local configuration

Install the versions in `.mise.toml`, copy `.env.example` to `.env`, and copy `backend.hcl.example` to `backend.hcl`. Replace example values with your private deployment values. You can instead put non-environment inputs in a local `deployment.auto.tfvars.json` file. These files, private keys, state, plans, and `.private/` are ignored by Git; protect them with permissions appropriate for credentials.

Required deployment inputs include `vaultwarden_hostname`. Real repository URLs and DNS names do not belong in tracked defaults.

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

Provider and backend credentials are GitHub Actions secrets. The additional deployment secret is `VAULTWARDEN_HOSTNAME`. Standalone `install_*` scripts and the OCI status utility are reusable manual tools; this root configuration does not provision or bootstrap a VM.

## Existing deployments

Keep the same backend, resource addresses, credentials and hostname when moving deployment configuration out of source control. Run a plan before changing infrastructure. A source-code privacy cleanup should not require applying resource changes.

### Legacy Oracle runner retirement

The legacy runner definition, cloud-init template, instance outputs, inputs and
runner-bound CI commands have been removed. The Oracle module now manages only
its existing shared VCN, Internet gateway, route table, subnet and security list.
Resource addresses and network defaults are preserved because the independently
managed VPN hub depends on that network. Never destroy the whole Oracle module
to retire a VM.

The retired instance and its boot disk are already absent. Removing their source
must produce a no-change plan before publication; no apply is needed for this
cleanup. Deployment evidence belongs in the home repository's private VPN
runbook. Other independently managed instances are outside this root's scope.

Historical revisions that still declare the runner can propose creating it again.
CI does not apply automatically; review the selected revision and its saved plan
before any separately authorized manual apply.
