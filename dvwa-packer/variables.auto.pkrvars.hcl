/*
 * DVWA CTF - Non-sensitive Values
 */

//----------------------------------------------------------------------
// Proxmox Connection
//----------------------------------------------------------------------
proxmox_url             = "https://playsoft-proxmox:8006/api2/json"
proxmox_api_token_id    = "chadha@pve!packer"
proxmox_node            = "playsoft-proxmox"
proxmox_skip_tls_verify = false 
proxmox_host            = "138.201.200.168"
proxmox_bastion_key     = "/home/chadha/.ssh/id_ecdsa"

//----------------------------------------------------------------------
// VM Configuration
// clone_vm_id : template Ubuntu avec qemu-guest-agent installé
// L'IP est obtenue automatiquement par Packer via qemu-guest-agent (DHCP)
//----------------------------------------------------------------------
clone_vm_id = "128"
vm_id       = "205"
vm_name     = "DVWA-CTF"

//----------------------------------------------------------------------
// SSH
//----------------------------------------------------------------------
ssh_username = "bob"

//----------------------------------------------------------------------
// CTF Flags
//----------------------------------------------------------------------
flag_sqli          = "FLAG{SQLi_success}"
flag_cmd_injection = "FLAG{CommandInjection_success!}"
flag_file_upload   = "flag{you_got_it}"
flag_xss_reflected = "FLAG{XSS_reflected_success}"
flag_xss_stored    = "FLAG{XSS_stored_success}"
flag_xss_dom       = "FLAG{XSS_DOM_success}"
