# VM 211 — Wazuh Server Medium
# VM Ubuntu vide — l'étudiant installe Wazuh manuellement.
# Packer configure uniquement l'IP statique et les prérequis de base.

source "proxmox-clone" "wazuh-server-medium" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  node                 = var.proxmox_node
  vm_id                = var.server_vm_id
  vm_name              = "wazuh-server-medium-{{timestamp}}"
  template_description = "Wazuh Server Medium — VM vide pour installation manuelle"

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
  ssh_timeout            = "20m"
  ssh_pty                = true
  ssh_handshake_attempts = 20

  ssh_bastion_host             = var.proxmox_host
  ssh_bastion_port             = 22
  ssh_bastion_username         = "abdou"
  ssh_bastion_private_key_file = var.proxmox_bastion_key
}

build {
  name    = "wazuh-server-medium"
  sources = ["source.proxmox-clone.wazuh-server-medium"]

  # 0. NOPASSWD sudo
  provisioner "shell" {
    inline = [
      "echo '${var.ssh_password}' | sudo -S bash -c \"echo 'bob ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/bob\""
    ]
  }

  # 1. Upload fichiers
  provisioner "file" {
    source      = "files/config-server-medium.sh"
    destination = "/tmp/config.sh"
  }

  provisioner "file" {
    source      = "files/99-static-server-medium.yaml"
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
    inline = [
      "echo '[INFO] Running /tmp/config.sh...'",
      "chmod u+x /tmp/config.sh",
      "/tmp/config.sh"
    ]
  }

  post-processor "shell-local" {
    environment_vars = [
      "PROXMOX_API_TOKEN_ID=${var.proxmox_api_token_id}",
      "PROXMOX_API_TOKEN_SECRET=${var.proxmox_api_token_secret}",
      "PROXMOX_URL=${var.proxmox_url}",
      "PROXMOX_NODE=${var.proxmox_node}",
      "PROXMOX_HOST=${var.proxmox_host}",
      "VM_ID=${var.server_vm_id}"
    ]
    inline = [
      "curl -sk -X PUT -H \"Authorization: PVEAPIToken=$PROXMOX_API_TOKEN_ID=$PROXMOX_API_TOKEN_SECRET\" \"$PROXMOX_URL/nodes/$PROXMOX_NODE/qemu/$VM_ID/config\" -d 'template=0'",
      "ssh -i ${var.proxmox_bastion_key} -o StrictHostKeyChecking=no abdou@${var.proxmox_host} \"sudo chattr -i /var/lib/vz/images/${var.server_vm_id}/base-${var.server_vm_id}-disk-0.qcow2 || true\"",
      "curl -sk -X POST -H \"Authorization: PVEAPIToken=$PROXMOX_API_TOKEN_ID=$PROXMOX_API_TOKEN_SECRET\" \"$PROXMOX_URL/nodes/$PROXMOX_NODE/qemu/$VM_ID/status/start\"",
      "echo '================================================='",
      "echo ' Wazuh Server Medium - Build Complete! (VM 211)'",
      "echo '================================================='"
    ]
  }
}