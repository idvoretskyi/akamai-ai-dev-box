# Security Model

## Intended Trust

This is a single-user development host for trusted workloads, not a multi-tenant inference service or a sandbox for hostile repositories. The developer has sudo access. Running an agent as that user exposes the user's accessible files and capabilities; approving a shell command can exercise sudo or other powerful local tools.

Docker is installed from Ubuntu packages for CPU containers. The developer is not added to the `docker` group and uses `sudo docker`. Access to the Docker daemon is effectively root access, and containers are not a substitute for a security boundary against untrusted agent commands. There is no local Kubernetes, CUDA toolkit, or GPU container runtime in the baseline.

## Network Exposure

SSH access is restricted to explicitly supplied IPv4 source CIDRs and optional IPv6 source CIDRs; IPv6 SSH sources default to an empty list. Use public-key authentication and verify the host fingerprint through a trusted channel. Do not widen rules to the entire Internet to troubleshoot a bad source address.

Ollama listens only on `127.0.0.1:11434`; its API has **no local authentication**. Every local user and process able to reach it is trusted to invoke it, consume resources, and interact with its model API. `OLLAMA_NO_CLOUD=1` disables Ollama cloud features; it does not add authentication or stop all outbound network activity.

Never expose port 11434 publicly, publish it through Docker, bind it to `0.0.0.0`, or put an unauthenticated public proxy in front of it. Use OpenCode on the GPU host over SSH. Any future remote inference access needs a separately reviewed authenticated design, not a firewall exception to the unauthenticated API.

The host needs outbound access for package and binary installation, explicit model pulls, and optional hosted services. This project does not implement egress isolation. Ordinary development servers and published container ports need their own access review.

## Credentials And State

- No workstation SSH private keys, GitHub credentials, Copilot tokens, cloud credentials, or user OpenCode configuration are copied by bootstrap.
- Keep OpenTofu and provider credentials on an external trusted administration host. Use `export LINODE_TOKEN="$(scripts/linode-token-from-cli.sh)"` in the active shell, and do not place that token on the GPU host.
- Remote state in Linode Object Storage uses separate S3 credentials (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`). Scope and rotate them independently from the Linode API token.
- The required `root_pass` is sensitive but can still be stored in state and saved plans. Treat state, plans, real tfvars, cloud-init data, crash logs, and backups as confidential.
- Encryption and access control are required for sensitive storage even if the repository or state bucket is private. OpenTofu `sensitive` and `.gitignore` are not encryption or access controls.
- Use scoped, revocable credentials and approved authentication flows when you deliberately enable GitHub or Copilot. GitHub CLI and OpenCode authentication are separate. Avoid SSH agent forwarding to a host you do not fully trust.
- Never attach real state, saved plans, authentication stores, or raw diagnostic bundles to issues. Redact host details, tokens, prompts, code, and other private data before sharing logs.

An encrypted and access-controlled backup strategy is the operator's responsibility; paid provider backups are disabled by default. Local session history, caches, model metadata, and working copies can remain on disk after a process exits. Revoking a token and deleting or reimaging a host are different actions; assess both after compromise.

## Local Does Not Mean Isolated

The OpenCode examples disable session sharing and automatic OpenCode updates, ask before edits and Bash commands, and set both main and small models to local Ollama. The local-only example allows only the `ollama` provider; the hybrid example additionally allows `github-copilot`.

These settings are useful defaults, **not a privacy guarantee, sandbox, or air gap**:

- `OPENCODE_CONFIG` merges with global, project, organizational, and other configuration sources. Higher-precedence settings, environment overrides, and agent-specific model selections can change behavior. Review the effective configuration.
- Plugins, custom tools, MCP servers, skills, language servers, shell commands, and network tools can read data or make outbound requests independently of the selected model provider. Provider allowlists do not disable those paths.
- Dependency downloads, model catalog lookups, and other runtime network behavior are not eliminated by disabling automatic updates or sharing.
- Permissions for edits and Bash do not automatically make all other tools ask. Review every enabled integration and the actual tool permission policy before using private material.
- Switching from a local to a hosted model in the same session can send earlier conversation, code, and tool results. Use a new, reviewed session when crossing that boundary; already transmitted data is not recalled.

No example is automatically copied to `~/.config/opencode/`. Restart OpenCode after config changes so that the chosen configuration is loaded. For stronger privacy requirements, use a separately reviewed isolated environment with controlled egress and audited configuration rather than relying on a filename such as `local-only.json`.

## Supply Chain And Limits

Ollama and OpenCode release binaries are version-pinned and checked against recorded upstream SHA256 values before installation. Review the provenance of those values: a checksum fetched from the same compromised publisher is not independent authenticity evidence. Do not bypass verification on download failure.

Ubuntu 26.04 (`linode/ubuntu26.04`) supplies `linux-generic`, `linux-headers-generic`, and the hardware-aware current compute driver selected by `ubuntu-drivers install --gpgpu`, with matching NVIDIA utilities. No NVIDIA branch is pinned; package and security revisions follow apt. This bleeding-edge baseline can differ between fresh installations and remains subject to GPU compatibility. Package availability is not a live GPU trial or a guarantee that every future package revision is compatible.

Bootstrap reboots into the distribution kernel before driver selection, then reboots again after driver installation. Separate `kernel-boot-id` and `driver-boot-id` markers under `/var/lib/ai-dev-box/` track those stages. Before enabling Ollama, bootstrap requires working `nvidia-smi` and a loaded driver version >= 550, and records the actual loaded driver in the readiness journal. Failures stop for diagnosis and manual service restart, not an infinite reboot loop. Do not bypass those checks or remove markers as a recovery shortcut.

Model tags are mutable and model licenses are independent of this repository's MIT license. Explicitly review a model before pulling, record its digest, and keep downloaded weights and generated output within the intended trust boundary. Treat model-proposed commands and repository-supplied instructions as untrusted input, not authority to access secrets or provision resources.

Ollama's one-request/one-loaded-model settings and host-memory/CPU limits reduce accidental contention. They are not a GPU-memory quota, protection from all denial of service, or isolation from other local workloads.

## Incident Handling

If exposure is suspected, stop transmitting sensitive prompts, restrict access through an approved incident process, revoke affected credentials, and preserve necessary evidence in protected storage. Do not publish logs before redaction or assume rewriting Git history resolves a leak. Follow [SECURITY.md](../SECURITY.md) for private repository vulnerability reporting.
