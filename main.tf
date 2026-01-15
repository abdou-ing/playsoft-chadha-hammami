resource "hcloud_server" "jump_server_new" {
  name        = "hzn-jump-${var.my_name}-new"
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

  ssh_keys = ["chadha_pubkey"]

  user_data = <<-EOF
    #cloud-config
    write_files:
      - path: /etc/networkd-dispatcher/routable.d/10-eth0-post-up
        content: |
          #!/bin/bash
          echo 1 > /proc/sys/net/ipv4/ip_forward
          iptables -t nat -A POSTROUTING -s '10.50.0.0/24' -o eth0 -j MASQUERADE
        permissions: '0755'
    runcmd:
      - apt-get update
      - apt-get install -y iptables-persistent
      - reboot
  EOF
}


resource "hcloud_server" "private_server_new" {
  name        = "hzn-private-${var.my_name}-new"
  image       = var.image
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

  user_data = <<-EOF
    #cloud-config
    write_files:
      - path: /etc/systemd/network/10-enp7s0.network
        content: |
          # Custom network configuration added by cloud-init
          [Match]
          Name=enp7s0

          [Network]
          DHCP=yes
          Gateway=10.50.0.1
        append: true

      - path: /etc/systemd/resolved.conf
        content: |
          [Resolve]
          DNS=185.12.64.2 185.12.64.1
          FallbackDNS=8.8.8.8
        append: true

    runcmd:
      - apt remove -y hc-utils
      - reboot
  EOF
}

