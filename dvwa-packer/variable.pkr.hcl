/*
 * DVWA CTF - Variable Declarations
 */

//----------------------------------------------------------------------
// Proxmox Connection Variables
//----------------------------------------------------------------------
variable "proxmox_url" {
  type        = string
  description = "Full Proxmox API URL"
}

variable "proxmox_api_token_id" {
  type        = string
  description = "Token ID (e.g. chadha@pve!packer)"
}

variable "proxmox_api_token_secret" {
  type        = string
  sensitive   = true
  description = "Token secret"
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name"
}

variable "proxmox_skip_tls_verify" {
  type    = bool
  default = true
}

variable "proxmox_host" {
  type        = string
  description = "IP du serveur Proxmox — utilisé comme bastion SSH pour vmbr1"
}

variable "proxmox_bastion_key" {
  type        = string
  description = "Chemin vers la clé SSH privée pour le bastion Proxmox"
}

//----------------------------------------------------------------------
// VM Configuration Variables
//----------------------------------------------------------------------
variable "clone_vm_id" {
  type        = string
  description = "VMID du template Ubuntu source (avec qemu-guest-agent)"
}

variable "vm_id" {
  type        = string
  description = "VMID de la VM DVWA CTF à créer"
}

variable "vm_name" {
  type        = string
  description = "Nom de la VM DVWA CTF"
}

//----------------------------------------------------------------------
// SSH Variables
// Pas de ssh_host fixe : Packer récupère l'IP via qemu-guest-agent (DHCP)
//----------------------------------------------------------------------
variable "ssh_username" {
  type    = string
  default = "bob"
}

variable "ssh_password" {
  type      = string
  sensitive = true
}

//----------------------------------------------------------------------
// CTF Flags
//----------------------------------------------------------------------
variable "flag_sqli"          { type = string }
variable "flag_cmd_injection" { type = string }
variable "flag_file_upload"   { type = string }
variable "flag_xss_reflected" { type = string }
variable "flag_xss_stored"    { type = string }
variable "flag_xss_dom"       { type = string }
