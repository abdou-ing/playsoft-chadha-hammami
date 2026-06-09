# ================================================================
# main.tf — Wazuh Easy Lab (provider bpg/proxmox)
# Ressource : proxmox_virtual_environment_vm
# Clone les templates Packer et démarre les VMs
# Ordre : Server 206 → Agent 207 → Unified 208
# ================================================================

# ── VM 206 — Wazuh Server ────────────────────────────────────
resource "proxmox_virtual_environment_vm" "wazuh_server" {
  node_name = var.proxmox_node
  vm_id     = var.wazuh_server_vmid
  name      = "wazuh-server"

  on_boot  = true
  started  = true

  clone {
    vm_id = var.wazuh_server_template_id
    full  = true
  }

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 8192
  }

  # Pas de cloud-init — IP déjà configurée via netplan dans la template
  # Le provider bpg hérite les disques et réseau du clone automatiquement
}

# ── VM 207 — Wazuh Agent ─────────────────────────────────────
resource "proxmox_virtual_environment_vm" "wazuh_agent" {
  node_name = var.proxmox_node
  vm_id     = var.wazuh_agent_vmid
  name      = "wazuh-agent"

  on_boot  = true
  started  = true

  clone {
    vm_id = var.wazuh_agent_template_id
    full  = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

  # Agent démarre après le server (wazuh-register.service attend le manager)
  depends_on = [proxmox_virtual_environment_vm.wazuh_server]
}

# ── VM 208 — Unified Attack VM ───────────────────────────────
resource "proxmox_virtual_environment_vm" "wazuh_unified" {
  node_name = var.proxmox_node
  vm_id     = var.wazuh_unified_vmid
  name      = "wazuh-unified"

  on_boot  = true
  started  = true

  clone {
    vm_id = var.wazuh_unified_template_id
    full  = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

  depends_on = [proxmox_virtual_environment_vm.wazuh_agent]
}
