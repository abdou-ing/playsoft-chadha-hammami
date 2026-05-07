source "proxmox-clone" "ctfd_haproxy" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  node        = var.proxmox_node
  clone_vm_id = var.clone_vm_id
  vm_id       = var.vm_id
  vm_name     = var.vm_name
  full_clone  = true

  cores  = 1
  memory = 1024

  network_adapters {
    bridge = "vmbr1"
    model  = "virtio"
  }

  qemu_agent = true

  ssh_username                 = var.ssh_username
  ssh_password                 = var.ssh_password
  ssh_timeout                  = "20m"
  communicator                 = "ssh"

  ssh_bastion_host             = var.proxmox_host
  ssh_bastion_username         = "abdou"
  ssh_bastion_private_key_file = var.proxmox_bastion_key
}

build {
  sources = ["source.proxmox-clone.ctfd_haproxy"]

  # 0. NOPASSWD sudo
  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | sudo -S bash -c '{{.Path}}'"
    inline = [
      "echo 'bob ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/bob",
      "sudo chmod 440 /etc/sudoers.d/bob"
    ]
  }

  # 1. Upload config.sh
  provisioner "file" {
    source      = "config.sh"
    destination = "/tmp/config.sh"
  }

  # 2. Run config.sh
  provisioner "shell" {
    environment_vars = [
      "MACHINE1_IP=${var.machine1_ip}",
      "MACHINE2_IP=${var.machine2_ip}"
    ]
    inline = [
      "echo '[INFO] Running /tmp/config.sh...'",
      "chmod u+x /tmp/config.sh",
      "/tmp/config.sh"
    ]
  }

  post-processor "shell-local" {
    inline = [
      <<-EOT
        VMID=${var.vm_id}
        NODE=${var.proxmox_node}
        API_URL="${var.proxmox_url}"
        TOKEN_ID="${var.proxmox_api_token_id}"
        TOKEN_SECRET="${var.proxmox_api_token_secret}"
        BASTION_KEY="${var.proxmox_bastion_key}"

        echo "==> Conversion template → VM $VMID..."
        curl -sk -X PUT \
          -H "Authorization: PVEAPIToken=$TOKEN_ID=$TOKEN_SECRET" \
          "$API_URL/nodes/$NODE/qemu/$VMID/config" \
          -d "template=0"

        echo "==> Correction permissions disque..."
        ssh -i $BASTION_KEY -o StrictHostKeyChecking=no abdou@${var.proxmox_host} \
          "sudo chattr -i /var/lib/vz/images/$VMID/base-$VMID-disk-0.qcow2 && \
           sudo chmod 644 /var/lib/vz/images/$VMID/base-$VMID-disk-0.qcow2"

        echo "==> Démarrage VM $VMID..."
        curl -sk -X POST \
          -H "Authorization: PVEAPIToken=$TOKEN_ID=$TOKEN_SECRET" \
          "$API_URL/nodes/$NODE/qemu/$VMID/status/start"
        echo "==> VM $VMID démarrée ✓"
      EOT
    ]
  }
}