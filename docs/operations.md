# Operations

## Scope And Cost

This is a fresh-instance workflow for Ubuntu 26.04 (`linode/ubuntu26.04`) on RTX 4000 Ada Small (`g2-gpu-rtx4000a1-s`) in Frankfurt 2 (`de-fra-2`). This bleeding-edge OS baseline is subject to GPU compatibility; no live GPU trial has been performed. Only Small is initially supported: four vCPUs, 16 GiB RAM, 512 GiB disk, and 20 GB VRAM. It does not configure an existing CPU box or a cluster.

The budget baseline is $0.52/hour, or $379.60 at 730 hours, with **no monthly cap and no included transfer**. Verify current Akamai pricing, taxes, availability, and transfer charges before deployment. Account for model downloads and any outbound traffic under the provider's current rules. Hosted-model subscriptions and usage are separate. No paid backups are enabled. Powering an instance off does not necessarily stop billing; retain an explicit teardown and data-retention plan.

## Inputs

Run OpenTofu >= 1.10 on an external trusted administration host, not on the instance it manages. Use Linode provider `3.12.0` and the committed dependency lock file. Set provider auth from local `linode-cli` configuration via `export LINODE_TOKEN="$(scripts/linode-token-from-cli.sh)"`.

| Variable | Requirement or default |
| --- | --- |
| `username` | local `$USER` by default; developer account with sudo access |
| `instance_label` | `<username>-ai-dev-box` |
| `region` | `de-fra-2` |
| `instance_type` | `g2-gpu-rtx4000a1-s` (required baseline) |
| `authorized_keys` | Required list of your SSH public keys, never private keys |
| `allowed_ssh_cidrs_ipv4` | Required list of actual trusted source CIDRs |
| `allowed_ssh_cidrs_ipv6` | `[]`; no IPv6 SSH sources by default |
| `root_pass` | Required sensitive value; provision out of band, never commit |

The following is illustrative input, **not deployable as written**. Replace placeholders privately; obtain the root password through a secure input mechanism rather than committing it in tfvars:

```hcl
username                = "dev"
instance_label          = "ai-dev-box"
region                  = "de-fra-2"
instance_type           = "g2-gpu-rtx4000a1-s"
authorized_keys         = ["REPLACE_WITH_YOUR_SSH_PUBLIC_KEY"]
allowed_ssh_cidrs_ipv4  = ["203.0.113.10/32"]
allowed_ssh_cidrs_ipv6  = []
```

`203.0.113.10/32` belongs to a documentation range. It will not grant your workstation access. Use the actual stable public source address or trusted network CIDR, not broad allowlists like `0.0.0.0/0` or `::/0`. A required provisioning root password does not imply that SSH password login should be enabled.

Keep real variable files, state, and plans out of Git. Marking a variable `sensitive` suppresses some display but does not encrypt it. Use restricted permissions and encryption for local storage, remote state, and backups, even when the repository or storage is private. See [state security](security.md#credentials-and-state).

### Shared remote state

Use a dedicated private Linode Object Storage bucket and configure the OpenTofu S3 backend from a local `tofu/backend.hcl` file (copy `tofu/backend.hcl.example`). This backend config is machine-local and must never be committed.

Export Object Storage S3 credentials (`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`) in your shell before `tofu init`. These are not the Linode API token and are used only for state storage access.

Initialize backend state on the first machine:

```bash
cp tofu/backend.hcl.example tofu/backend.hcl
$EDITOR tofu/backend.hcl
tofu -chdir=tofu init -reconfigure -backend-config=backend.hcl -lockfile=readonly
```

If migrating an existing backend, use `tofu -chdir=tofu init -migrate-state -backend-config=backend.hcl -lockfile=readonly` after separate review.

On additional machines, use the same backend settings and the same deployment inputs so all operators target the same resources and state.

Before first production use, verify backend locking behavior in your account and endpoint (for example, concurrent `tofu plan` against the same state key should serialize when `use_lockfile = true`).

## Deployment

**Do not deploy during repository development or CI.** These commands are a future operator workflow, not authorization to incur charges. Verify the target account, credentials, SSH sources, current price, and intended new resources first. From the repository root on the trusted administration host:

```bash
export LINODE_TOKEN="$(scripts/linode-token-from-cli.sh)"
tofu -chdir=tofu init -reconfigure -backend-config=backend.hcl -lockfile=readonly
tofu -chdir=tofu validate
tofu -chdir=tofu plan -out=create.tfplan
tofu -chdir=tofu show create.tfplan
```

Review the saved plan privately, including instance type, region, firewall, disabled backups, disks, and boot configuration. Obtain separate explicit approval for the paid deployment of **that plan**. Only then:

```bash
tofu -chdir=tofu apply create.tfplan
```

Do not replace this with an unsaved apply, `-auto-approve`, or an unattended plan/apply pipeline. If the inputs or intended change differ, generate a new plan and obtain approval again. `-chdir=tofu` places `create.tfplan` in `tofu/`; protect it as sensitive data and do not publish it as a CI artifact.

Outputs `ssh_command_user`, `instance_id`, and `ipv4_address` identify the created instance and access command. They **do not assert readiness**. Check the SSH host fingerprint using a trusted channel before accepting it. Bootstrap intentionally interrupts SSH for two reboots: first for the distribution kernel, then for the selected NVIDIA driver.

The instance uses explicit root and swap disks with a GRUB boot configuration so that Ubuntu's distribution kernel boots. A provider-supplied alternative kernel can break the distribution NVIDIA driver. This layout is for fresh deployment only; imports, in-place upgrades, disk migration, and conversion of existing hosts require a separately reviewed procedure and are not documented here.

## Bootstrap Lifecycle

1. Cloud-init configures the initial host and writes `/etc/ai-dev-box.env` plus the bootstrap service. The environment file is bootstrap configuration, not a destination for provider or workstation credentials.
2. `ai-dev-box-bootstrap.service` runs as a root oneshot after `cloud-final.service`. It installs the minimal development packages plus `linux-generic` and `linux-headers-generic`.
3. The service records the current boot ID in `/var/lib/ai-dev-box/kernel-boot-id` and requests the first reboot. It resumes on the next boot, verifies that the distribution kernel is running, and only then proceeds to driver selection.
4. Using `ubuntu-drivers-common`, the service runs `ubuntu-drivers install --gpgpu` to select and install the current hardware-aware, distro-recommended compute driver and installs the NVIDIA utilities matching that selection. No driver branch is pinned. It records the current boot ID in `/var/lib/ai-dev-box/driver-boot-id` and requests the second reboot.
5. After the second reboot, working `nvidia-smi` and a loaded driver version >= 550 are required before proceeding. The service records the actual loaded driver version in the readiness journal, installs pinned Ollama `0.33.3` and OpenCode `1.18.29` release binaries with SHA256 verification, then enables localhost Ollama.
6. Successful bootstrap writes `/var/lib/ai-dev-box/ready`. Models are not downloaded, user credentials are not copied, and OpenCode examples are not installed into user configuration.

Each boot-ID marker distinguishes its installation boot from the subsequent boot. The normal path requests two reboots, not an unbounded retry cycle. A failed stage stops for diagnosis and a manual service restart after the cause is addressed; it must not repeatedly reboot to try to fix itself.

Ubuntu package and security revisions follow apt, including the recommended compute-driver selection. The reported Resolute apt-cache inspection found `ubuntu-drivers-common` version `1:0.10.9`, a `580-server` driver at `580.178`, and a transitional `590-server` package leading to `595`. These are package-availability observations, not driver pins, proof of which driver this GPU will select, or a GPU compatibility trial. Record the actual loaded driver rather than inferring it from a package name.

Pinned binary versions and recorded upstream checksums are supply-chain controls, not proof that the driver/runtime combination works. Verify actual release availability and checksums when maintaining pins; do not fall back to an unverified installer if a download fails.

Ollama is bound to loopback port 11434 with `OLLAMA_NO_CLOUD=1`, `OLLAMA_NUM_PARALLEL=1`, `OLLAMA_MAX_LOADED_MODELS=1`, and a 16,384-token context baseline. Its service has `MemoryMax=10G` and `CPUQuota=200%`. Inspect the installed unit when diagnosing limits; host-memory cgroups do not cap GPU VRAM.

## Readiness And Diagnostics

After reconnecting to the deployed instance:

```bash
sudo systemctl status ai-dev-box-bootstrap.service --no-pager
sudo journalctl -u ai-dev-box-bootstrap.service --no-pager
sudo test -f /var/lib/ai-dev-box/ready
nvidia-smi
sudo systemctl status ollama.service --no-pager
curl --fail --silent --show-error http://127.0.0.1:11434/api/tags
```

A oneshot service need not look like a continuously running daemon. Review its exit result, logs across both reboots, the recorded loaded driver version (>= 550), and the ready marker together. Cloud-init completion, an IP address, or an open SSH port alone is insufficient. A marker records successful bootstrap, not current health; repeat GPU and service checks before relying on the host.

With this repository available on the server, run the infrastructure/runtime smoke check:

```bash
bash scripts/smoke-test.sh
```

After explicitly [creating the reference model](models.md#reference-model), optionally include a model generation check:

```bash
bash scripts/smoke-test.sh dev-coder
```

For failures, inspect the bootstrap journal first. Check `uname -r` and `nvidia-smi` for kernel/driver problems. Inspect `sudo systemctl cat ollama.service`, `sudo journalctl -u ollama.service`, `ollama ps`, `free -h`, and `df -h` for runtime, OOM, and disk issues. Inspect `sudo ss -lntp` to confirm Ollama is not listening on public interfaces. Do not remove boot or readiness markers, change the boot kernel, broaden firewall rules, or rerun root installation logic blindly to mask a failure.

Once the cause is understood and corrected through an approved recovery procedure, manually restart `ai-dev-box-bootstrap.service` to resume. Do not add automatic restart/reboot loops or bypass the GPU validation gate to enable Ollama on an incompatible host.

No CUDA toolkit or NVIDIA container runtime is installed. `sudo docker` runs normal CPU containers; a missing GPU Docker capability is not a bootstrap defect. Avoid adding the developer to the root-equivalent `docker` group as a convenience fix.

## Lifecycle Limits

Schedule OS security maintenance and review binary pin changes deliberately. Reboots, driver changes, imports, upgrades, and any recovery that changes disks or boot configuration need their own reviewed maintenance procedure. This guide does not establish an in-place upgrade path.

Before ending use, export needed data to appropriately protected storage and obtain separate explicit approval for a reviewed teardown plan. Do not use destruction as a test or run it from the box being deleted. Verify in the provider account that intended resources were removed and billing ended; stopping Ollama or shutting down the OS is not teardown. Keep protected state until reconciliation is complete, and retain or securely dispose of secrets and records according to your policy.
