/*
 * Wazuh Lab CTF - Variable Declarations
 */

//----------------------------------------------------------------------
// Proxmox Connection
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
  default = false
}

variable "proxmox_host" {
  type        = string
  description = "IP du serveur Proxmox — bastion SSH pour vmbr1"
}

variable "proxmox_bastion_key" {
  type        = string
  description = "Chemin vers la clé SSH privée pour le bastion"
}

//----------------------------------------------------------------------
// Template source (même pour toutes les VMs)
//----------------------------------------------------------------------
variable "clone_vm_id" {
  type        = string
  description = "VMID du template Ubuntu source (avec qemu-guest-agent)"
  default     = "128"
}

//----------------------------------------------------------------------
// SSH
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
// VM IDs et noms
//----------------------------------------------------------------------
variable "wazuh_vm_id" {
  type    = string
  default = "206"
}

variable "agent_vm_id" {
  type    = string
  default = "207"
}

variable "attack_vm_id" {
  type    = string
  default = "208"
}

variable "fauxpositif_vm_id" {
  type    = string
  default = "209"
}

variable "legit_vm_id" {
  type    = string
  default = "210"
}

//----------------------------------------------------------------------
// IPs inter-VMs — passées par deploy-wazuh.sh après récupération DHCP
//----------------------------------------------------------------------
variable "wazuh_ip" {
  type        = string
  description = "IP de la VM Wazuh server — récupérée via API Proxmox après build VM 206"
  default     = ""
}

variable "agent_ip" {
  type        = string
  description = "IP de la VM Agent — récupérée via API Proxmox après build VM 207"
  default     = ""
}

//----------------------------------------------------------------------
// Wazuh config
//----------------------------------------------------------------------
variable "wazuh_agent_name" {
  type    = string
  default = "agent-ubuntu"
}

variable "testuser_password" {
  type      = string
  sensitive = true
  default   = "123456"
}

