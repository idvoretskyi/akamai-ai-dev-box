"""Render cloud-init with synthetic values; never execute bootstrap or providers."""

import json
from pathlib import Path
import re
import subprocess
import tempfile
import yaml

ROOT = Path(__file__).resolve().parents[1]
TOFU = ROOT / "tofu"

with tempfile.TemporaryDirectory(prefix="ai-dev-box-render-") as directory:
    # Standalone locals-only module: no state, provider, credentials or API calls.
    source = (TOFU / "cloud-init.tf").read_text().replace(
        "${path.module}/cloud-init/", f"{TOFU}/cloud-init/"
    )
    (Path(directory) / "main.tf").write_text(source)
    (Path(directory) / "variables.tf").write_text('''
variable "label" { default = "test-ai-dev-box" }
variable "username" { default = "testdev" }
variable "ssh_public_keys" { default = ["ssh-ed25519 dGVzdA== synthetic"] }
''')
    rendered = subprocess.run(
        ["tofu", "console", "-no-color"], cwd=directory,
        input="jsonencode(local.cloud_init)\n", text=True,
        capture_output=True, check=True,
    )
    config = yaml.safe_load(json.loads(json.loads(rendered.stdout)))

assert config["hostname"] == "test-ai-dev-box"
assert config["ssh_pwauth"] is False and config["disable_root"] is True
assert "default" not in config["users"]
assert config["users"][0]["groups"] == ["sudo"]
files = {entry["path"]: entry for entry in config["write_files"]}
bootstrap = files["/usr/local/sbin/ai-dev-box-bootstrap"]["content"]
subprocess.run(["bash", "-n"], input=bootstrap, text=True, check=True)
for marker in ("kernel-boot-id", "driver-boot-id"):
    assert f'$(cat "$state/{marker}") == "$boot_id"' in bootstrap
assert bootstrap.index("modprobe nvidia_uvm") < bootstrap.index("systemctl enable --now ollama")
assert bootstrap.index('touch "$state/ready"') > bootstrap.index("/api/version")
assert "ubuntu-drivers install --gpgpu" in bootstrap
assert "ollama pull" not in bootstrap
assert "LINODE_TOKEN" not in files["/etc/ai-dev-box.env"]["content"]
assert "--no-block" in config["runcmd"][0][-1]
assert "set -euo pipefail" in config["runcmd"][0][-1]
assert "selected_driver=$(ubuntu-drivers devices --gpgpu" in bootstrap
assert "logger -t ai-dev-box \"loaded_nvidia_driver=" in bootstrap
assert "After=network-online.target cloud-final.service" in files[
    "/etc/systemd/system/ai-dev-box-bootstrap.service"
]["content"]
assert "ConditionPathExists=/var/lib/cloud/instance/boot-finished" in files[
    "/etc/systemd/system/ai-dev-box-bootstrap.service"
]["content"]
service = files["/etc/systemd/system/ollama.service"]["content"]
for setting in (
    "User=ollama", "OLLAMA_HOST=127.0.0.1:11434", "OLLAMA_NO_CLOUD=1",
    "OLLAMA_NUM_PARALLEL=1", "OLLAMA_MAX_LOADED_MODELS=1",
    "OLLAMA_CONTEXT_LENGTH=16384", "MemoryMax=10G", "CPUQuota=200%",
    "ExecStartPre=/usr/bin/nvidia-smi",
):
    assert setting in service
assert "PrivateDevices=true" not in service

releases = json.loads((TOFU / "cloud-init/releases.json").read_text())
for release in releases.values():
    assert re.fullmatch(r"\d+\.\d+\.\d+", release["version"])
    assert re.fullmatch(r"[a-f0-9]{64}", release["sha256"])

for mode in ("hybrid", "local-only"):
    example = json.loads((ROOT / f"examples/opencode/{mode}.json").read_text())
    assert example["$schema"] == "https://opencode.ai/config.json"
    assert example["model"] == example["small_model"] == "ollama/dev-coder"
    assert example["provider"]["ollama"]["npm"] == "@ai-sdk/openai-compatible"
    assert example["provider"]["ollama"]["options"]["baseURL"] == "http://127.0.0.1:11434/v1"
    assert example["provider"]["ollama"]["models"]["dev-coder"]["tool_call"] is True
    assert example["share"] == "disabled"
    assert example["autoupdate"] is False
    assert example["permission"]["edit"] == "ask"
    assert example["permission"]["bash"] == "ask"
    assert example["provider"]["ollama"]["models"]["dev-coder"]["limit"] == {
        "context": 16384, "output": 4096,
    }
    assert example["enabled_providers"] == (
        ["ollama"] if mode == "local-only" else ["ollama", "github-copilot"]
    )
print("PASS: cloud-init rendering, bootstrap invariants, and OpenCode schema/examples")
