terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_url
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = false   # CA importé par setup-env.sh

  ssh {
    agent       = false
    username    = "abdou"
    private_key = file(var.proxmox_bastion_key)
  }
}
