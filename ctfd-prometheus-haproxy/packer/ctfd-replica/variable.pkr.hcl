/*
* CTFd Replica — Variable Declarations
*/

variable "proxmox_url" {
  type    = string
  default = "https://proxmox.playsoft.io:8006/api2/json"
}

variable "proxmox_api_token_id" {
  type    = string
  default = "chadha@pve!packer"
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type    = string
  default = "playsoft-proxmox"
}

variable "proxmox_skip_tls_verify" {
  type    = bool
  default = true
}

variable "proxmox_host" {
  type    = string
  default = "138.201.200.168"
}

variable "proxmox_bastion_key" {
  type    = string
  default = "/home/chadha/.ssh/id_ecdsa"
}

variable "clone_vm_id" {
  type    = string
  default = "128"
}

variable "vm_id" {
  type    = string
  default = "202"
}

variable "vm_name" {
  type    = string
  default = "CTFd-Replica"
}

variable "ssh_username" {
  type    = string
  default = "bob"
}

variable "ssh_password" {
  type      = string
  sensitive = true
  default   = "123456"
}

# IP de Machine 1 — passée par deploy.sh après le build Machine 1
variable "machine1_ip" {
  type        = string
  description = "IP DHCP de Machine 1 récupérée après son build"
}

# Binlog — passés par deploy.sh après lecture de binlog_info.json
variable "binlog_file" {
  type        = string
  description = "Binlog file de Machine 1"
}

variable "binlog_pos" {
  type        = string
  description = "Binlog position de Machine 1"
}
