# ================================================================
# variables.tf — DVWA CTF Lab
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
# DVWA : template créée par Packer (VMID 1205)
variable "dvwa_template_id" {
  description = "VMID de la template Packer DVWA (1205)"
  type        = number
}

# Kali : template existante sur Proxmox (VMID 104) — pas buildée par Packer
variable "kali_template_id" {
  description = "VMID de la template Kali existante"
  type        = number
  default     = 104
}

# ── VMIDs des VMs à créer ─────────────────────────────────────
variable "dvwa_vmid" {
  description = "VMID de la VM DVWA à créer"
  type        = number
  default     = 205
}

variable "kali_vmid" {
  description = "VMID de la VM Kali à créer"
  type        = number
  default     = 220   # VMID libre — à ajuster selon ton Proxmox
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
