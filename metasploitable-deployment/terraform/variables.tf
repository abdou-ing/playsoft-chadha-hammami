# ================================================================
# variables.tf — Metasploitable CTF Lab
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

# ── Templates ─────────────────────────────────────────────────
# Metasploitable : template créée par Packer (VMID 1301)
variable "meta_template_id" {
  description = "VMID de la template Packer Metasploitable (1301)"
  type        = number
}

# Kali : template existante sur Proxmox (VMID 104)
variable "kali_template_id" {
  description = "VMID de la template Kali existante"
  type        = number
  default     = 104
}

# ── VMIDs des VMs à créer ─────────────────────────────────────
variable "meta_vmid" {
  description = "VMID de la VM Metasploitable à créer"
  type        = number
  default     = 301
}

variable "kali_vmid" {
  description = "VMID de la VM Kali à créer"
  type        = number
  default     = 302
}

# ── IPs ───────────────────────────────────────────────────────
# Metasploitable a une IP statique configurée dans /etc/network/interfaces
variable "meta_ip" {
  description = "IP statique de Metasploitable (configurée dans le template)"
  type        = string
  default     = "10.0.30.99"
}

# ── Stockage ──────────────────────────────────────────────────
variable "storage_pool" {
  type    = string
  default = "local"
}

# ── Bastion ───────────────────────────────────────────────────
variable "bastion_public_ip" {
  type    = string
  default = "188.245.215.21"
}
