# Contributing

Small, focused improvements are welcome. Open an issue before proposing a new instance size, a different operating system, a new credential flow, or a deployment/lifecycle change. The initial target is a fresh Ubuntu 26.04 (`linode/ubuntu26.04`) RTX 4000 Ada Small instance in Frankfurt 2, not an existing machine or cluster. This bleeding-edge baseline remains subject to GPU compatibility; no live GPU trial has been performed.

## Local Checks

Use OpenTofu >= 1.10 and the repository's pinned Linode provider lock file. Install Python 3 with venv support and ShellCheck. From the repository root:

```bash
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

These are static checks. They must not need cloud credentials, provision resources, download model weights, or call paid inference APIs. Dependency installation and provider initialization may require network access. Preserve the provider lock file; normal initialization uses:

```bash
tofu -chdir=tofu init -lockfile=readonly
```

For real deployments, this repo expects remote state in Linode Object Storage via `tofu/backend.hcl` (from `tofu/backend.hcl.example`) and local shell exports for credentials: `LINODE_TOKEN` from `scripts/linode-token-from-cli.sh` plus Object Storage S3 credentials.

Do not run bootstrap scripts as root on your workstation. Server-side smoke checks require a separately approved deployment; report them separately from static results. Model quality and tool-use claims need reproducible runtime evidence, not just passing JSON validation.

## Change Expectations

- Keep the minimal default installation and narrow SSH access intact. No paid CI, paid backups, local Kubernetes, CUDA toolkit, or GPU container runtime by default.
- Add or adjust tests for behavior changes, and update the relevant documentation and examples together.
- Check upstream release assets and SHA256 values for binary pin changes. Record the source and validation performed in the pull request. Keep NVIDIA selection hardware-aware through `ubuntu-drivers install --gpgpu`; do not pin a driver branch or freeze Ubuntu package and security revisions.
- Preserve the distribution-kernel reboot before compute-driver installation and the second reboot before GPU validation. Cover stage markers and failure handling without automatic reboot loops. Readiness requires working `nvidia-smi`, a loaded driver version >= 550, and the actual loaded version recorded in the journal before Ollama is enabled.
- Validate OpenCode fields against the [published schema](https://opencode.ai/config.json) and verify behavior with the pinned OpenCode release when possible. Preserve the warning about merged configuration and restart requirements.
- Use placeholders only. Never include real state, tfvars, saved plans, credentials, private keys, or unredacted logs. Review the diff and staged files, even when ignore rules exist.
- Describe test commands, results, limitations, and any possible cost or security impact. Do not claim GPU testing unless it actually happened on the documented hardware.

Deployment, destruction, imports, and upgrade procedures need separate explicit review and authorization. An issue or pull request requesting implementation is not permission to operate anyone's infrastructure.

## Sign-Off

Contributions must include a Developer Certificate of Origin sign-off. By signing off, you certify the [DCO 1.1](https://developercertificate.org/) for your contribution. Use your own identity:

```bash
git commit -s -m "Describe the change"
```

This adds a `Signed-off-by: Your Name <your-email>` trailer; it is not a cryptographic signature. Contributions are under the repository's [MIT license](LICENSE). Third-party models and dependencies retain their own terms.

## Security Reports

Follow [SECURITY.md](SECURITY.md) instead of posting exploit details or secrets in a public issue.
