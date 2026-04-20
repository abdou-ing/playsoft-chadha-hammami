# Metasploitable CTF
# ---
# Clones Metasploitable2 template and injects CTF flags.
# The template has a static IP set in /etc/network/interfaces
# so Packer can always reach it via ssh_host.

source "proxmox-clone" "metasploitable-ctf" {

  # Proxmox Connection
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  # VM Settings
  node                 = var.proxmox_node
  vm_id                = var.vm_id
  vm_name              = "${var.vm_name}-{{timestamp}}"
  template_description = "Metasploitable2 CTF - flags injected"

  # Clone source
  clone_vm_id   = var.clone_vm_id
  full_clone    = true
  task_timeout  = "10m"  # timeout pour stop/convert operations

  # Réseau sur vmbr1
  network_adapters {
    model    = "e1000"
    bridge   = "vmbr1"
    firewall = false
  }

  # SSH communicator
  # ssh_host fixe car Metasploitable2 n'a pas de qemu-guest-agent
  # L'IP statique est configurée dans /etc/network/interfaces du template
  communicator = "ssh"
  ssh_host     = var.ssh_host
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "15m"
  ssh_pty      = true

  # Bastion Proxmox pour atteindre le réseau interne vmbr1
  ssh_bastion_host             = var.proxmox_host
  ssh_bastion_port             = 22
  ssh_bastion_username         = "abdou"
  ssh_bastion_private_key_file = var.proxmox_bastion_key

}

build {
  name    = "metasploitable-ctf"
  sources = ["source.proxmox-clone.metasploitable-ctf"]

  provisioner "file" {
    source      = "inject_flags.sh"
    destination = "/tmp/inject_flags.sh"
  }

  provisioner "shell" {
    inline = [
      "chmod +x /tmp/inject_flags.sh",
      # Passe les flags directement en variables inline pour compatibilite Ubuntu 8.04
      # sudo -S lit le mot de passe depuis stdin
      "echo msfadmin | sudo -S env FLAG_SSH='${var.flag_ssh}' FLAG_FTP='${var.flag_ftp}' FLAG_SMB='${var.flag_smb}' FLAG_HTTP='${var.flag_http}' FLAG_TELNET='${var.flag_telnet}' FLAG_MYSQL='${var.flag_mysql}' FLAG_POSTGRES='${var.flag_postgres}' /tmp/inject_flags.sh",
      # Arret propre depuis SSH avant que Proxmox tente ACPI poweroff
      "echo msfadmin | sudo -S shutdown -h now || true"
    ]
  }

  post-processor "shell-local" {
    inline = [
      "echo '================================================='",
      "echo ' Metasploitable CTF - Build Complete!'",
      "echo '================================================='",
    ]
  }
}
