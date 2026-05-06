# VM 208 — Attaque Brute Force SSH

source "proxmox-clone" "wazuh-attack" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  node                 = var.proxmox_node
  vm_id                = var.attack_vm_id
  vm_name              = "wazuh-attack-{{timestamp}}"
  template_description = "Wazuh Lab — Brute Force SSH scenario"

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
  name    = "wazuh-attack"
  sources = ["source.proxmox-clone.wazuh-attack"]

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
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-client"
    ]
  }
  provisioner "file" {
    source      = "files/99-static-attack.yaml"
    destination = "/tmp/99-static.yaml"
  }

  provisioner "shell" {
    inline = [
      "sudo rm -f /etc/netplan/01-network-manager-all.yaml",
      "sudo cp /tmp/99-static.yaml /etc/netplan/99-static.yaml",
      "sudo chmod 600 /etc/netplan/99-static.yaml",
      "nohup sudo bash -c 'sleep 5 && netplan apply' > /tmp/netplan.log 2>&1 &",
      "echo '[+] IP statique 10.0.30.65 sera appliquée dans 5s'"
    ]
  }
  # 2. Upload du script puis injection de l'IP agent
  provisioner "file" {
    source      = "files/autoattack2.sh"
    destination = "/tmp/autoattack2.sh"
  }

  provisioner "shell" {
    inline = [
      "sed -i 's|__AGENT_IP__|${var.agent_ip}|g' /tmp/autoattack2.sh",
      "sudo cp /tmp/autoattack2.sh /usr/local/bin/autoattack2.sh",
      "sudo chmod 0755 /usr/local/bin/autoattack2.sh",
      "echo '[+] autoattack2.sh installé avec TARGET_IP=${var.agent_ip}'"
    ]
  }

  # 3. Service systemd
  provisioner "shell" {
    inline = [
      "sudo tee /etc/systemd/system/autoattack2.service > /dev/null <<'EOF'",
      "[Unit]",
      "Description=Auto Attack Script v2",
      "[Service]",
      "Type=oneshot",
      "ExecStart=/bin/bash /usr/local/bin/autoattack2.sh",
      "User=root",
      "Environment=\"PATH=/usr/bin:/bin:/usr/sbin:/sbin\"",
      "EOF"
    ]
  }

  # 4. Timer systemd
  provisioner "shell" {
    inline = [
      "sudo tee /etc/systemd/system/autoattack2.timer > /dev/null <<'EOF'",
      "[Unit]",
      "Description=Run Auto Attack Script v2 every 10 minutes",
      "[Timer]",
      "OnBootSec=60",
      "OnUnitActiveSec=600",
      "Unit=autoattack2.service",
      "[Install]",
      "WantedBy=timers.target",
      "EOF",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable autoattack2.timer",
      "sudo systemctl start autoattack2.timer",
      "echo '[+] autoattack2.timer activé'"
    ]
  }

  post-processor "shell-local" {
    environment_vars = [
      "PROXMOX_API_TOKEN_ID=${var.proxmox_api_token_id}",
      "PROXMOX_API_TOKEN_SECRET=${var.proxmox_api_token_secret}",
      "PROXMOX_URL=${var.proxmox_url}",
      "PROXMOX_NODE=${var.proxmox_node}",
      "PROXMOX_HOST=${var.proxmox_host}",
      "VM_ID=${var.attack_vm_id}"
    ]
    inline = [
      "curl -sk -X PUT -H \"Authorization: PVEAPIToken=$PROXMOX_API_TOKEN_ID=$PROXMOX_API_TOKEN_SECRET\" \"$PROXMOX_URL/nodes/$PROXMOX_NODE/qemu/$VM_ID/config\" -d 'template=0'",
      "ssh -i ${var.proxmox_bastion_key} -o StrictHostKeyChecking=no abdou@${var.proxmox_host} \"sudo chattr -i /var/lib/vz/images/${var.attack_vm_id}/base-${var.attack_vm_id}-disk-0.qcow2 || true\"",
      "curl -sk -X POST -H \"Authorization: PVEAPIToken=$PROXMOX_API_TOKEN_ID=$PROXMOX_API_TOKEN_SECRET\" \"$PROXMOX_URL/nodes/$PROXMOX_NODE/qemu/$VM_ID/status/start\"",
      "echo '================================================='",
      "echo ' Attack VM - Build Complete! (VM 208)'",
      "echo '================================================='"
    ]
  }
}
