# VM 207 — Wazuh Agent
# Installe wazuh-agent et le configure pour pointer vers wazuh_ip.
# wazuh_ip est passé par deploy-wazuh.sh après récupération IP de VM 206.

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

  # 0. NOPASSWD sudo
  provisioner "shell" {
    inline = [
      "echo '${var.ssh_password}' | sudo -S bash -c \"echo 'bob ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/bob\""
    ]
  }

  # 1. Prérequis
  provisioner "shell" {
    inline = [
      "sudo systemctl stop unattended-upgrades || true",
      "sudo apt-get update -y",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget"
    ]
  }
  provisioner "file" {
    source      = "files/99-static-agent.yaml"
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
  # 2. Créer testuser (cible des scénarios SSH)
  provisioner "shell" {
    inline = [
      "sudo useradd -m -s /bin/bash testuser || true",
      "echo 'testuser:${var.testuser_password}' | sudo chpasswd"
    ]
  }

  # 3. Activer PasswordAuthentication SSH (requis pour fauxpositif + legit)
  provisioner "shell" {
    inline = [
      "sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config",
      "sudo systemctl restart sshd",
      "echo '[+] PasswordAuthentication activé'"
    ]
  }

# Vérifier que le serveur Wazuh est joignable avant d'installer l'agent
  provisioner "shell" {
    inline = [
      "echo '[*] Attente connectivité Wazuh Server (${var.wazuh_ip})...'",
      "for i in $(seq 1 30); do",
      "  if curl -sk --max-time 5 https://${var.wazuh_ip}:55000 > /dev/null 2>&1 || ping -c1 -W2 ${var.wazuh_ip} > /dev/null 2>&1; then",
      "    echo '[+] Wazuh Server joignable !'",
      "    break",
      "  fi",
      "  echo \"Tentative $i/30 — serveur pas encore prêt, attente 10s...\"",
      "  sleep 10",
      "done"
    ]
  }



  # 4. Télécharger et installer le package wazuh-agent
  provisioner "shell" {
    inline = [
      "curl -sO https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.14.3-1_amd64.deb",
      "sudo WAZUH_MANAGER=${var.wazuh_ip} WAZUH_AGENT_NAME=${var.wazuh_agent_name} dpkg -i wazuh-agent_4.14.3-1_amd64.deb"
    ]
  }

  # 4. Démarrer et activer le service
  provisioner "shell" {
    inline = [
      "sudo systemctl daemon-reload",
      "sudo systemctl enable wazuh-agent",
      "sudo systemctl start wazuh-agent"
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
      "echo ' Wazuh Agent - Build Complete! (VM 207)'",
      "echo '================================================='"
    ]
  }
}
