
#!/bin/bash
set -e

echo "[INFO] Arrêt unattended-upgrades..."
sudo systemctl stop unattended-upgrades || true
sudo systemctl disable unattended-upgrades || true
sudo systemctl stop apt-daily.timer apt-daily-upgrade.timer || true
sudo systemctl disable apt-daily.timer apt-daily-upgrade.timer || true
sudo systemctl kill --kill-who=all apt-daily.service apt-daily-upgrade.service || true
sudo kill -9 $(pgrep unattended-upgr) 2>/dev/null || true
for i in $(seq 1 30); do
  sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || break
  echo "Lock APT occupé ($i/30)..."
  sleep 5
done
sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock || true
sudo dpkg --configure -a || true

echo "[INFO] Installation des paquets..."
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget iptables-persistent

echo "[INFO] Création testuser..."
sudo useradd -m -s /bin/bash testuser || true
echo "testuser:$TESTUSER_PASSWORD" | sudo chpasswd

echo "[INFO] Activation PasswordAuthentication SSH..."
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart sshd

echo "[INFO] Blocage port 1514 — challenge étudiant..."
sudo iptables -A OUTPUT -p tcp --dport 1514 -j DROP
sudo iptables -A OUTPUT -p udp --dport 1514 -j DROP
sudo mkdir -p /etc/iptables
sudo sh -c 'iptables-save > /etc/iptables/rules.v4'
sudo systemctl enable netfilter-persistent || true
sudo netfilter-persistent save || true

echo "[+] config-agent-medium.sh terminé"