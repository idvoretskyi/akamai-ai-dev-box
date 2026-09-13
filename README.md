# akamai-ai-dev-box

OpenTofu configuration for a fresh GPU coding workstation on Akamai Cloud (Linode), with local Ollama and OpenCode-ready examples.

- Baseline: `de-fra-2` + `g2-gpu-rtx4000a1-s` + `linode/ubuntu26.04`
- Hardware: 4 vCPU / 16 GiB RAM / 512 GiB disk / 20 GB VRAM
- Bootstrap: staged kernel + NVIDIA driver flow with two planned reboots
- Network: Ollama bound to `127.0.0.1:11434` only
- Scope: creates a new host; does not modify existing boxes or clusters

This Ubuntu 26.04 + RTX 4000 Ada Small baseline is intentionally narrow and still subject to real GPU compatibility testing.

## 2-Minute Quickstart

Admin machine:

```bash
set -euo pipefail

cp tofu/terraform.tfvars.example tofu/terraform.tfvars
cp tofu/backend.hcl.example tofu/backend.hcl
$EDITOR tofu/terraform.tfvars
$EDITOR tofu/backend.hcl

LINODE_TOKEN="$(scripts/linode-token-from-cli.sh)"
export LINODE_TOKEN
test -n "$LINODE_TOKEN"

tofu -chdir=tofu init -backend-config=backend.hcl -lockfile=readonly
tofu -chdir=tofu validate
tofu -chdir=tofu plan -out=create.tfplan
tofu -chdir=tofu show create.tfplan
# Apply only after explicit approval of this saved plan:
tofu -chdir=tofu apply create.tfplan

bash -lc "$(tofu -chdir=tofu output -raw wait_ready_command)"
bash -lc "$(tofu -chdir=tofu output -raw ssh_config_install_command)"
ssh "$USER-ai-dev-box"
```

GPU host:

```bash
ollama pull qwen3:8b
ollama create dev-coder -f examples/models/Modelfile
OPENCODE_CONFIG="$PWD/examples/opencode/local-only.json" opencode
```

Readiness is complete only when `/var/lib/ai-dev-box/ready` exists.

## Common Mistakes

- Leaving placeholders unchanged: replace sample SSH key, `root_pass`, and `203.0.113.10/32` with your real deployment inputs.
- Mixing credentials: `LINODE_TOKEN` is for the Linode provider, while remote state also needs Object Storage S3 credentials.
- Running model commands in the wrong place: run model/OpenCode commands on the ready GPU host from a checkout of this repository.

## Prerequisites

Use a trusted administration machine (not the managed instance):

- OpenTofu `>= 1.10`
- Python 3 + venv (for static checks)
- `linode-cli` configured locally (token, defaults)
- SSH public key(s) ready
- Private Linode Object Storage bucket for remote state
- Object Storage S3 credentials exported in shell (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)

See [docs/operations.md](docs/operations.md) for cost, safety, lifecycle constraints, and the full deployment runbook, plus [docs/models.md](docs/models.md) for the model/OpenCode workflow.

## Key Configuration

- Required variables: `authorized_keys`, `root_pass`, `allowed_ssh_cidrs_ipv4`
- Defaults from `~/.config/linode-cli`: `region`, `image` (plus built-in fallback)
- Enforced baseline plan: `g2-gpu-rtx4000a1-s`
- Backups default: `false`
- Keep `tofu/backend.hcl` local and private (gitignored)

For full input details, see [tofu/terraform.tfvars.example](tofu/terraform.tfvars.example) and [docs/operations.md](docs/operations.md).

## Shared State

Use the same backend settings and deployment inputs on each operator machine. If backend location changes, migrate with `tofu init -migrate-state`; do not use `-reconfigure` for state migration.

## Validation And Docs

- Static local checks: [CONTRIBUTING.md](CONTRIBUTING.md) (or run `scripts/check.sh`)
- Operations and deployment safety: [docs/operations.md](docs/operations.md)
- Models and OpenCode usage: [docs/models.md](docs/models.md)
- Security notes: [docs/security.md](docs/security.md)

## License

[MIT](LICENSE)
