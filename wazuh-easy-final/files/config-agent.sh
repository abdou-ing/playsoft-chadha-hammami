#!/bin/bash
set -e

echo "[INFO] Arrêt unattended-upgrades..."
sudo systemctl stop unattended-upgrades || true
sudo systemctl disable unattended-upgrades || true
sudo systemctl kill --kill-who=all apt-daily.service apt-daily-upgrade.service || true
for i in $(seq 1 30); do
  sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || break
  echo "Lock APT occupé ($i/30)..."
  sleep 5
done
sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock || true
sudo dpkg --configure -a || true

echo "[INFO] Installation des paquets..."
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget

echo "[INFO] Création testuser..."
sudo useradd -m -s /bin/bash testuser || true
echo "testuser:$TESTUSER_PASSWORD" | sudo chpasswd

echo "[INFO] Activation PasswordAuthentication SSH..."
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart sshd

echo "[INFO] Attente connectivité Wazuh Server ($WAZUH_IP)..."
for i in $(seq 1 30); do
  if curl -sk --max-time 5 https://$WAZUH_IP:55000 > /dev/null 2>&1 || ping -c1 -W2 $WAZUH_IP > /dev/null 2>&1; then
    echo "[+] Wazuh Server joignable !"
    break
  fi
  echo "Tentative $i/30 — attente 10s..."
  sleep 10
done

echo "[INFO] Installation wazuh-agent..."
curl -sO https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.14.3-1_amd64.deb
sudo WAZUH_MANAGER=$WAZUH_IP WAZUH_AGENT_NAME=$AGENT_NAME dpkg -i wazuh-agent_4.14.3-1_amd64.deb

echo "[INFO] Démarrage wazuh-agent..."
sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent

echo "[+] config-agent.sh terminé"