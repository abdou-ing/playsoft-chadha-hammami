# ================================================================
# main.tf — Metasploitable CTF Lab (provider bpg/proxmox)
#
# VM 301 — Metasploitable : clonée depuis template Packer (1301)
#                           IP statique 10.0.30.99
#                           PAS de qemu-guest-agent (VM trop ancienne)
#                           agent { enabled = false } pour éviter
#                           l'attente infinie du provider
# VM 302 — Kali           : clonée depuis template existante (104)
#                           IP DHCP via qemu-guest-agent
# ================================================================

# ── VM 301 — Metasploitable ───────────────────────────────────
resource "proxmox_virtual_environment_vm" "metasploitable" {
  node_name     = var.proxmox_node
  vm_id         = var.meta_vmid
  name          = "metasploitable-ctf"

  on_boot       = true
  started       = true
  timeout_clone = 300

  clone {
    vm_id = var.meta_template_id
    full  = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

  # CRUCIAL : sans ce bloc, le provider attend indéfiniment
  # une réponse du QEMU agent même si aucun bloc agent n'est déclaré.
  # enabled = false coupe cette attente dès le démarrage de la VM.
  agent {
    enabled = false
    trim    = false
    type    = "virtio"
  }
}

# ── VM 302 — Kali ────────────────────────────────────────────
resource "proxmox_virtual_environment_vm" "kali" {
  node_name     = var.proxmox_node
  vm_id         = var.kali_vmid
  name          = "kali-ctf"

  on_boot       = true
  started       = true
  timeout_clone = 300

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
    timeout = "5m"
  }

  depends_on = [proxmox_virtual_environment_vm.metasploitable]
}
