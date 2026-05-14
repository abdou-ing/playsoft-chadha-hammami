# ─── Proxmox connection ───────────────────────────────────────────────────────
variable "proxmox_url" {
  type    = string
  default = "https://playsoft-proxmox:8006/api2/json"
}

variable "proxmox_api_token_id" {
  type    = string
  default = "chadha@pve!packer"
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "proxmox_skip_tls_verify" {
  type    = bool
  default = false
}

variable "proxmox_node" {
  type    = string
  default = "playsoft-proxmox"
}

variable "proxmox_host" {
  type    = string
  default = "138.201.200.168"
}

variable "proxmox_bastion_key" {
  type    = string
  default = "/home/chadha/.ssh/id_ecdsa"
}

# ─── Template source ───────────────────────────────────────────────────────────
variable "clone_vm_id" {
  type    = number
  default = 128
}

# ─── SSH credentials ──────────────────────────────────────────────────────────
variable "ssh_username" {
  type    = string
  default = "bob"
}

variable "ssh_password" {
  type      = string
  sensitive = true
}

variable "testuser_password" {
  type      = string
  sensitive = true
}

# ─── VM IDs ───────────────────────────────────────────────────────────────────
variable "server_vm_id" {
  type    = number
  default = 211
}

variable "agent_vm_id" {
  type    = number
  default = 212
}

variable "attack_vm_id" {
  type    = number
  default = 213
}

variable "fauxpositif_vm_id" {
  type    = number
  default = 214
}

variable "legit_vm_id" {
  type    = number
  default = 215
}

# ─── Wazuh config ─────────────────────────────────────────────────────────────
variable "wazuh_ip" {
  type    = string
  default = "10.0.30.142"
}

variable "wazuh_agent_name" {
  type    = string
  default = "agent-medium"
}

variable "agent_ip" {
  type    = string
  default = "10.0.30.147"
}
