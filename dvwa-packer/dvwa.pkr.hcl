source "proxmox-clone" "dvwa-ctf" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  node                 = var.proxmox_node
  vm_id                = var.vm_id
  vm_name              = "${var.vm_name}-{{timestamp}}"
  template_description = "DVWA CTF - Apache + MySQL + PHP, flags injectés"
  cores                = 2
  memory               = 2048

  clone_vm_id  = var.clone_vm_id
  full_clone   = true
  task_timeout = "10m"

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
  name    = "dvwa-ctf"
  sources = ["source.proxmox-clone.dvwa-ctf"]

  # 0. NOPASSWD sudo
  provisioner "shell" {
    inline = [
      "echo '${var.ssh_password}' | sudo -S bash -c \"echo 'bob ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/bob\""
    ]
  }

  # 1. Upload config.sh
  provisioner "file" {
    source      = "config.sh"
    destination = "/tmp/config.sh"
  }

  # 2. Run config.sh
  provisioner "shell" {
    inline = [
      "echo '[INFO] Running /tmp/config.sh...'",
      "chmod u+x /tmp/config.sh",
      "/tmp/config.sh"
    ]
  }

  # 3. Upload inject_flags.sh
  provisioner "file" {
    source      = "inject_flags.sh"
    destination = "/tmp/inject_flags.sh"
  }
  # 4. Run inject_flags.sh
  provisioner "shell" {
    environment_vars = [
      "FLAG_SQLI=${var.flag_sqli}",
      "FLAG_CMD_INJECTION=${var.flag_cmd_injection}",
      "FLAG_FILE_UPLOAD=${var.flag_file_upload}",
      "FLAG_XSS_REFLECTED=${var.flag_xss_reflected}",
      "FLAG_XSS_STORED=${var.flag_xss_stored}",
      "FLAG_XSS_DOM=${var.flag_xss_dom}"
    ]
    inline = [
      "echo '[INFO] Running /tmp/inject_flags.sh...'",
      "chmod u+x /tmp/inject_flags.sh",
      "sudo -E /tmp/inject_flags.sh"
    ]
  }
   
}