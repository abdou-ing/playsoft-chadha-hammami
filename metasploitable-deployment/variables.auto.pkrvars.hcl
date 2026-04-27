/*
* Metasploitable CTF - Non-sensitive Values
*/

//----------------------------------------------------------------------
// Proxmox Connection
//----------------------------------------------------------------------
proxmox_url             = "https://proxmox.playsoft.io:8006/api2/json"
proxmox_api_token_id    = "chadha@pve!packer"
proxmox_node            = "playsoft-proxmox"
proxmox_skip_tls_verify = true

proxmox_host            = "138.201.200.168"
proxmox_bastion_key     = "/home/chadha/.ssh/id_ecdsa"  // nom exact de la clé

//----------------------------------------------------------------------
// VM Configuration
//----------------------------------------------------------------------
clone_vm_id = "125"
vm_id       = "301"
vm_name     = "TPL-Metasploitable-CTF"

//----------------------------------------------------------------------
// CTF Flags
//----------------------------------------------------------------------
flag_ssh      = "FLAG{SSH_FLAG}"
flag_ftp      = "FLAG{FTP_FLAG_DONE}"
flag_smb      = "FLAG{SMB_FLAG_IS_HERE}"
flag_http     = "FLAG{HTTP_FLAG80}"
flag_telnet   = "FLAG{telnet_flag_23}"
flag_mysql    = "FLAG{MYSQL_FLAG_MYSQL}"
flag_postgres = "FLAG{POSTGRES_FLAG_DONE}"

# IP statique — doit correspondre à ce qui est dans /etc/network/interfaces du template
ssh_host = "10.0.30.99"
