# VM 207 — Wazuh Agent
# Packer installe wazuh-agent SANS le connecter au manager.
# La connexion se fait au premier boot via wazuh-register.service.

source "proxmox-clone" "wazuh-agent" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  node                 = var.proxmox_node
  vm_id                = var.agent_vm_id
  vm_name              = "wazuh-agent-{{timestamp}}"
  template_description = "Wazuh Agent — envoie logs vers Wazuh Server"

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
  name    = "wazuh-agent"
  sources = ["source.proxmox-clone.wazuh-agent"]

  provisioner "shell" {
    inline = [
      "echo '${var.ssh_password}' | sudo -S bash -c \"echo 'bob ALL=(ALL) NOPASSWD: /usr/bin/systemctl, /usr/bin/apt-get, /usr/bin/dpkg, /usr/sbin/useradd, /usr/sbin/chpasswd, /usr/bin/sed, /usr/sbin/iptables, /usr/bin/tee, /usr/bin/cp, /usr/bin/mv, /usr/bin/chmod, /usr/bin/mkdir, /usr/bin/rm, /usr/bin/fuser, /usr/bin/kill, /usr/bin/pkill, /usr/bin/tar, /usr/bin/bash, /usr/bin/env, /usr/sbin/netplan, /usr/sbin/netfilter-persistent, /usr/sbin/update-ca-certificates' > /etc/sudoers.d/bob && chmod 0440 /etc/sudoers.d/bob\""
    ]
  }

  # 1. Upload config-agent.sh (installation sans connexion au manager)
  provisioner "file" {
    source      = "files/config-agent.sh"
    destination = "/tmp/config.sh"
  }

  # 2. Upload netplan
  provisioner "file" {
    source      = "files/99-static-agent.yaml"
    destination = "/tmp/99-static.yaml"
  }

  # 3. Upload script d'enregistrement (s'exécute au premier boot)
  provisioner "file" {
    source      = "files/wazuh-register.sh"
    destination = "/tmp/wazuh-register.sh"
  }

  # 4. Upload service systemd
  provisioner "file" {
    source      = "files/wazuh-register.service"
    destination = "/tmp/wazuh-register.service"
  }

  # 5. Run config.sh — installe wazuh-agent, crée testuser, configure netplan
  provisioner "shell" {
    environment_vars = [
      "WAZUH_IP=${var.wazuh_ip}",
      "AGENT_NAME=${var.wazuh_agent_name}",
      "TESTUSER_PASSWORD=${var.testuser_password}"
    ]
    inline = [
      "chmod u+x /tmp/config.sh",
      "/tmp/config.sh"
    ]
  }

  # 6. Installe wazuh-register.service (enregistrement au premier boot)
  provisioner "shell" {
    environment_vars = [
      "WAZUH_IP=${var.wazuh_ip}",
      "AGENT_NAME=${var.wazuh_agent_name}"
    ]
    inline = [
      # Place le script dans /usr/local/bin/
      "sudo mv /tmp/wazuh-register.sh /usr/local/bin/wazuh-register.sh",
      "sudo chmod +x /usr/local/bin/wazuh-register.sh",

      # Écrit les variables dans un fichier d'env lu par le script au boot
      "echo \"WAZUH_IP=$WAZUH_IP\" | sudo tee /etc/wazuh-register.env > /dev/null",
      "echo \"AGENT_NAME=$AGENT_NAME\" | sudo tee -a /etc/wazuh-register.env > /dev/null",
      "sudo chmod 600 /etc/wazuh-register.env",

      # Installe et active le service systemd
      "sudo mv /tmp/wazuh-register.service /etc/systemd/system/wazuh-register.service",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable wazuh-register.service",

      "echo '[+] wazuh-register.service installé et activé'"
    ]
  }
}
