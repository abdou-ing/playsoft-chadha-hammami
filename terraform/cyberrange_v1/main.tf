module "hzn-bastionhost" {
  source                   = "./modules/hzn-bastionhost"
  my_name                  = var.my_name
  image                    = var.image
  location                 = var.location
  server_type              = var.server_type
  existing_network_id      = var.existing_network_id
  public_net_ipv4_enabled  = var.public_net_ipv4_enabled
  public_net_ipv6_enabled  = var.public_net_ipv6_enabled
  private_net_ipv4_enabled = var.private_net_ipv4_enabled
  private_net_ipv6_enabled = var.private_net_ipv6_enabled
  hcloud_token             = var.hcloud_token


}

module "hzn-privateserver" {
  source                   = "./modules/hzn-privateserver"
  my_name                  = var.my_name
  image                    = var.image
  location                 = var.location
  server_type              = var.server_type
  existing_network_id      = var.existing_network_id
  public_net_ipv4_enabled  = var.public_net_ipv4_enabled
  public_net_ipv6_enabled  = var.public_net_ipv6_enabled
  private_net_ipv4_enabled = var.private_net_ipv4_enabled
  private_net_ipv6_enabled = var.private_net_ipv6_enabled
  hcloud_token             = var.hcloud_token
}