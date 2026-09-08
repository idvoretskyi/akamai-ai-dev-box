# Akamai AI Dev Box

A minimal, single-user GPU development box on Akamai Cloud (Linode), managed with OpenTofu. Run OpenCode against localhost Ollama, with optional GitHub Copilot access for hosted models. This creates a **fresh instance**; it does not modify an existing CPU dev box or Kubernetes cluster.

## Baseline

| Component | Initial configuration |
| --- | --- |
| Region | Frankfurt 2, `de-fra-2` |
| Plan | RTX 4000 Ada Small, `g2-gpu-rtx4000a1-s` (only supported size) |
| Resources | 4 vCPU, 16 GiB RAM, 512 GiB disk, 20 GB VRAM |
| OS | Minimal Ubuntu 26.04, `linode/ubuntu26.04` |
| GPU | Distribution kernel, hardware-aware Ubuntu compute driver via `ubuntu-drivers install --gpgpu` |
| Inference | Ollama `0.33.3`, loopback only, cloud features disabled |
| Agent | OpenCode `1.18.29`, opt-in configuration examples |
| Infrastructure | OpenTofu >= 1.9, Linode provider `3.12.0` with lock file |

Budget **$0.52/hour**, approximately **$379.60 for 730 hours**. There is **no monthly cap and no included transfer**. Taxes, transfer, and optional hosted-model subscriptions or usage are additional. Recheck current pricing and regional availability before approving any deployment; a powered-off instance is not a cost-control substitute for deleting billable resources.

Includes Git, `gh`, tmux, Bash, `python3-venv`, `build-essential`, ripgrep, jq, curl, and Ubuntu's Docker package for ordinary CPU containers. Docker requires `sudo`; the developer is not added to the `docker` group. No paid backups, local Kubernetes, CUDA toolkit, or GPU container runtime are installed. No workstation credentials are copied.

**Validation status:** Ubuntu 26.04 is the bleeding-edge baseline, subject to GPU compatibility; no live GPU trial has been performed. Bootstrap reboots into the distribution kernel first, selects the current distro-recommended compute driver, then reboots again. Working `nvidia-smi` and a loaded driver version >= 550 are required before enabling Ollama. Binary release pins require verified upstream SHA256 values; static checks do not establish driver, inference, or OpenCode tool-use compatibility. See [operations](docs/operations.md) for verification boundaries.

## Start Here

1. Read the [security model](docs/security.md) and [operations guide](docs/operations.md). Review cost, SSH allowlists, state handling, and the two planned reboots before deploying.
2. Run the [contributor checks](CONTRIBUTING.md) locally. They do not provision cloud resources or invoke paid model APIs.
3. If separately authorized to deploy, use an external trusted administration host, explicit provider credentials, and the [saved-plan workflow](docs/operations.md#deployment). Never apply as part of a documentation example or CI run.
4. After deployment, wait for bootstrap to finish across both reboots and run the server smoke checks. Instance creation and SSH availability are not readiness signals.
5. Explicitly [pull the reference model and create `dev-coder`](docs/models.md#reference-model), then select an OpenCode example below.

On the GPU box, from this repository's root, after the model exists:

```bash
OPENCODE_CONFIG="$PWD/examples/opencode/local-only.json" opencode
```

For optional Copilot access instead:

```bash
OPENCODE_CONFIG="$PWD/examples/opencode/hybrid.json" opencode
```

Both examples default the main and small model to `ollama/dev-coder`, disable sharing and automatic OpenCode updates, and ask before edits and shell commands. Hybrid enables only Ollama and GitHub Copilot; connect Copilot with `/connect`, then choose a currently supported model with `/models`. No hosted model ID is hardcoded.

**These files merge with existing OpenCode configuration; they do not replace it or guarantee privacy.** Review inherited providers, agents, plugins, MCP servers, network tools, and environment overrides. Quit and restart OpenCode after changing configuration. Nothing is automatically copied into your user configuration. Switching to a hosted model within the same session may transmit earlier conversation content. See [model setup](docs/models.md) and [privacy limits](docs/security.md#local-does-not-mean-isolated).

## Documentation

- [Models and OpenCode](docs/models.md): reference model, resource budget, configuration, and evaluation.
- [Operations](docs/operations.md): inputs, approved deployment, bootstrap, diagnostics, and lifecycle limits.
- [Security](docs/security.md): trust boundaries, credentials, state, and network exposure.
- [Contributing](CONTRIBUTING.md), [agent instructions](AGENTS.md), and [security reporting](SECURITY.md).

## Static Validation

From the repository root:

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements-dev.txt
tofu -chdir=tofu fmt -check -recursive -diff
tofu -chdir=tofu init -backend=false -lockfile=readonly
tofu -chdir=tofu validate
bash -n tofu/cloud-init/bootstrap.sh scripts/smoke-test.sh
shellcheck tofu/cloud-init/bootstrap.sh scripts/smoke-test.sh
python tests/check_config.py
```

These checks are static and credential-free. They do not perform `tofu apply`.

## License

[MIT](LICENSE), copyright 2026 Ihor Dvoretskyi. Downloaded models, drivers, tools, and hosted services retain their own licenses and terms. This is an independent community project, not an Akamai support offering.
