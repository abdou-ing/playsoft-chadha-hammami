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

  # 0. NOPASSWD sudo — exception nécessaire avant tout upload
  provisioner "shell" {
    inline = [
      "echo '${var.ssh_password}' | sudo -S bash -c \"echo 'bob ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/bob\""
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
      "echo ' Wazuh Server - Build Complete! (VM 206)'"
    ]
  }
}