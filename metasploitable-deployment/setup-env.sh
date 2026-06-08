#!/usr/bin/env bash
set -e

BASTION_KEY="${BASTION_KEY:-/home/chadha/.ssh/id_ecdsa}"
BASTION_USER="abdou"
BASTION_HOST="138.201.200.168"

echo "[1/2] Adding playsoft-proxmox to /etc/hosts..."
if ! grep -q "playsoft-proxmox" /etc/hosts; then
  echo "$BASTION_HOST  playsoft-proxmox" | sudo tee -a /etc/hosts
  echo "[+] /etc/hosts updated"
else
  echo "[+] Already present in /etc/hosts"
fi

echo "[2/2] Importing Proxmox CA certificate..."
ssh -i "$BASTION_KEY" "$BASTION_USER@$BASTION_HOST" \
  "sudo cat /etc/pve/pve-root-ca.pem" > /tmp/proxmox-ca.crt
sudo cp /tmp/proxmox-ca.crt /usr/local/share/ca-certificates/proxmox-ca.crt
sudo update-ca-certificates --fresh
echo "[+] Proxmox CA imported"

echo "✅ Environment ready for deployment"
