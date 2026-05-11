/*
 * Wazuh Lab CTF - Non-sensitive Values
 */

//----------------------------------------------------------------------
// Proxmox Connection
//----------------------------------------------------------------------
proxmox_url             = "https://proxmox.playsoft.io:8006/api2/json"
proxmox_api_token_id    = "chadha@pve!packer"
proxmox_node            = "playsoft-proxmox"
proxmox_skip_tls_verify = true
proxmox_host            = "138.201.200.168"
proxmox_bastion_key     = "/home/chadha/.ssh/id_ecdsa"

//----------------------------------------------------------------------
// Template source
//----------------------------------------------------------------------
clone_vm_id = "128"

//----------------------------------------------------------------------
// SSH
//----------------------------------------------------------------------
ssh_username = "bob"

//----------------------------------------------------------------------
// VM IDs
//----------------------------------------------------------------------
wazuh_vm_id       = "206"
agent_vm_id       = "207"
attack_vm_id      = "208"
fauxpositif_vm_id = "209"
legit_vm_id       = "210"

//----------------------------------------------------------------------
// Wazuh config
//----------------------------------------------------------------------
wazuh_agent_name  = "agent-ubuntu"

# wazuh_ip et agent_ip sont injectés dynamiquement par deploy-wazuh.sh
# Ne pas les définir ici — passés via -var au moment du build
