# ================================================================
# main.tf — Wazuh Medium Lab
# Clone les templates Packer et démarre les 3 VMs
#
# VM 211 — Wazuh Server  : VM vide, l'étudiant installe Wazuh
# VM 212 — Wazuh Agent   : VM vide avec port 1514 bloqué (iptables)
# VM 213 — Unified Attack: scripts d'attaque déjà installés
#
# Ordre : Server 211 → Agent 212 → Unified 213
# ================================================================

# ── VM 211 — Wazuh Server Medium ─────────────────────────────
resource "proxmox_virtual_environment_vm" "wazuh_server" {
  node_name = var.proxmox_node
  vm_id     = var.wazuh_server_vmid
  name      = "wazuh-server-medium"

  on_boot = true
  started = true

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
}

# ── VM 212 — Wazuh Agent Medium ──────────────────────────────
resource "proxmox_virtual_environment_vm" "wazuh_agent" {
  node_name = var.proxmox_node
  vm_id     = var.wazuh_agent_vmid
  name      = "wazuh-agent-medium"

  on_boot = true
  started = true

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

  depends_on = [proxmox_virtual_environment_vm.wazuh_server]
}

# ── VM 213 — Unified Attack VM Medium ────────────────────────
resource "proxmox_virtual_environment_vm" "wazuh_unified" {
  node_name = var.proxmox_node
  vm_id     = var.wazuh_unified_vmid
  name      = "wazuh-unified-medium"

  on_boot = true
  started = true

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
