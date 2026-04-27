source "proxmox-clone" "ctfd_haproxy" {
  proxmox_url              = "https://${var.proxmox_host}:8006/api2/json"
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  node        = var.proxmox_node
  clone_vm_id = var.clone_vm_id
  vm_id       = var.vm_id
  vm_name     = var.vm_name
  full_clone  = true

  cores  = 1
  memory = 1024

  network_adapters {
    bridge = "vmbr1"
    model  = "virtio"
  }

  qemu_agent = true

  ssh_username                 = var.ssh_username
  ssh_password                 = var.ssh_password
  ssh_timeout                  = "20m"
  communicator                 = "ssh"

  ssh_bastion_host             = var.proxmox_host
  ssh_bastion_username         = "abdou"
  ssh_bastion_private_key_file = var.proxmox_bastion_key
}

build {
  sources = ["source.proxmox-clone.ctfd_haproxy"]

  # Configurer sudo sans mot de passe
  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | sudo -S bash -c '{{.Path}}'"
    inline = [
      "echo 'bob ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/bob",
      "sudo chmod 440 /etc/sudoers.d/bob"
    ]
  }

  # Installer HAProxy
  provisioner "shell" {
    inline = [
      "sudo apt update -y",
      "sudo apt install -y haproxy",
      "sudo systemctl enable haproxy"
    ]
  }

  # Générer et déployer la config HAProxy
  provisioner "shell" {
    environment_vars = [
      "MACHINE1_IP=${var.machine1_ip}",
      "MACHINE2_IP=${var.machine2_ip}"
    ]
    inline = [
      <<-EOT
        sudo tee /etc/haproxy/haproxy.cfg > /dev/null <<EOF
global
    log /dev/log local0
    log /dev/log local1 notice
    maxconn 4096
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    option  dontlognull
    retries 3
    timeout connect 5s
    timeout client  30s
    timeout server  30s

# --- Frontend for CTFd Web App ---
frontend ctfd_frontend
    bind *:80
    mode http
    default_backend ctfd_backend

backend ctfd_backend
    mode http
    balance roundrobin
    option httpchk GET /
    server ctfd1 $MACHINE1_IP:8000 check
    server ctfd2 $MACHINE2_IP:8001 check

# --- Frontend for MariaDB ---
frontend mariadb_frontend
    bind *:3306
    mode tcp
    default_backend mariadb_backend

backend mariadb_backend
    mode tcp
    balance roundrobin
    option mysql-check user haproxy
    server db1 $MACHINE1_IP:3307 check
    server db2 $MACHINE2_IP:3308 check backup
EOF
        sudo systemctl restart haproxy
        sudo systemctl status haproxy --no-pager
        echo "==> HAProxy configuré ✓"
      EOT
    ]
  }

  post-processor "shell-local" {
    inline = [
      <<-EOT
        VMID=${var.vm_id}
        NODE=${var.proxmox_node}
        API_URL="https://${var.proxmox_host}:8006/api2/json"
        TOKEN_ID="${var.proxmox_api_token_id}"
        TOKEN_SECRET="${var.proxmox_api_token_secret}"
        BASTION_KEY="${var.proxmox_bastion_key}"

        echo "==> Conversion template → VM $VMID..."
        curl -sk -X PUT \
          -H "Authorization: PVEAPIToken=$TOKEN_ID=$TOKEN_SECRET" \
          "$API_URL/nodes/$NODE/qemu/$VMID/config" \
          -d "template=0"

        echo "==> Correction permissions disque..."
        ssh -i $BASTION_KEY -o StrictHostKeyChecking=no abdou@${var.proxmox_host} \
          "sudo chattr -i /var/lib/vz/images/$VMID/base-$VMID-disk-0.qcow2 && \
           sudo chmod 644 /var/lib/vz/images/$VMID/base-$VMID-disk-0.qcow2"

        echo "==> Démarrage VM $VMID..."
        curl -sk -X POST \
          -H "Authorization: PVEAPIToken=$TOKEN_ID=$TOKEN_SECRET" \
          "$API_URL/nodes/$NODE/qemu/$VMID/status/start"
        echo "==> VM $VMID démarrée ✓"
      EOT
    ]
  }
}