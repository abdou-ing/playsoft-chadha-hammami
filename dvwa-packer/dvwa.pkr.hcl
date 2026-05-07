# DVWA CTF
# ---
# Clone le template Ubuntu (VMID 128, qemu-guest-agent installé).
# Packer récupère l'IP automatiquement via qemu-guest-agent — pas d'IP fixe.
# Installe DVWA (Apache + MySQL + PHP) et injecte les flags CTF.

source "proxmox-clone" "dvwa-ctf" {
  # Proxmox Connection
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  # VM Settings
  node                 = var.proxmox_node
  vm_id                = var.vm_id
  vm_name              = "${var.vm_name}-{{timestamp}}"
  template_description = "DVWA CTF - Apache + MySQL + PHP, flags injectés"
  cores  = 2
  memory = 2048

  # Clone source (template Ubuntu avec qemu-guest-agent)
  clone_vm_id  = var.clone_vm_id
  full_clone   = true
  task_timeout = "10m"

  # Réseau sur vmbr1 — IP obtenue en DHCP, récupérée via qemu-guest-agent
  network_adapters {
    model    = "e1000"
    bridge   = "vmbr1"
    firewall = false
  }

  # SSH communicator
  # Pas de ssh_host fixe — Packer interroge qemu-guest-agent pour l'IP DHCP
  communicator           = "ssh"
  ssh_username           = var.ssh_username
  ssh_password           = var.ssh_password
  ssh_timeout            = "20m"
  ssh_pty                = true
  ssh_handshake_attempts = 20

  # Bastion Proxmox pour atteindre le réseau interne vmbr1
  ssh_bastion_host             = var.proxmox_host
  ssh_bastion_port             = 22
  ssh_bastion_username         = "abdou"
  ssh_bastion_private_key_file = var.proxmox_bastion_key
}

build {
  name    = "dvwa-ctf"
  sources = ["source.proxmox-clone.dvwa-ctf"]

  # -------------------------------------------------------------------------
  # 0. NOPASSWD sudo pour bob
  # -------------------------------------------------------------------------
  provisioner "shell" {
    inline = [
      "echo '${var.ssh_password}' | sudo -S bash -c \"echo 'bob ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/bob\""
    ]
  }

  # -------------------------------------------------------------------------
  # 1. Installation des dépendances
  # -------------------------------------------------------------------------
  provisioner "shell" {
    inline = [
      "sudo systemctl stop unattended-upgrades || true",
      "sudo apt-get update -y",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y apache2 mysql-server php php-mysqli php-gd php-xml php-curl git curl"
    ]
  }

  # -------------------------------------------------------------------------
  # 2. Clonage DVWA
  # -------------------------------------------------------------------------
  provisioner "shell" {
    inline = [
      "sudo git clone https://github.com/digininja/DVWA.git /var/www/html/dvwa",
      "sudo chown -R www-data:www-data /var/www/html/dvwa",
      "sudo chmod -R 755 /var/www/html/dvwa"
    ]
  }

  # -------------------------------------------------------------------------
  # 3. Base de données MySQL
  # -------------------------------------------------------------------------
  provisioner "shell" {
    inline = [
      "sudo mysql -e \"CREATE DATABASE IF NOT EXISTS dvwa;\"",
      "sudo mysql -e \"CREATE USER IF NOT EXISTS 'dvwa'@'localhost' IDENTIFIED BY 'dvwa';\"",
      "sudo mysql -e \"GRANT ALL PRIVILEGES ON dvwa.* TO 'dvwa'@'localhost';\"",
      "sudo mysql -e \"FLUSH PRIVILEGES;\""
    ]
  }

  # -------------------------------------------------------------------------
  # 4. Configuration config.inc.php
  # -------------------------------------------------------------------------
  provisioner "shell" {
    inline = [
      "sudo cp /var/www/html/dvwa/config/config.inc.php.dist /var/www/html/dvwa/config/config.inc.php",
      <<-SHELL
sudo bash -c "cat > /var/www/html/dvwa/config/config.inc.php << 'EOF'
<?php
\$DBMS = 'MySQL';
\$_DVWA = array();
\$_DVWA['db_server']              = '127.0.0.1';
\$_DVWA['db_database']            = 'dvwa';
\$_DVWA['db_user']                = 'dvwa';
\$_DVWA['db_password']            = 'dvwa';
\$_DVWA['db_port']                = '3306';
\$_DVWA['recaptcha_public_key']   = '';
\$_DVWA['recaptcha_private_key']  = '';
\$_DVWA['default_security_level'] = 'low';
\$_DVWA['default_locale']         = 'en';
\$_DVWA['disable_authentication'] = false;
define('MYSQL', 'mysql');
define('SQLITE', 'sqlite');
\$_DVWA['SQLI_DB'] = MYSQL;
?>
EOF"
      SHELL
      ,
      "sudo chown www-data:www-data /var/www/html/dvwa/config/config.inc.php"
    ]
  }

  # -------------------------------------------------------------------------
  # 5. Limitation du menu DVWA (désactiver les modules hors scope CTF)
  # Utilise sed pour commenter les lignes des modules à désactiver.
  # Plus fiable que Python pour ce pattern dans un heredoc Packer.
  # Modules conservés : exec, upload, sqli, xss_d, xss_r, xss_s
  # -------------------------------------------------------------------------
  provisioner "shell" {
    inline = [
      "sudo sed -i \"/\\$menuBlocks\\[ 'vulnerabilities' \\]\\[\\].*'id' => 'brute'/s/^/\\/\\//\" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php",
      "sudo sed -i \"/\\$menuBlocks\\[ 'vulnerabilities' \\]\\[\\].*'id' => 'csrf'/s/^/\\/\\//\" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php",
      "sudo sed -i \"/\\$menuBlocks\\[ 'vulnerabilities' \\]\\[\\].*'id' => 'fi'/s/^/\\/\\//\" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php",
      "sudo sed -i \"/\\$menuBlocks\\[ 'vulnerabilities' \\]\\[\\].*'id' => 'captcha'/s/^/\\/\\//\" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php",
      "sudo sed -i \"/\\$menuBlocks\\[ 'vulnerabilities' \\]\\[\\].*'id' => 'sqli_blind'/s/^/\\/\\//\" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php",
      "sudo sed -i \"/\\$menuBlocks\\[ 'vulnerabilities' \\]\\[\\].*'id' => 'weak_id'/s/^/\\/\\//\" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php",
      "sudo sed -i \"/\\$menuBlocks\\[ 'vulnerabilities' \\]\\[\\].*'id' => 'csp'/s/^/\\/\\//\" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php",
      "sudo sed -i \"/\\$menuBlocks\\[ 'vulnerabilities' \\]\\[\\].*'id' => 'javascript'/s/^/\\/\\//\" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php",
      "sudo sed -i \"/\\$menuBlocks\\[ 'vulnerabilities' \\]\\[\\].*'id' => 'authbypass'/s/^/\\/\\//\" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php",
      "sudo sed -i \"/\\$menuBlocks\\[ 'vulnerabilities' \\]\\[\\].*'id' => 'open_redirect'/s/^/\\/\\//\" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php",
      "sudo sed -i \"/\\$menuBlocks\\[ 'vulnerabilities' \\]\\[\\].*'id' => 'cryptography'/s/^/\\/\\//\" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php",
      "sudo sed -i \"/\\$menuBlocks\\[ 'vulnerabilities' \\]\\[\\].*'id' => 'encryption'/s/^/\\/\\//\" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php",
      "sudo sed -i \"/\\$menuBlocks\\[ 'vulnerabilities' \\]\\[\\].*'id' => 'api'/s/^/\\/\\//\" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php",
      "echo '[+] Menu DVWA limité aux modules CTF actifs'"
    ]
  }

  # -------------------------------------------------------------------------
  # 6. Injection des flags CTF
  # inject_flags.sh : crée les tables, injecte les flags, patche les low.php
  # -------------------------------------------------------------------------
  provisioner "file" {
    source      = "inject_flags.sh"
    destination = "/tmp/inject_flags.sh"
  }

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
      "chmod +x /tmp/inject_flags.sh",
      "sudo -E /tmp/inject_flags.sh"
    ]
  }

  # -------------------------------------------------------------------------
  # 7. Finalisation Apache
  # -------------------------------------------------------------------------
  provisioner "shell" {
    inline = [
      "sudo a2enmod rewrite",
      "sudo systemctl restart apache2",
      "sudo systemctl enable apache2",
      "sudo systemctl enable mysql"
    ]
  }

  # -------------------------------------------------------------------------
  # Post-processor : fix disque immuable + démarrage VM
  # -------------------------------------------------------------------------
  post-processor "shell-local" {
    environment_vars = [
      "PROXMOX_API_TOKEN_ID=${var.proxmox_api_token_id}",
      "PROXMOX_API_TOKEN_SECRET=${var.proxmox_api_token_secret}",
      "PROXMOX_URL=${var.proxmox_url}",
      "PROXMOX_NODE=${var.proxmox_node}",
      "PROXMOX_HOST=${var.proxmox_host}",
      "VM_ID=${var.vm_id}"
    ]
    inline = [
      "curl -sk -X PUT -H \"Authorization: PVEAPIToken=$PROXMOX_API_TOKEN_ID=$PROXMOX_API_TOKEN_SECRET\" \"$PROXMOX_URL/nodes/$PROXMOX_NODE/qemu/$VM_ID/config\" -d 'template=0'",
      "ssh -i ${var.proxmox_bastion_key} -o StrictHostKeyChecking=no abdou@${var.proxmox_host} \"sudo chattr -i /var/lib/vz/images/${var.vm_id}/base-${var.vm_id}-disk-0.qcow2 || true\"",
      "curl -sk -X POST -H \"Authorization: PVEAPIToken=$PROXMOX_API_TOKEN_ID=$PROXMOX_API_TOKEN_SECRET\" \"$PROXMOX_URL/nodes/$PROXMOX_NODE/qemu/$VM_ID/status/start\"",
      "echo '================================================='",
      "echo ' DVWA CTF - Build Complete!'",
      "echo ' URL : http://<IP_DVWA>/dvwa  (voir Proxmox pour l IP)'",
      "echo ' Login : admin / password'",
      "echo ' ⚠  Aller sur /dvwa/setup.php → Create / Reset Database'",
      "echo '================================================='"
    ]
  }
}
