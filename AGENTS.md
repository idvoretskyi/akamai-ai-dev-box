# Agent Instructions

## Scope

This is a public OSS repository for a fresh, single-user Akamai GPU dev box. Preserve the minimal Ubuntu 26.04 (`linode/ubuntu26.04`) / RTX 4000 Ada Small baseline. This bleeding-edge OS baseline is subject to GPU compatibility, not yet established by a live GPU trial. Do not modify other repositories, existing CPU instances, or clusters. Read the relevant files before editing; keep changes small and tests and documentation aligned.

Routine in-scope file edits, formatting, and static checks do not need a separate conversational confirmation for every step. Respect the active tool permission policy, including the example OpenCode `ask` rules. Stop and ask when scope, cost, credentials, or destructive effects are unclear.

## Infrastructure Boundary

- Do not provision cloud resources or use paid model APIs for tests or CI.
- Do not run `tofu apply`, `tofu destroy`, imports, state mutations, resource replacements, or cloud API mutations without separate explicit approval for that operation and target. A request to implement code is not deployment approval.
- Paid deployment belongs on an external trusted administration host. Review a saved plan, obtain approval, and apply only that saved plan. Do not use `-auto-approve` or combine planning and applying into unattended automation.
- Do not hardcode provider credentials or read real secrets into repository files. For operator workflows, this repo may export `LINODE_TOKEN` from local `linode-cli` config via `scripts/linode-token-from-cli.sh`; never print or commit credential values.
- Do not add upgrade or import procedures without separate review. Explicit root/swap disks and GRUB boot configuration are required to boot the distribution kernel for NVIDIA support.
- Preserve the two-stage reboot sequence: install `linux-generic` and `linux-headers-generic`, record `kernel-boot-id`, and reboot into the distribution kernel before driver selection; then use `ubuntu-drivers install --gpgpu`, install the matching selected NVIDIA utilities, record `driver-boot-id`, and reboot again. Both markers live under `/var/lib/ai-dev-box/`. Failures require diagnosis and a manual service restart, not an automatic reboot loop.
- Do not widen SSH allowlists, expose Ollama on public port 11434, enable paid backups, add local Kubernetes, or install a CUDA toolkit or GPU Docker runtime as incidental fixes.

## Data And Trust

- Never commit real tfvars, state, saved plans, credentials, private keys, authentication stores, model conversation data, or unredacted operational logs. OpenTofu `sensitive` does not encrypt state or plans. Private storage still requires encryption and access controls.
- Keep ignore rules narrow and reviewable. Do not hide whole configuration or source trees with broad ignores to bypass secret or test checks. Preserve the provider lock file and public placeholder examples.
- Use only fictional documentation addresses and explicit placeholders in examples. `203.0.113.10/32` is not a usable deployment SSH source.
- Preserve upstream binary version and SHA256 verification. Never fabricate a checksum or mark an untested GPU configuration as verified. Select the hardware-aware current Ubuntu-recommended compute driver rather than pinning a NVIDIA branch; package and security revisions follow apt. Require working `nvidia-smi` and a loaded driver version >= 550 before enabling Ollama, and record the actual loaded driver in the readiness journal.
- Local inference is not a sandbox. Plugins, tools, inherited configuration, local users, and hosted-provider switches have separate trust implications. Never describe `local-only.json` as an air gap or a privacy guarantee.

## Verification And Handoff

Run static verification with direct commands:

```bash
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

Do not run root bootstrap scripts on a workstation. Runtime `scripts/smoke-test.sh` checks belong on a separately approved deployed server; a model test also requires an explicitly downloaded and created model.

Report exactly which checks ran, any skipped checks, and whether results are static or live GPU observations. Review changes for secrets and unintended files. Do not commit, publish, push, or open a pull request unless requested. Contributor commits require DCO sign-off as described in `CONTRIBUTING.md`.
