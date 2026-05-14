/*
* Metasploitable CTF - Variable Declarations
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
  type        = bool
  default     = true
}

# IP du serveur Proxmox — utilisé comme bastion SSH
variable "proxmox_host" {
  type        = string
  description = "IP or hostname of the Proxmox server (used as SSH bastion)"
}

# Clé SSH privée pour se connecter au bastion Proxmox (root)
variable "proxmox_bastion_key" {
  type        = string
  description = "Path to the SSH private key for the Proxmox bastion (root)"
}

//----------------------------------------------------------------------
// VM Configuration Variables
//----------------------------------------------------------------------
variable "clone_vm_id" {
  type        = string
  description = "ID of the source Metasploitable template to clone"
}

variable "vm_id" {
  type        = string
  description = "ID for the new CTF template"
}

variable "vm_name" {
  type        = string
  description = "Name of the new CTF template"
}

//----------------------------------------------------------------------
// SSH Variables
//----------------------------------------------------------------------
variable "ssh_username" {
  type    = string
  default = "msfadmin"
}

variable "ssh_password" {
  type      = string
  sensitive = true
  default   = "msfadmin"
}

//----------------------------------------------------------------------
// CTF Flags
//----------------------------------------------------------------------
variable "flag_ssh"      { type = string }
variable "flag_ftp"      { type = string }
variable "flag_smb"      { type = string }
variable "flag_http"     { type = string }
variable "flag_telnet"   { type = string }
variable "flag_mysql"    { type = string }
variable "flag_postgres" { type = string }

# IP statique configurée dans /etc/network/interfaces du template
variable "ssh_host" {
  type        = string
  description = "IP fixe de la VM Metasploitable sur vmbr1"
}
