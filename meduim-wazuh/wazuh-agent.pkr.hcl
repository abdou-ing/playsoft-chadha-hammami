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

  # 0. NOPASSWD sudo
  provisioner "shell" {
    inline = [
      "echo '${var.ssh_password}' | sudo -S bash -c \"echo 'bob ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/bob\""
    ]
  }

  # 1. Tuer APT lock + prérequis
  provisioner "shell" {
    inline = [
      "sudo systemctl stop unattended-upgrades || true",
      "sudo systemctl disable unattended-upgrades || true",
      "sudo systemctl stop apt-daily.timer apt-daily-upgrade.timer || true",
      "sudo systemctl disable apt-daily.timer apt-daily-upgrade.timer || true",
      "sudo systemctl kill --kill-who=all apt-daily.service apt-daily-upgrade.service || true",
      "echo '[*] Attente libération lock APT...'",
      "for i in $(seq 1 30); do sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || break; echo \"Lock APT occupé, attente 5s ($i/30)...\"; sleep 5; done",
      "sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock || true",
      "sudo dpkg --configure -a || true",
      "sudo apt-get update -y",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget iptables-persistent"
    ]
  }

  # 2. Créer testuser (cible des scénarios SSH)
  provisioner "shell" {
    inline = [
      "sudo useradd -m -s /bin/bash testuser || true",
      "echo 'testuser:${var.testuser_password}' | sudo chpasswd",
      "echo '[+] testuser créé'"
    ]
  }

  # 3. Activer PasswordAuthentication SSH
  provisioner "shell" {
    inline = [
      "sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config",
      "sudo systemctl restart sshd",
      "echo '[+] PasswordAuthentication activé'"
    ]
  }

  # 4. IP statique
  provisioner "file" {
    source      = "files/99-static-agent-medium.yaml"
    destination = "/tmp/99-static.yaml"
  }

  provisioner "shell" {
    inline = [
      "sudo rm -f /etc/netplan/01-network-manager-all.yaml",
      "sudo cp /tmp/99-static.yaml /etc/netplan/99-static.yaml",
      "sudo chmod 600 /etc/netplan/99-static.yaml",
      "nohup sudo bash -c 'sleep 5 && netplan apply' > /tmp/netplan.log 2>&1 &",
      "echo '[+] IP statique 10.0.30.47 sera appliquée dans 5s'"
    ]
  }




  # 5. Bloquer port 1514 — LE CHALLENGE ÉTUDIANT
  # L'étudiant doit découvrir cette règle via les logs wazuh-agent
  # puis la supprimer avec : sudo iptables -D OUTPUT -p tcp --dport 1514 -j DROP
  provisioner "shell" {
    inline = [
      "sudo iptables -A OUTPUT -p tcp --dport 1514 -j DROP",
      "sudo iptables -A OUTPUT -p udp --dport 1514 -j DROP",
      "sudo mkdir -p /etc/iptables",
      "sudo sh -c 'iptables-save > /etc/iptables/rules.v4'",
      "echo '[+] Port 1514 bloqué en sortie — challenge étudiant actif'"
    ]
  }

  # 6. Persister les règles iptables au reboot
  provisioner "shell" {
    inline = [
      "sudo systemctl enable netfilter-persistent || true",
      "sudo netfilter-persistent save || true",
      "echo '[+] Règles iptables persistées'"
    ]
  }

  post-processor "shell-local" {
    environment_vars = [
      "PROXMOX_API_TOKEN_ID=${var.proxmox_api_token_id}",
      "PROXMOX_API_TOKEN_SECRET=${var.proxmox_api_token_secret}",
      "PROXMOX_URL=${var.proxmox_url}",
      "PROXMOX_NODE=${var.proxmox_node}",
      "PROXMOX_HOST=${var.proxmox_host}",
      "VM_ID=${var.agent_vm_id}"
    ]
    inline = [
      "curl -sk -X PUT -H \"Authorization: PVEAPIToken=$PROXMOX_API_TOKEN_ID=$PROXMOX_API_TOKEN_SECRET\" \"$PROXMOX_URL/nodes/$PROXMOX_NODE/qemu/$VM_ID/config\" -d 'template=0'",
      "ssh -i ${var.proxmox_bastion_key} -o StrictHostKeyChecking=no abdou@${var.proxmox_host} \"sudo chattr -i /var/lib/vz/images/${var.agent_vm_id}/base-${var.agent_vm_id}-disk-0.qcow2 || true\"",
      "curl -sk -X POST -H \"Authorization: PVEAPIToken=$PROXMOX_API_TOKEN_ID=$PROXMOX_API_TOKEN_SECRET\" \"$PROXMOX_URL/nodes/$PROXMOX_NODE/qemu/$VM_ID/status/start\"",
      "echo '================================================='",
      "echo ' Wazuh Agent Medium - Build Complete! (VM 212)'",
      "echo '================================================='"
    ]
  }
}
