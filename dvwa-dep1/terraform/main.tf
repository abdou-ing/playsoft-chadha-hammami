resource "hcloud_server" "jump" {
  name        = "hzn-jump-${var.my_name}"
  image       = var.image
  server_type = var.server_type
  location    = var.location

  public_net {
    ipv4_enabled = var.public_net_ipv4_enabled   
    ipv6_enabled = var.public_net_ipv6_enabled
  }

  network {
    network_id = var.existing_network_id
  }

  ssh_keys  = ["chadha_pubkey"]
  # Cloud-init pour configurer NAT, proxy DVWA et Fail2ban
  user_data = file("user_data/jump-server.yaml")

  # Provisioner pour installer les paquets après le boot
  provisioner "remote-exec" { 
    inline = [ 
      "sleep 60", # attendre que le système soit stable 
      "apt-get update", 
      "DEBIAN_FRONTEND=noninteractive apt-get install -y nginx ufw fail2ban", 
      "systemctl enable nginx", 
      "systemctl restart nginx", 
      "systemctl enable fail2ban", 
      "systemctl restart fail2ban" 
    ]
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("${path.module}/keys/playsoft.pem")
      host        = self.ipv4_address   # IP publique du jump
    }
  }

}

resource "hcloud_server" "private" {
  name        = "hzn-private-${var.my_name}"
  image       = "351621800"   
  server_type = var.server_type
  location    = var.location

  public_net {
    ipv4_enabled = var.private_net_ipv4_enabled
    ipv6_enabled = var.private_net_ipv6_enabled
  }

  network {
    network_id = var.existing_network_id
  }

  ssh_keys  = ["chadha_pubkey"]

  user_data = file("user_data/private-server.sh")

  depends_on = [hcloud_server.jump]
}
