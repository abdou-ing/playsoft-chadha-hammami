# ================================================================
# variables.tf — Wazuh Easy Lab (provider bpg/proxmox)
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

# ── Templates créées par Packer ───────────────────────────────
variable "wazuh_server_template_id" {
  description = "VMID de la template Packer wazuh-server (ex: 1206)"
  type        = number
}

variable "wazuh_agent_template_id" {
  description = "VMID de la template Packer wazuh-agent (ex: 1207)"
  type        = number
}

variable "wazuh_unified_template_id" {
  description = "VMID de la template Packer wazuh-unified (ex: 1208)"
  type        = number
}

# ── VMIDs des VMs à créer ─────────────────────────────────────
variable "wazuh_server_vmid" {
  type    = number
  default = 206
}

variable "wazuh_agent_vmid" {
  type    = number
  default = 207
}

variable "wazuh_unified_vmid" {
  type    = number
  default = 208
}

# ── IPs (pour les outputs) ────────────────────────────────────
variable "wazuh_server_ip" {
  type    = string
  default = "10.0.30.142"
}

variable "wazuh_agent_ip" {
  type    = string
  default = "10.0.30.47"
}

variable "wazuh_unified_ip" {
  type    = string
  default = "10.0.30.65"
}

variable "storage_pool" {
  type    = string
  default = "local"
}

variable "bastion_public_ip" {
  type    = string
  default = "188.245.215.21"
}
