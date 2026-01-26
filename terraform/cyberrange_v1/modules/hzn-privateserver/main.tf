

resource "hcloud_server" "private" {
  name        = "hzn-private-${var.my_name}"
  image       = "351927162"
  server_type = var.server_type
  location    = var.location

  public_net {
    ipv4_enabled = var.private_net_ipv4_enabled
    ipv6_enabled = var.private_net_ipv6_enabled
  }

  network {
    network_id = var.existing_network_id
  }

  ssh_keys = ["chadha_pubkey"]

  user_data = templatefile("${path.module}/cloud-init.yml", {
    gateway_ip = var.gateway_ip
  })

  # depends_on = [hcloud_server.jump]
}
