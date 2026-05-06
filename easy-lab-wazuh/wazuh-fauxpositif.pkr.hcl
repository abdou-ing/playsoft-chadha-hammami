# VM 209 — Faux Positifs SSH

source "proxmox-clone" "wazuh-fauxpositif" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  node                 = var.proxmox_node
  vm_id                = var.fauxpositif_vm_id
  vm_name              = "wazuh-fauxpositif-{{timestamp}}"
  template_description = "Wazuh Lab — Faux Positifs SSH scenario"

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
  name    = "wazuh-fauxpositif"
  sources = ["source.proxmox-clone.wazuh-fauxpositif"]

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
      "sudo systemctl disable unattended-upgrades || true",
      "sudo kill -9 $(pgrep unattended-upgr) 2>/dev/null || true",
      "while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do echo 'Attente lock dpkg...'; sleep 3; done",
      "sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock",
      "sudo dpkg --configure -a || true",
      "sudo apt-get update -y",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y sshpass openssh-client"
    ]
  }

  provisioner "file" {
    source      = "files/99-static-fauxpositif.yaml"
    destination = "/tmp/99-static.yaml"
  }

  provisioner "shell" {
    inline = [
      "sudo rm -f /etc/netplan/01-network-manager-all.yaml",
      "sudo cp /tmp/99-static.yaml /etc/netplan/99-static.yaml",
      "sudo chmod 600 /etc/netplan/99-static.yaml",
      "nohup sudo bash -c 'sleep 5 && netplan apply' > /tmp/netplan.log 2>&1 &",
      "echo '[+] IP statique 10.0.30.56 sera appliquée dans 5s'"
    ]
  }

  # 2. Upload du script puis injection IP + password
  provisioner "file" {
    source      = "files/fauxpositif.sh"
    destination = "/tmp/fauxpositif.sh"
  }

  provisioner "shell" {
    inline = [
      "sed -i 's|__AGENT_IP__|${var.agent_ip}|g' /tmp/fauxpositif.sh",
      "sed -i 's|__TESTUSER_PASS__|${var.testuser_password}|g' /tmp/fauxpositif.sh",
      "sudo cp /tmp/fauxpositif.sh /usr/local/bin/fauxpositif.sh",
      "sudo chmod 0755 /usr/local/bin/fauxpositif.sh",
      "echo '[+] fauxpositif.sh installé avec TARGET_IP=${var.agent_ip}'"
    ]
  }

  # 3. Service systemd
  provisioner "shell" {
    inline = [
      "sudo tee /etc/systemd/system/fauxpositif.service > /dev/null <<'EOF'",
      "[Unit]",
      "Description=Faux Positif SSH Script",
      "[Service]",
      "Type=oneshot",
      "ExecStart=/bin/bash /usr/local/bin/fauxpositif.sh",
      "User=root",
      "EOF"
    ]
  }

  # 4. Timer systemd
  provisioner "shell" {
    inline = [
      "sudo tee /etc/systemd/system/fauxpositif.timer > /dev/null <<'EOF'",
      "[Unit]",
      "Description=Run Faux Positif SSH Script every 10 minutes",
      "[Timer]",
      "OnBootSec=60",
      "OnUnitActiveSec=600",
      "Unit=fauxpositif.service",
      "[Install]",
      "WantedBy=timers.target",
      "EOF",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable fauxpositif.timer",
      "sudo systemctl start fauxpositif.timer",
      "echo '[+] fauxpositif.timer activé'"
    ]
  }

  post-processor "shell-local" {
    environment_vars = [
      "PROXMOX_API_TOKEN_ID=${var.proxmox_api_token_id}",
      "PROXMOX_API_TOKEN_SECRET=${var.proxmox_api_token_secret}",
      "PROXMOX_URL=${var.proxmox_url}",
      "PROXMOX_NODE=${var.proxmox_node}",
      "PROXMOX_HOST=${var.proxmox_host}",
      "VM_ID=${var.fauxpositif_vm_id}"
    ]
    inline = [
      "curl -sk -X PUT -H \"Authorization: PVEAPIToken=$PROXMOX_API_TOKEN_ID=$PROXMOX_API_TOKEN_SECRET\" \"$PROXMOX_URL/nodes/$PROXMOX_NODE/qemu/$VM_ID/config\" -d 'template=0'",
      "ssh -i ${var.proxmox_bastion_key} -o StrictHostKeyChecking=no abdou@${var.proxmox_host} \"sudo chattr -i /var/lib/vz/images/${var.fauxpositif_vm_id}/base-${var.fauxpositif_vm_id}-disk-0.qcow2 || true\"",
      "curl -sk -X POST -H \"Authorization: PVEAPIToken=$PROXMOX_API_TOKEN_ID=$PROXMOX_API_TOKEN_SECRET\" \"$PROXMOX_URL/nodes/$PROXMOX_NODE/qemu/$VM_ID/status/start\"",
      "echo '================================================='",
      "echo ' Faux Positif VM - Build Complete! (VM 209)'",
      "echo '================================================='"
    ]
  }
}
