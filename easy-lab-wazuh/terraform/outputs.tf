# ================================================================
# outputs.tf — Wazuh Easy Lab (provider bpg/proxmox)
# ================================================================

output "wazuh_server_ip" {
  value = var.wazuh_server_ip
}

output "wazuh_agent_ip" {
  value = var.wazuh_agent_ip
}

output "wazuh_unified_ip" {
  value = var.wazuh_unified_ip
}

output "wazuh_dashboard_url" {
  value = "https://${var.wazuh_server_ip}"
}

output "guacamole" {
  description = "Données pour Ansible Guacamole — remplace tf_output.json"
  value = {
    bastion_public_ip = var.bastion_public_ip
    vnc_vm_ids = [
      proxmox_virtual_environment_vm.wazuh_server.vm_id,
      proxmox_virtual_environment_vm.wazuh_agent.vm_id,
      proxmox_virtual_environment_vm.wazuh_unified.vm_id,
    ]
    vnc_vm_ips = [
      var.wazuh_server_ip,
      var.wazuh_agent_ip,
      var.wazuh_unified_ip,
    ]
    windows_vm_ids = []
    windows_vm_ips = []
  }
}
