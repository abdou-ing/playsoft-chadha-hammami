# ================================================================
# variables.tf — Wazuh Medium Lab
# ================================================================

variable "proxmox_url" {
  type    = string
  default = "https://playsoft-proxmox:8006/api2/json"
}

variable "proxmox_api_token_id" {
  type      = string
  sensitive = true
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type    = string
  default = "playsoft-proxmox"
}

variable "proxmox_bastion_key" {
  type    = string
  default = "/home/chadha/.ssh/id_ecdsa"
}

# ── VMIDs des templates créées par Packer ─────────────────────
# Packer utilise 1211/1212/1213 pour les templates
# Terraform clone ces templates et crée les VMs 211/212/213
variable "wazuh_server_template_id" {
  description = "VMID de la template Packer wazuh-server-medium (1211)"
  type        = number
}

variable "wazuh_agent_template_id" {
  description = "VMID de la template Packer wazuh-agent-medium (1212)"
  type        = number
}

variable "wazuh_unified_template_id" {
  description = "VMID de la template Packer wazuh-unified-medium (1213)"
  type        = number
}

# ── VMIDs des VMs à créer ─────────────────────────────────────
variable "wazuh_server_vmid" {
  type    = number
  default = 211
}

variable "wazuh_agent_vmid" {
  type    = number
  default = 212
}

variable "wazuh_unified_vmid" {
  type    = number
  default = 213
}

# ── IPs statiques (configurées via netplan dans les templates) ─
variable "wazuh_server_ip" {
  type    = string
  default = "10.0.30.142"
}

variable "wazuh_agent_ip" {
  type    = string
  default = "10.0.30.147"
}

variable "wazuh_unified_ip" {
  type    = string
  default = "10.0.30.165"
}

variable "storage_pool" {
  type    = string
  default = "local"
}

variable "bastion_public_ip" {
  type    = string
  default = "188.245.215.21"
}
