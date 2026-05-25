#!/bin/bash
set -e

echo "[INFO] Arrêt unattended-upgrades..."
sudo systemctl stop unattended-upgrades || true
sudo systemctl disable unattended-upgrades || true
sudo systemctl stop apt-daily.timer apt-daily-upgrade.timer || true
sudo systemctl disable apt-daily.timer apt-daily-upgrade.timer || true
sudo systemctl kill --kill-who=all apt-daily.service apt-daily-upgrade.service || true
sudo kill -9 $(pgrep unattended-upgr) 2>/dev/null || true
sudo kill -9 $(pgrep apt) 2>/dev/null || true

echo "[INFO] Attente libération lock APT..."
for i in $(seq 1 30); do
  sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || break
  echo "Lock APT occupé ($i/30)..."
  sleep 5
done

sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock || true
sudo dpkg --configure -a || true

echo "[INFO] Installation des paquets..."
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget netcat-openbsd

echo "[INFO] Création testuser..."
sudo useradd -m -s /bin/bash testuser || true
echo "testuser:$TESTUSER_PASSWORD" | sudo chpasswd

echo "[INFO] Activation PasswordAuthentication SSH..."
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# ── Installation wazuh-agent (sans connexion au manager) ──────────────
# Le manager n'est pas accessible ici (template éteinte pendant le build Packer)
# L'enregistrement se fera au premier boot via wazuh-register.service
echo "[INFO] Installation wazuh-agent (sans démarrage)..."
curl -sO https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.14.3-1_amd64.deb
sudo WAZUH_MANAGER="$WAZUH_IP" WAZUH_AGENT_NAME="$AGENT_NAME" dpkg -i wazuh-agent_4.14.3-1_amd64.deb

# Désactiver l'agent — il sera démarré par wazuh-register.service après enregistrement
sudo systemctl daemon-reload
sudo systemctl disable wazuh-agent || true
sudo systemctl stop wazuh-agent || true

# ── Configuration IP statique ──────────────────────────────────────────
echo "[INFO] Configuration IP statique..."
sudo rm -f /etc/netplan/01-network-manager-all.yaml
sudo cp /tmp/99-static.yaml /etc/netplan/99-static.yaml
sudo chmod 600 /etc/netplan/99-static.yaml
nohup sudo bash -c 'sleep 5 && netplan apply' > /tmp/netplan.log 2>&1 &

echo "[+] config-agent.sh terminé"
