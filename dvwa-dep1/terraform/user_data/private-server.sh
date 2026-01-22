#cloud-config
write_files:
  - path: /etc/systemd/network/10-enp7s0.network
    content: |
      [Match]
      Name=enp7s0

      [Network]
      DHCP=yes
      Gateway=10.50.0.1
  - path: /etc/systemd/resolved.conf
    content: |
      [Resolve]
      DNS=185.12.64.2 185.12.64.1
      FallbackDNS=8.8.8.8

runcmd:
  - systemctl restart systemd-networkd || true
  - systemctl restart systemd-resolved || true
  - apt remove -y hc-utils || true
