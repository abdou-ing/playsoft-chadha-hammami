# VM 212 — Wazuh Agent Medium
# VM Ubuntu vide — l'étudiant installe wazuh-agent manuellement.
# Le port 1514 est bloqué par iptables : l'étudiant doit diagnostiquer et débloquer.

source "proxmox-clone" "wazuh-agent-medium" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  node                 = var.proxmox_node
  vm_id                = var.agent_vm_id
  vm_name              = "wazuh-agent-medium-{{timestamp}}"
  template_description = "Wazuh Agent Medium — VM vide avec port 1514 bloqué"

  clone_vm_id  = var.clone_vm_id
  full_clone   = true
  task_timeout = "10m"

  cores  = 2
  memory = 2048

  network_adapters {
    model    = "e1000"
    bridge   = "vmbr1"
    firewall = false
  }

  communicator           = "ssh"
  ssh_username           = var.ssh_username
  ssh_password           = var.ssh_password
  ssh_timeout            = "20m"
  ssh_pty                = true
  ssh_handshake_attempts = 20

  ssh_bastion_host             = var.proxmox_host
  ssh_bastion_port             = 22
  ssh_bastion_username         = "abdou"
  ssh_bastion_private_key_file = var.proxmox_bastion_key
}

build {
  name    = "wazuh-agent-medium"
  sources = ["source.proxmox-clone.wazuh-agent-medium"]

  provisioner "shell" {
    inline = [
      "echo '${var.ssh_password}' | sudo -S bash -c \"echo 'bob ALL=(ALL) NOPASSWD: /usr/bin/systemctl, /usr/bin/apt-get, /usr/bin/dpkg, /usr/sbin/useradd, /usr/bin/chpasswd, /usr/bin/sed, /usr/sbin/iptables, /usr/bin/tee, /usr/bin/cp, /usr/bin/chmod, /usr/bin/mkdir, /usr/bin/rm, /usr/bin/fuser, /usr/bin/kill, /usr/bin/pkill, /usr/bin/sh, /usr/bin/bash, /usr/sbin/netplan, /usr/sbin/netfilter-persistent, /usr/sbin/dpkg-reconfigure' > /etc/sudoers.d/bob && chmod 0440 /etc/sudoers.d/bob\""
    ]
  }

  # 1. Upload fichiers
  provisioner "file" {
    source      = "files/config-agent-medium.sh"
    destination = "/tmp/config.sh"
  }

  provisioner "file" {
    source      = "files/99-static-agent-medium.yaml"
    destination = "/tmp/99-static.yaml"
  }

  # 2. IP statique
  provisioner "shell" {
    inline = [
      "sudo rm -f /etc/netplan/01-network-manager-all.yaml",
      "sudo cp /tmp/99-static.yaml /etc/netplan/99-static.yaml",
      "sudo chmod 600 /etc/netplan/99-static.yaml",
      "nohup sudo bash -c 'sleep 5 && netplan apply' > /tmp/netplan.log 2>&1 &"
    ]
  }

  # 3. Run config.sh
  provisioner "shell" {
    environment_vars = [
      "TESTUSER_PASSWORD=${var.testuser_password}"
    ]
    inline = [
      "echo '[INFO] Running /tmp/config.sh...'",
      "chmod u+x /tmp/config.sh",
      "/tmp/config.sh"
    ]
  }

  
}