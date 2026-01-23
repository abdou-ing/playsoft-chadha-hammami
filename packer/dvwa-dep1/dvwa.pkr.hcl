source "hcloud" "dvwa" {
  token        = var.hcloud_token
  server_type  = "cx23"
  image        = "ubuntu-24.04"
  location     = "hel1"
  ssh_username = "root"
  ssh_keys     = ["chadha_pubkey"]
}

build {
  sources = ["source.hcloud.dvwa"]
  name    = "dvwa-image-v1"


  # Script externe pour installer Apache, MySQL, PHP et DVWA
  provisioner "shell" {
    script = "scripts/install-dvwa.sh"
  }
  

  # Injecter config.inc.php
  provisioner "file" {
    source      = "files/config.inc.php"
    destination = "/var/www/html/dvwa/config/config.inc.php"
  }

  provisioner "shell" {
    inline = [
      "chown www-data:www-data /var/www/html/dvwa/config/config.inc.php",
      "chmod 644 /var/www/html/dvwa/config/config.inc.php"
    ]
  }
}
