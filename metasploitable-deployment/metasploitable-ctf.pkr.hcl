source "proxmox-clone" "metasploitable-ctf" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  node                 = var.proxmox_node
  vm_id                = var.vm_id
  vm_name              = "${var.vm_name}-{{timestamp}}"
  template_description = "Metasploitable2 CTF - flags injected"

  clone_vm_id  = var.clone_vm_id
  full_clone   = true
  task_timeout = "10m"

  network_adapters {
    model    = "e1000"
    bridge   = "vmbr1"
    firewall = false
  }

  communicator = "ssh"
  ssh_host     = var.ssh_host
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "15m"
  ssh_pty      = true

  ssh_bastion_host             = var.proxmox_host
  ssh_bastion_port             = 22
  ssh_bastion_username         = "abdou"
  ssh_bastion_private_key_file = var.proxmox_bastion_key
}

build {
  name    = "metasploitable-ctf"
  sources = ["source.proxmox-clone.metasploitable-ctf"]

  # 1. Upload fichiers
  provisioner "file" {
    source      = "inject_flags.sh"
    destination = "/tmp/inject_flags.sh"
  }

  provisioner "file" {
    source      = "config.sh"
    destination = "/tmp/config.sh"
  }

  # 2. Run config.sh
  provisioner "shell" {
    environment_vars = [
      "FLAG_SSH=${var.flag_ssh}",
      "FLAG_FTP=${var.flag_ftp}",
      "FLAG_SMB=${var.flag_smb}",
      "FLAG_HTTP=${var.flag_http}",
      "FLAG_TELNET=${var.flag_telnet}",
      "FLAG_MYSQL=${var.flag_mysql}",
      "FLAG_POSTGRES=${var.flag_postgres}"
    ]
    inline = [
      "chmod u+x /tmp/config.sh",
      "/tmp/config.sh"
    ]
  }

}