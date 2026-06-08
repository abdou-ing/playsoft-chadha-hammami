# VM 206 — Wazuh Server (all-in-one)

source "proxmox-clone" "wazuh-server" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  node                 = var.proxmox_node
  vm_id                = var.wazuh_vm_id
  vm_name              = "wazuh-server-{{timestamp}}"
  template_description = "Wazuh Server all-in-one"

  clone_vm_id  = var.clone_vm_id
  full_clone   = true
  task_timeout = "10m"

  cores  = 4
  memory = 8192

  network_adapters {
    model    = "e1000"
    bridge   = "vmbr1"
    firewall = false
  }

  communicator           = "ssh"
  ssh_username           = var.ssh_username
  ssh_password           = var.ssh_password
  ssh_timeout            = "60m"
  ssh_pty                = true
  ssh_handshake_attempts = 20

  ssh_bastion_host             = var.proxmox_host
  ssh_bastion_port             = 22
  ssh_bastion_username         = "abdou"
  ssh_bastion_private_key_file = var.proxmox_bastion_key
}

build {
  name    = "wazuh-server"
  sources = ["source.proxmox-clone.wazuh-server"]

  provisioner "shell" {
    inline = [
      "echo '${var.ssh_password}' | sudo -S bash -c \"echo 'bob ALL=(ALL) NOPASSWD: /usr/bin/systemctl, /usr/bin/apt-get, /usr/bin/dpkg, /usr/sbin/useradd, /usr/bin/chpasswd, /usr/bin/sed, /usr/sbin/iptables, /usr/bin/tee, /usr/bin/cp, /usr/bin/mv, /usr/bin/chmod, /usr/bin/mkdir, /usr/bin/rm, /usr/bin/fuser, /usr/bin/kill, /usr/bin/pkill, /usr/bin/tar, /usr/bin/bash, /usr/bin/env, /usr/sbin/netplan, /usr/sbin/netfilter-persistent, /usr/sbin/update-ca-certificates' > /etc/sudoers.d/bob && chmod 0440 /etc/sudoers.d/bob\""
    ]
  }

  # 1. Upload fichiers
  provisioner "file" {
    source      = "files/config-server.sh"
    destination = "/tmp/config.sh"
  }

  provisioner "file" {
    source      = "files/99-static-server.yaml"
    destination = "/tmp/99-static.yaml"
  }

  # 2. Run config.sh — APT + netplan + install Wazuh
  provisioner "shell" {
    expect_disconnect = true
    valid_exit_codes  = [0, 2300218]
    inline = [
      "chmod u+x /tmp/config.sh",
      "/tmp/config.sh"
    ]
    timeout = "40m"
  }

  # 3. Pause reconnexion après install Wazuh
  provisioner "shell" {
    pause_before = "30s"
    inline       = ["echo '[+] Reconnexion SSH OK'"]
  }

  # 4. Upload + run patch-wazuh.sh
  provisioner "file" {
    source      = "files/patch-wazuh.sh"
    destination = "/tmp/patch-wazuh.sh"
  }

  provisioner "shell" {
    inline = [
      "chmod +x /tmp/patch-wazuh.sh",
      "bash /tmp/patch-wazuh.sh"
    ]
  }

  
}