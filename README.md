# akamai-ai-dev-box

OpenTofu configuration for a fresh, always-on GPU coding workstation on Akamai Cloud (Linode): Ubuntu 26.04 + RTX 4000 Ada Small, local Ollama, and OpenCode-ready defaults.

- Baseline: `de-fra-2` + `g2-gpu-rtx4000a1-s` + `linode/ubuntu26.04`
- Hardware: 4 vCPU / 16 GiB RAM / 512 GiB disk / 20 GB VRAM
- Bootstrap: staged kernel/driver flow with two planned reboots
- Inference: Ollama `0.33.3` on `127.0.0.1:11434` only
- Agent runtime: OpenCode `1.18.29`

This repository provisions a new host only. It does not resize or mutate existing CPU dev boxes or Kubernetes clusters.

State is intended to live in a remote Linode Object Storage bucket so the same deployment can be managed from multiple machines.

## Fresh deployment

```sh
export LINODE_TOKEN="$(scripts/linode-token-from-cli.sh)"
cp tofu/terraform.tfvars.example tofu/terraform.tfvars
cp tofu/backend.hcl.example tofu/backend.hcl
$EDITOR tofu/backend.hcl
$EDITOR tofu/terraform.tfvars   # set authorized_keys + root_pass + allowed_ssh_cidrs_ipv4

tofu -chdir=tofu init -reconfigure -backend-config=backend.hcl -lockfile=readonly
tofu -chdir=tofu plan -out=create.tfplan
# Review resources, region, plan, and firewall rules before apply.
tofu -chdir=tofu apply create.tfplan
eval "$(tofu -chdir=tofu output -raw wait_ready_command)"
eval "$(tofu -chdir=tofu output -raw ssh_config_install_command)"
ssh "$USER-ai-dev-box"
```

Do not treat first SSH availability as readiness. Bootstrap must complete both reboot stages and create `/var/lib/ai-dev-box/ready`.

## Configuration

Key variables (`tofu/variables.tf`):

| Variable | Default | Notes |
|---|---|---|
| `region` / `instance_type` / `image` | from `~/.config/linode-cli` | fallback: `de-fra-2` / `g2-gpu-rtx4000a1-s` / `linode/ubuntu26.04` |
| `authorized_keys`, `root_pass` | none | required |
| `allowed_ssh_cidrs_ipv4` | none | required; set your real source CIDR(s) |
| `allowed_ssh_cidrs_ipv6` | `[]` | optional; no IPv6 SSH allowlist by default |
| `backups_enabled` | `false` | paid backups not included in baseline |

The config enforces `g2-gpu-rtx4000a1-s` as the supported baseline plan.

## Remote state

- Use `tofu/backend.hcl.example` as the template for the S3 backend pointed at Linode Object Storage.
- Keep `tofu/backend.hcl` local and private; it is ignored by Git.
- Export Object Storage S3 credentials (for example `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`) in your shell before `tofu init`.
- Keep `use_lockfile = true` and enable bucket versioning to reduce shared-state corruption risk.
- Validate backend locking once in your environment before collaborative use.
- Use `tofu init -migrate-state` for backend moves; do not use `-reconfigure` for state migration.

## OpenCode examples

After the server is ready and the reference model exists:

```sh
OPENCODE_CONFIG="$PWD/examples/opencode/local-only.json" opencode
```

Optional hosted-provider mode:

```sh
OPENCODE_CONFIG="$PWD/examples/opencode/hybrid.json" opencode
```

Examples merge with existing OpenCode configuration; they do not replace it.

## Static validation

```sh
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements-dev.txt
tofu -chdir=tofu fmt -check -recursive -diff
tofu -chdir=tofu init -backend=false -lockfile=readonly
tofu -chdir=tofu validate
bash -n scripts/linode-token-from-cli.sh
bash -n scripts/smoke-test.sh
bash -n tofu/cloud-init/bootstrap.sh
bash -n tofu/scripts/read-linode-cli.sh
bash -n tofu/scripts/read-local-user.sh
shellcheck scripts/linode-token-from-cli.sh
shellcheck scripts/smoke-test.sh
shellcheck tofu/cloud-init/bootstrap.sh
shellcheck tofu/scripts/read-linode-cli.sh
shellcheck tofu/scripts/read-local-user.sh
python tests/check_config.py
```

These checks are static and do not run `tofu apply`.

## Docs

- [docs/operations.md](docs/operations.md)
- [docs/models.md](docs/models.md)
- [docs/security.md](docs/security.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)

## License

[MIT](LICENSE)
