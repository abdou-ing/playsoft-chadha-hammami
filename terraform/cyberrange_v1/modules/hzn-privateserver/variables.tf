variable "hcloud_token" {
  sensitive = true
}
variable "location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "hel1"
}

variable "server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "cx23"
}

variable "image" {
  description = "OS image for the server"
  type        = string
  default     = "ubuntu-24.04"
}

variable "my_name" {
  description = "Custom name suffix for servers"
  type        = string
  default     = "chadha"
}

# variable "existing_network_id" {
#   description = "ID of the existing Hetzner private network"
#   type        = string
#   default     = "11835170"
# }

variable "existing_network_id" {
  description = "ID of the existing Hetzner private network"
  type        = string
  default     = ""  # vide = l'utilisateur doit fournir un ID
}

variable "public_net_ipv4_enabled" {
  description = "Enable IPv4 on public network"
  type        = bool
  default     = true
}

variable "public_net_ipv6_enabled" {
  description = "Enable IPv6 on public network"
  type        = bool
  default     = false
}

variable "private_net_ipv4_enabled" {
  description = "Enable IPv4 on private server public_net"
  type        = bool
  default     = false
}

variable "private_net_ipv6_enabled" {
  description = "Enable IPv6 on private server public_net"
  type        = bool
  default     = false
}

variable "private_key_path" {
  default = "C:/Users/sha33/.ssh/playsoft.pem"
}

