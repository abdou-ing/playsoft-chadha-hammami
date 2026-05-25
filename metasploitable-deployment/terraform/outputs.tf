# ================================================================
# outputs.tf — Metasploitable CTF Lab
#
# Metasploitable : IP statique depuis variable (pas de guest agent)
# Kali           : IP dynamique via qemu-guest-agent
# ================================================================

output "meta_ip" {
  description = "IP statique de Metasploitable"
  value       = var.meta_ip
}

output "kali_ip" {
  description = "IP dynamique de Kali (DHCP via qemu-guest-agent)"
  value       = proxmox_virtual_environment_vm.kali.ipv4_addresses[1][0]
}

output "meta_vmid" {
  value = proxmox_virtual_environment_vm.metasploitable.vm_id
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
      proxmox_virtual_environment_vm.metasploitable.vm_id,
      proxmox_virtual_environment_vm.kali.vm_id,
    ]
    vnc_vm_ips = [
      var.meta_ip,
      proxmox_virtual_environment_vm.kali.ipv4_addresses[1][0],
    ]
    windows_vm_ids = []
    windows_vm_ips = []
  }
}
