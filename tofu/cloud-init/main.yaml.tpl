#cloud-config

hostname: ${jsonencode(hostname)}
fqdn: ${jsonencode(hostname)}
preserve_hostname: false
manage_etc_hosts: true
timezone: ${jsonencode(timezone)}
locale: en_US.UTF-8

package_update: true

packages:
  - ca-certificates
  - curl
  - gnupg
  - sudo
  - git
  - gh
  - zsh
  - tmux
  - vim
  - jq
  - ripgrep
  - htop
  - build-essential
  - python3-venv
  - python3-pip
  - docker.io
  - docker-compose-v2
  - zstd
  - pciutils
  - ubuntu-drivers-common
%{ for p in extra_packages ~}
  - ${jsonencode(p)}
%{ endfor ~}

users:
  - name: ${jsonencode(username)}
    groups:
      - sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys: ${jsonencode(ssh_keys)}

ssh_pwauth: false
disable_root: true

write_files:
  - path: /etc/ssh/sshd_config.d/00-ai-dev-box.conf
    content: |
      PermitRootLogin no
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      ClientAliveInterval 60
      ClientAliveCountMax 3

  - path: /etc/ai-dev-box.env
    permissions: '0600'
    content: |
      OLLAMA_VERSION=${ollama_version}
      OLLAMA_SHA256=${ollama_sha256}
      OPENCODE_VERSION=${opencode_version}
      OPENCODE_SHA256=${opencode_sha256}

  - path: /usr/local/sbin/ai-dev-box-bootstrap
    permissions: '0755'
    content: |
      ${indent(6, bootstrap_script)}

  - path: /etc/systemd/system/ai-dev-box-bootstrap.service
    permissions: '0644'
    content: |
      ${indent(6, service_unit)}

  - path: /etc/systemd/system/ollama.service
    permissions: '0644'
    content: |
      ${indent(6, ollama_unit)}

  - path: /etc/systemd/journald.conf.d/ai-dev-box.conf
    content: |
      [Journal]
      SystemMaxUse=200M
      RuntimeMaxUse=50M

  - path: /etc/apt/apt.conf.d/52-ai-dev-box-reboots
    content: |
      Unattended-Upgrade::Automatic-Reboot "false";

runcmd:
  - |
    bash -euo pipefail << 'RUNCMD'
    sshd -t
    systemctl reload ssh
    systemctl daemon-reload
    systemctl enable --now --no-block ai-dev-box-bootstrap.service
    RUNCMD

final_message: "ai-dev-box cloud-init finished after $UPTIME seconds."
