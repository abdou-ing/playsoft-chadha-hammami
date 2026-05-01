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
      "echo '[+] APT lock libéré'",
      "sudo apt-get update -y",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget tar"
    ]
  }

  provisioner "file" {
    source      = "files/99-static-server.yaml"
    destination = "/tmp/99-static.yaml"
  }

  provisioner "shell" {
    inline = [
      "sudo rm -f /etc/netplan/01-network-manager-all.yaml",
      "sudo cp /tmp/99-static.yaml /etc/netplan/99-static.yaml",
      "sudo chmod 600 /etc/netplan/99-static.yaml",
      "nohup sudo bash -c 'sleep 5 && netplan apply' > /tmp/netplan.log 2>&1 &",
      "echo '[+] IP statique 10.0.30.42 sera appliquée dans 5s'"
    ]
  }

  # 2. Installation Wazuh all-in-one
  provisioner "shell" {
    expect_disconnect = true
    valid_exit_codes  = [0, 2300218]
    inline = [
      "curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh",
      "sudo bash wazuh-install.sh -a --overwrite",
      "echo \"[*] tar trouvé : $(sudo find /home/bob /tmp /root -name 'wazuh-install-files.tar' 2>/dev/null | head -1)\"",
      "sudo chmod 644 /home/bob/wazuh-install-files.tar",
      "echo '[+] wazuh-install-files.tar prêt'"
    ]
    timeout = "40m"
  }

  # Pause reconnexion après install Wazuh
  provisioner "shell" {
    pause_before = "30s"
    inline = [
      "echo '[+] Reconnexion SSH après installation Wazuh'",
      "sudo systemctl status wazuh-manager --no-pager || true"
    ]
  }

  # 3. Upload patch-wazuh.sh (fichier externe — évite les problèmes HCL heredoc)
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

  # 4. Afficher les credentials dans les logs Packer
  provisioner "shell" {
    inline = [
      "echo '========== WAZUH CREDENTIALS =========='",
      "sudo tar -O -xf /home/bob/wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt 2>/dev/null | grep -A2 'Admin user' | head -6",
      "echo '========================================'",
      "echo '[+] Password admin fixé : Admin1234!'"
    ]
  }

  post-processor "shell-local" {
    environment_vars = [
      "PROXMOX_API_TOKEN_ID=${var.proxmox_api_token_id}",
      "PROXMOX_API_TOKEN_SECRET=${var.proxmox_api_token_secret}",
      "PROXMOX_URL=${var.proxmox_url}",
      "PROXMOX_NODE=${var.proxmox_node}",
      "PROXMOX_HOST=${var.proxmox_host}",
      "VM_ID=${var.wazuh_vm_id}"
    ]
    inline = [
      "curl -sk -X PUT -H \"Authorization: PVEAPIToken=$PROXMOX_API_TOKEN_ID=$PROXMOX_API_TOKEN_SECRET\" \"$PROXMOX_URL/nodes/$PROXMOX_NODE/qemu/$VM_ID/config\" -d 'template=0'",
      "ssh -i ${var.proxmox_bastion_key} -o StrictHostKeyChecking=no abdou@${var.proxmox_host} \"sudo chattr -i /var/lib/vz/images/${var.wazuh_vm_id}/base-${var.wazuh_vm_id}-disk-0.qcow2 || true\"",
      "curl -sk -X POST -H \"Authorization: PVEAPIToken=$PROXMOX_API_TOKEN_ID=$PROXMOX_API_TOKEN_SECRET\" \"$PROXMOX_URL/nodes/$PROXMOX_NODE/qemu/$VM_ID/status/start\"",
      "echo '================================================='",
      "echo ' Wazuh Server - Build Complete! (VM 206)'",
      "echo '================================================='"
    ]
  }
}
