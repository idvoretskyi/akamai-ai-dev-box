locals {
  releases = jsondecode(file("${path.module}/cloud-init/releases.json"))
  cloud_init = join("\n", ["#cloud-config", yamlencode({
    hostname       = var.label
    timezone       = "UTC"
    ssh_pwauth     = false
    disable_root   = true
    package_update = true
    packages       = ["ca-certificates", "curl", "jq", "git", "gh", "tmux", "vim", "ripgrep", "htop", "build-essential", "python3-venv", "python3-pip", "docker.io", "docker-compose-v2", "zstd", "pciutils", "ubuntu-drivers-common"]
    users = [{
      name                = var.username
      groups              = ["sudo"]
      shell               = "/bin/bash"
      sudo                = "ALL=(ALL) NOPASSWD:ALL"
      lock_passwd         = true
      ssh_authorized_keys = var.ssh_public_keys
    }]
    write_files = [
      {
        path        = "/etc/ssh/sshd_config.d/00-ai-dev-box.conf"
        permissions = "0644"
        content     = "PermitRootLogin no\nPasswordAuthentication no\nKbdInteractiveAuthentication no\nClientAliveInterval 60\nClientAliveCountMax 3\n"
      },
      {
        path        = "/etc/ai-dev-box.env"
        permissions = "0600"
        content     = "OLLAMA_VERSION=${local.releases.ollama.version}\nOLLAMA_SHA256=${local.releases.ollama.sha256}\nOPENCODE_VERSION=${local.releases.opencode.version}\nOPENCODE_SHA256=${local.releases.opencode.sha256}\n"
      },
      {
        path        = "/usr/local/sbin/ai-dev-box-bootstrap"
        permissions = "0755"
        content     = file("${path.module}/cloud-init/bootstrap.sh")
      },
      {
        path        = "/etc/systemd/system/ai-dev-box-bootstrap.service"
        permissions = "0644"
        content     = file("${path.module}/cloud-init/ai-dev-box-bootstrap.service")
      },
      {
        path        = "/etc/systemd/system/ollama.service"
        permissions = "0644"
        content     = file("${path.module}/cloud-init/ollama.service")
      },
      {
        path        = "/etc/systemd/journald.conf.d/ai-dev-box.conf"
        permissions = "0644"
        content     = "[Journal]\nSystemMaxUse=200M\nRuntimeMaxUse=50M\n"
      },
      {
        path        = "/etc/apt/apt.conf.d/52-ai-dev-box-reboots"
        permissions = "0644"
        content     = "Unattended-Upgrade::Automatic-Reboot \"false\";\n"
      }
    ]
    runcmd = [["bash", "-lc", "set -euo pipefail; sshd -t; systemctl reload ssh; systemctl daemon-reload; systemctl enable --now --no-block ai-dev-box-bootstrap.service"]]
  })])
}
