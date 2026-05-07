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

  # 1. Upload fichiers
  provisioner "file" {
    source      = "files/config-fauxpositif.sh"   # ou config-legit.sh
    destination = "/tmp/config.sh"
  }

  provisioner "file" {
    source      = "files/99-static-fauxpositif.yaml"  # ou 99-static-legit.yaml
    destination = "/tmp/99-static.yaml"
  }

  provisioner "file" {
    source      = "files/fauxpositif.sh"   # ou legit_ssh.sh
    destination = "/tmp/fauxpositif.sh"    # ou /tmp/legit_ssh.sh
  }

 

  # 3. Run config.sh
  provisioner "shell" {
    environment_vars = [
      "AGENT_IP=${var.agent_ip}",
      "TESTUSER_PASSWORD=${var.testuser_password}"
    ]
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
      "VM_ID=${var.fauxpositif_vm_id}"
    ]
    inline = [
      "curl -sk -X PUT -H \"Authorization: PVEAPIToken=$PROXMOX_API_TOKEN_ID=$PROXMOX_API_TOKEN_SECRET\" \"$PROXMOX_URL/nodes/$PROXMOX_NODE/qemu/$VM_ID/config\" -d 'template=0'",
      "ssh -i ${var.proxmox_bastion_key} -o StrictHostKeyChecking=no abdou@${var.proxmox_host} \"sudo chattr -i /var/lib/vz/images/${var.fauxpositif_vm_id}/base-${var.fauxpositif_vm_id}-disk-0.qcow2 || true\"",
      "curl -sk -X POST -H \"Authorization: PVEAPIToken=$PROXMOX_API_TOKEN_ID=$PROXMOX_API_TOKEN_SECRET\" \"$PROXMOX_URL/nodes/$PROXMOX_NODE/qemu/$VM_ID/status/start\"",
      "echo '================================================='",
      "echo ' Wazuh faux positif - Build Complete! '",
      "echo '================================================='"
    ]
  }
}
