source "proxmox-clone" "ctfd_replica" {
  proxmox_url              = "https://${var.proxmox_host}:8006/api2/json"
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  node        = var.proxmox_node
  clone_vm_id = var.clone_vm_id
  vm_id       = var.vm_id
  vm_name     = var.vm_name
  full_clone  = true

  cores  = 2
  memory = 4096

  network_adapters {
    bridge = "vmbr1"
    model  = "virtio"
  }

  qemu_agent = true

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "20m"

  communicator = "ssh"

  ssh_bastion_host     = "138.201.200.168"
  ssh_bastion_port     = 22
  ssh_bastion_username = "abdou"
  ssh_bastion_private_key_file = "/home/chadha/.ssh/id_ecdsa"
}

build {
  sources = ["source.proxmox-clone.ctfd_replica"]



  provisioner "ansible" {
    playbook_file = "../../ansible/machine2.yml"
    extra_arguments = [
      "--extra-vars", "ansible_ssh_pass=${var.ssh_password} ansible_become_pass=${var.ssh_password} ansible_remote_tmp=/home/bob/.ansible_tmp machine1_ip=${var.machine1_ip} binlog_file=${var.binlog_file} binlog_pos=${var.binlog_pos}",
      "--ssh-extra-args", "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ControlMaster=no",
      "-e", "ansible_scp_if_ssh=False",
      "-e", "ansible_transfer_method=sftp"
    ]
  }
  post-processor "shell-local" {
  inline = [
    <<-EOT
      VMID=${var.vm_id}
      NODE=${var.proxmox_node}
      API_URL="https://${var.proxmox_host}:8006/api2/json"
      TOKEN_ID="${var.proxmox_api_token_id}"
      TOKEN_SECRET="${var.proxmox_api_token_secret}"
      BASTION_KEY="${var.proxmox_bastion_key}"

      echo "==> Conversion template → VM $VMID..."
      curl -sk -X PUT \
        -H "Authorization: PVEAPIToken=$TOKEN_ID=$TOKEN_SECRET" \
        "$API_URL/nodes/$NODE/qemu/$VMID/config" \
        -d "template=0"

      echo "==> Correction permissions disque via Proxmox SSH..."
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