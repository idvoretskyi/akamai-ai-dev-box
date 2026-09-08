#!/usr/bin/env bash
# Fresh Ubuntu GPU VM only. Never execute on an existing workstation.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

[[ $EUID -eq 0 ]] || { echo "Root is required." >&2; exit 1; }
# shellcheck source=/dev/null
source /etc/os-release
[[ $ID == ubuntu && $VERSION_ID == 26.04 && $(uname -m) == x86_64 ]] || {
  echo "Only Ubuntu 26.04 x86_64 is supported." >&2
  exit 1
}
# shellcheck source=/dev/null
source /etc/ai-dev-box.env
state=/var/lib/ai-dev-box
install -d -m 0700 "$state"
exec 9>"$state/bootstrap.lock"
flock -n 9 || exit 0
trap 'echo "Bootstrap failed at line $LINENO. Inspect the journal before retrying." >&2' ERR
boot_id=$(cat /proc/sys/kernel/random/boot_id)

if [[ ! -f "$state/kernel-boot-id" ]]; then
  apt-get update
  apt-get install -y linux-generic linux-headers-generic
  update-grub
  printf '%s\n' "$boot_id" > "$state/kernel-boot-id"
  echo "Distribution kernel installed. Reboot scheduled in one minute."
  shutdown -r +1 "AI dev box: boot distribution kernel before NVIDIA installation"
  exit 0
fi
if [[ $(cat "$state/kernel-boot-id") == "$boot_id" ]]; then
  echo "Waiting for the scheduled kernel reboot; no further reboot scheduled." >&2
  exit 1
fi
[[ $(uname -r) == *-generic ]] || {
  echo "Not running the distribution generic kernel. Check the GRUB boot profile." >&2
  exit 1
}

if [[ ! -f "$state/driver-boot-id" ]]; then
  apt-get update
  apt-get install -y "linux-headers-$(uname -r)" ubuntu-drivers-common
  selected_driver=$(ubuntu-drivers devices --gpgpu | awk '/recommended/ { for (i = 1; i <= NF; i++) if ($i ~ /^nvidia-driver-[0-9]+(-server)?(-open)?$/) { print $i; exit } }')
  if [[ -z $selected_driver ]]; then
    selected_driver=$(ubuntu-drivers list --gpgpu | awk '/^nvidia-driver-[0-9]+(-server)?(-open)?$/ { print; exit }')
  fi
  ubuntu-drivers install --gpgpu
  # Ensure userspace utilities match the selected driver family when available.
  if [[ -n $selected_driver ]]; then
    selected_driver=${selected_driver%-open}
    utils_package=${selected_driver/nvidia-driver-/nvidia-utils-}
    if apt-cache show "$utils_package" >/dev/null 2>&1; then
      apt-get install -y "$utils_package"
    else
      echo "Skipping explicit utility package install: $utils_package not available." >&2
    fi
  else
    echo "Unable to identify the recommended NVIDIA driver package; continuing with installed compute stack." >&2
  fi
  update-initramfs -u
  printf '%s\n' "$boot_id" > "$state/driver-boot-id"
  echo "NVIDIA driver installed. Reboot scheduled in one minute."
  shutdown -r +1 "AI dev box: activate NVIDIA kernel modules"
  exit 0
fi
if [[ $(cat "$state/driver-boot-id") == "$boot_id" ]]; then
  echo "Waiting for the scheduled NVIDIA reboot; no further reboot scheduled." >&2
  exit 1
fi

modprobe nvidia_uvm
nvidia-smi
driver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | sort -u)
if [[ ! $driver =~ ^[0-9]+\.[0-9.]+$ ]] || ! dpkg --compare-versions "$driver" ge 550; then
  echo "Ollama requires a working NVIDIA driver >= 550; found: $driver" >&2
  exit 1
fi
printf 'Loaded NVIDIA driver: %s\n' "$driver"
logger -t ai-dev-box "loaded_nvidia_driver=$driver"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl --fail --location --retry 3 \
  "https://github.com/ollama/ollama/releases/download/v$OLLAMA_VERSION/ollama-linux-amd64.tar.zst" \
  -o "$tmp/ollama.tar.zst"
printf '%s  %s\n' "$OLLAMA_SHA256" "$tmp/ollama.tar.zst" | sha256sum --check --status
tar --zstd -xf "$tmp/ollama.tar.zst" -C /usr/local

curl --fail --location --retry 3 \
  "https://github.com/anomalyco/opencode/releases/download/v$OPENCODE_VERSION/opencode-linux-x64.tar.gz" \
  -o "$tmp/opencode.tar.gz"
printf '%s  %s\n' "$OPENCODE_SHA256" "$tmp/opencode.tar.gz" | sha256sum --check --status
install -d "$tmp/opencode"
tar -xzf "$tmp/opencode.tar.gz" -C "$tmp/opencode"
install -m 0755 "$tmp/opencode/opencode" /usr/local/bin/opencode

if ! id ollama >/dev/null 2>&1; then
  useradd --system --user-group --home-dir /var/lib/ollama --shell /usr/sbin/nologin ollama
fi
install -d -o ollama -g ollama -m 0700 /var/lib/ollama /var/lib/ollama/models
for group in video render; do
  if getent group "$group" >/dev/null; then
    usermod -aG "$group" ollama
  fi
done
systemctl daemon-reload
systemctl enable --now ollama
for ((attempt = 1; attempt <= 30; attempt++)); do
  if curl --fail --silent http://127.0.0.1:11434/api/version; then
    /usr/local/bin/opencode --version
    touch "$state/ready"
    echo "GPU and inference service ready. No model has been downloaded."
    exit 0
  fi
  sleep 2
done
echo "Ollama failed its readiness check. Inspect journalctl -u ollama." >&2
exit 1
