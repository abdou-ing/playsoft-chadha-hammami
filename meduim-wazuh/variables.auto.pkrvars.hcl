proxmox_url             = "https://playsoft-proxmox:8006/api2/json"
proxmox_api_token_id    = "chadha@pve!packer"
proxmox_skip_tls_verify = false
proxmox_node            = "playsoft-proxmox"
proxmox_host            = "138.201.200.168"
proxmox_bastion_key     = "/home/chadha/.ssh/id_ecdsa"

clone_vm_id  = 128
ssh_username = "bob"

server_vm_id      = 211
agent_vm_id       = 212
attack_vm_id      = 213
fauxpositif_vm_id = 214
legit_vm_id       = 215

wazuh_ip         = "10.0.30.142"
wazuh_agent_name = "agent-medium"
agent_ip         = "10.0.30.147"
