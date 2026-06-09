proxmox_url              = "https://playsoft-proxmox:8006/api2/json"
proxmox_node             = "playsoft-proxmox"
proxmox_api_token_id     = "chadha@pve!packer"
proxmox_api_token_secret = "fb6f11c7-5acd-41d2-8de3-758256f7951e"
proxmox_bastion_key      = "/home/chadha/.ssh/id_ecdsa"

wazuh_server_template_id  = 1211
wazuh_agent_template_id   = 1212
wazuh_unified_template_id = 1213

wazuh_server_vmid  = 206
wazuh_agent_vmid   = 207
wazuh_unified_vmid = 208

wazuh_server_ip  = "10.0.30.42"
wazuh_agent_ip   = "10.0.30.47"
wazuh_unified_ip = "10.0.30.65"

storage_pool      = "local"
bastion_public_ip = "188.245.215.21"
