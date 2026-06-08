# ================================================================
# outputs.tf — DVWA CTF Lab
# IPs récupérées dynamiquement via qemu-guest-agent
# ================================================================

output "dvwa_ip" {
  description = "IP de la VM DVWA (DHCP via qemu-guest-agent)"
  value       = proxmox_virtual_environment_vm.dvwa.ipv4_addresses[1][0]
}

output "kali_ip" {
  description = "IP de la VM Kali (DHCP via qemu-guest-agent)"
  value       = proxmox_virtual_environment_vm.kali.ipv4_addresses[1][0]
}

output "dvwa_vmid" {
  value = proxmox_virtual_environment_vm.dvwa.vm_id
}

output "kali_vmid" {
  value = proxmox_virtual_environment_vm.kali.vm_id
}

# ── Format Guacamole / Ansible ────────────────────────────────
output "guacamole" {
  description = "Données pour Ansible Guacamole — remplace tf_output.json"
  value = {
    bastion_public_ip = var.bastion_public_ip
    vnc_vm_ids = [
      proxmox_virtual_environment_vm.dvwa.vm_id,
      proxmox_virtual_environment_vm.kali.vm_id,
    ]
    vnc_vm_ips = [
      proxmox_virtual_environment_vm.dvwa.ipv4_addresses[1][0],
      proxmox_virtual_environment_vm.kali.ipv4_addresses[1][0],
    ]
    windows_vm_ids = []
    windows_vm_ips = []
  }
}
