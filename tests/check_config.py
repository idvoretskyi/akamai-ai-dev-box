"""Render cloud-init with synthetic values; never execute bootstrap or providers."""

import json
from pathlib import Path
import re
import subprocess
import tempfile
import yaml

ROOT = Path(__file__).resolve().parents[1]
TOFU = ROOT / "tofu"

FAILURES: list[str] = []


def check(condition: bool, message: str) -> None:
    """Record a readable failure instead of a bare assert traceback."""
    if not condition:
        FAILURES.append(message)


with tempfile.TemporaryDirectory(prefix="ai-dev-box-render-") as directory:
    # Standalone locals-only module: no state, provider, credentials or API calls.
    # Mirrors tofu/locals.tf's `cloud_init` templatefile call so the rendered
    # config matches what tofu/main.tf actually feeds the instance.
    main_tf = f'''
locals {{
  bootstrap_script = file("{TOFU}/cloud-init/bootstrap.sh")
  service_unit     = file("{TOFU}/cloud-init/ai-dev-box-bootstrap.service")
  ollama_unit      = file("{TOFU}/cloud-init/ollama.service")

  releases = jsondecode(file("{TOFU}/cloud-init/releases.json"))

  cloud_init = templatefile("{TOFU}/cloud-init/main.yaml.tpl", {{
    username         = "testdev"
    hostname         = "test-ai-dev-box"
    timezone         = "UTC"
    ssh_keys         = ["ssh-ed25519 dGVzdA== synthetic"]
    extra_packages   = []
    ollama_version   = local.releases.ollama.version
    ollama_sha256    = local.releases.ollama.sha256
    opencode_version = local.releases.opencode.version
    opencode_sha256  = local.releases.opencode.sha256
    bootstrap_script = local.bootstrap_script
    service_unit     = local.service_unit
    ollama_unit      = local.ollama_unit
  }})
}}
'''
    (Path(directory) / "main.tf").write_text(main_tf)

    # `tofu console` prints a JSON-encoded string (jsonencode) to stdout, which
    # is itself valid JSON, hence the double json.loads. This is sensitive to
    # OpenTofu's console output format; CI pins the OpenTofu version.
    rendered = subprocess.run(
        ["tofu", "console", "-no-color"], cwd=directory,
        input="jsonencode(local.cloud_init)\n", text=True,
        capture_output=True, check=True, timeout=60,
    )
    config = yaml.safe_load(json.loads(json.loads(rendered.stdout)))

check(config["hostname"] == "test-ai-dev-box", "hostname not rendered correctly")
check(config["ssh_pwauth"] is False, "ssh_pwauth must be false")
check(config["disable_root"] is True, "disable_root must be true")
check("default" not in config["users"], "cloud-init must not configure a 'default' user")
check(config["users"][0]["groups"] == ["sudo"], "non-root user must only be in the sudo group (not docker)")

files = {entry["path"]: entry for entry in config["write_files"]}

env_file = files["/etc/ai-dev-box.env"]
check(env_file.get("permissions") == "0600", "/etc/ai-dev-box.env must be 0600")
check("LINODE_TOKEN" not in env_file["content"], "provider token must never reach the instance")

bootstrap_file = files["/usr/local/sbin/ai-dev-box-bootstrap"]
check(bootstrap_file.get("permissions") == "0755", "bootstrap script must be 0755")
bootstrap = bootstrap_file["content"]
subprocess.run(["bash", "-n"], input=bootstrap, text=True, check=True, timeout=10)

service_file = files["/etc/systemd/system/ai-dev-box-bootstrap.service"]
check(
    "ExecStart=/usr/local/sbin/ai-dev-box-bootstrap" in service_file["content"],
    "service ExecStart must match the installed bootstrap script path",
)

for marker in ("kernel-boot-id", "driver-boot-id"):
    check(f'$(cat "$state/{marker}") == "$boot_id"' in bootstrap, f"missing {marker} comparison")
check(
    bootstrap.index("modprobe nvidia_uvm") < bootstrap.index("systemctl enable --now ollama"),
    "GPU validation must happen before enabling ollama",
)
check(
    bootstrap.index('touch "$state/ready"') > bootstrap.index("/api/version"),
    "ready marker must be written only after the ollama readiness check",
)
check(
    'selected_driver=$(ubuntu-drivers list --gpgpu --recommended' in bootstrap,
    "driver selection must come from ubuntu-drivers list --gpgpu --recommended",
)
check(
    'apt-get install -y "$selected_driver"' in bootstrap,
    "must install the exact listed driver package (not a separate ubuntu-drivers install pass)",
)
check("ubuntu-drivers install --gpgpu" not in bootstrap, "must not re-run ubuntu-drivers' own selection")
check("ollama pull" not in bootstrap, "bootstrap must not download models")
check('logger -t ai-dev-box "loaded_nvidia_driver=' in bootstrap, "must record the loaded driver version")
check(
    "flock -n 9 ||" in bootstrap and "exit 1" in bootstrap.split("flock -n 9 ||", 1)[1].splitlines()[0],
    "lock contention must fail loudly (exit 1), not silently succeed",
)

runcmd_entry = config["runcmd"][0]
check("--no-block" in runcmd_entry, "bootstrap enablement must not block cloud-init")
check("-euo pipefail" in runcmd_entry, "runcmd must run under strict mode")

check(
    "After=network-online.target cloud-final.service" in service_file["content"],
    "service must start after network and cloud-final",
)
check(
    "ConditionPathExists=/var/lib/cloud/instance/boot-finished" in service_file["content"],
    "service must wait for cloud-init boot-finished",
)

sshd_conf = files["/etc/ssh/sshd_config.d/00-ai-dev-box.conf"]["content"]
for directive in ("PermitRootLogin no", "PasswordAuthentication no", "KbdInteractiveAuthentication no"):
    check(directive in sshd_conf, f"sshd_config.d must set: {directive}")

service = files["/etc/systemd/system/ollama.service"]["content"]
for setting in (
    "User=ollama", "OLLAMA_HOST=127.0.0.1:11434", "OLLAMA_NO_CLOUD=1",
    "OLLAMA_NUM_PARALLEL=1", "OLLAMA_MAX_LOADED_MODELS=1",
    "OLLAMA_CONTEXT_LENGTH=16384", "MemoryMax=10G", "CPUQuota=200%",
    "ExecStartPre=/usr/bin/nvidia-smi",
):
    check(setting in service, f"ollama.service missing required setting: {setting}")
check("PrivateDevices=true" not in service, "ollama.service must not set PrivateDevices=true (GPU device access)")
check(service.count("OLLAMA_HOST=") == 1, "ollama.service must set OLLAMA_HOST exactly once (loopback only)")

releases = json.loads((TOFU / "cloud-init/releases.json").read_text())
for name, release in releases.items():
    check(re.fullmatch(r"\d+\.\d+\.\d+", release["version"]) is not None, f"{name} version must be X.Y.Z")
    check(re.fullmatch(r"[a-f0-9]{64}", release["sha256"]) is not None, f"{name} sha256 must be 64 hex chars")

for mode in ("hybrid", "local-only"):
    example = json.loads((ROOT / f"examples/opencode/{mode}.json").read_text())
    check(example["$schema"] == "https://opencode.ai/config.json", f"{mode}: wrong $schema")
    check(example["model"] == example["small_model"] == "ollama/dev-coder", f"{mode}: model/small_model mismatch")
    check(example["provider"]["ollama"]["npm"] == "@ai-sdk/openai-compatible", f"{mode}: wrong provider npm package")
    check(
        example["provider"]["ollama"]["options"]["baseURL"] == "http://127.0.0.1:11434/v1",
        f"{mode}: baseURL must be loopback",
    )
    check(example["provider"]["ollama"]["models"]["dev-coder"]["tool_call"] is True, f"{mode}: tool_call must be true")
    check(example["share"] == "disabled", f"{mode}: share must be disabled")
    check(example["autoupdate"] is False, f"{mode}: autoupdate must be false")
    check(example["permission"]["edit"] == "ask", f"{mode}: permission.edit must be ask")
    check(example["permission"]["bash"] == "ask", f"{mode}: permission.bash must be ask")
    check(
        example["provider"]["ollama"]["models"]["dev-coder"]["limit"] == {"context": 16384, "output": 4096},
        f"{mode}: context/output limit mismatch",
    )
    expected_providers = ["ollama"] if mode == "local-only" else ["ollama", "github-copilot"]
    check(example["enabled_providers"] == expected_providers, f"{mode}: enabled_providers mismatch")

if FAILURES:
    for failure in FAILURES:
        print(f"FAIL: {failure}")
    raise SystemExit(f"{len(FAILURES)} check(s) failed")

print("PASS: cloud-init rendering, bootstrap invariants, and OpenCode schema/examples")
