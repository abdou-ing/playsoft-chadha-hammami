# VM 208 — Unified Attack VM (Brute Force + Faux Positifs + Legit SSH)
source "proxmox-clone" "wazuh-unified-medium" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  node                 = var.proxmox_node
  vm_id                = var.attack_vm_id
  vm_name              = "wazuh-unified-medium{{timestamp}}"
  template_description = "Wazuh Lab — Unified Attack VM (Brute Force + Faux Positifs + Legit SSH)"

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
  name    = "wazuh-unified-medium"
  sources = ["source.proxmox-clone.wazuh-unified-medium"]

  # 0. NOPASSWD sudo
  provisioner "shell" {
    inline = [
      "echo '${var.ssh_password}' | sudo -S bash -c \"echo 'bob ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/bob\""
    ]
  }

  # 1. Upload config script
  provisioner "file" {
    source      = "files/config-unified.sh"
    destination = "/tmp/config.sh"
  }

  # 2. Upload netplan
  provisioner "file" {
    source      = "files/99-static-unified.yaml"
    destination = "/tmp/99-static.yaml"
  }

  # 3. Upload attack scripts
  provisioner "file" {
    source      = "files/autoattack2.sh"
    destination = "/tmp/autoattack2.sh"
  }

  provisioner "file" {
    source      = "files/fauxpositif.sh"
    destination = "/tmp/fauxpositif.sh"
  }

  provisioner "file" {
    source      = "files/legit_ssh.sh"
    destination = "/tmp/legit_ssh.sh"
  }

  # 4. Run config.sh
  provisioner "shell" {
    environment_vars = [
      "AGENT_IP=${var.agent_ip}",
      "TESTUSER_PASSWORD=${var.testuser_password}"
    ]
    inline = [
      "chmod u+x /tmp/config.sh",
      "/tmp/config.sh"
    ]
  }

  
  
}
