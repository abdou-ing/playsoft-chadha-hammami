# ================================================================
# main.tf — DVWA CTF Lab (provider bpg/proxmox)
#
# VM 205 — DVWA    : clonée depuis template Packer (1205)
# VM 220 — Kali    : clonée depuis template existante (104)
#
# IPs dynamiques (DHCP) — récupérées via outputs après démarrage
# ================================================================

# ── VM 205 — DVWA ────────────────────────────────────────────
resource "proxmox_virtual_environment_vm" "dvwa" {
  node_name = var.proxmox_node
  vm_id     = var.dvwa_vmid
  name      = "dvwa-ctf"

  on_boot = true
  started = true

  clone {
    vm_id = var.dvwa_template_id
    full  = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

  # IP DHCP — récupérée via qemu-guest-agent après démarrage
  agent {
    enabled = true
  }
}

# ── VM 220 — Kali ────────────────────────────────────────────
resource "proxmox_virtual_environment_vm" "kali" {
  node_name = var.proxmox_node
  vm_id     = var.kali_vmid
  name      = "kali-ctf"

  on_boot = true
  started = true

  clone {
    vm_id = var.kali_template_id
    full  = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

  agent {
    enabled = true
  }

  depends_on = [proxmox_virtual_environment_vm.dvwa]
}
