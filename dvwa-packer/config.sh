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

echo "[INFO] Installation des dépendances..."
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  apache2 mysql-server php php-mysqli php-gd php-xml php-curl git curl

echo "[INFO] Clonage DVWA..."
sudo git clone https://github.com/digininja/DVWA.git /var/www/html/dvwa
sudo chown -R www-data:www-data /var/www/html/dvwa
sudo chmod -R 755 /var/www/html/dvwa

echo "[INFO] Configuration MySQL..."
sudo mysql -e "CREATE DATABASE IF NOT EXISTS dvwa;"
sudo mysql -e "CREATE USER IF NOT EXISTS 'dvwa'@'localhost' IDENTIFIED BY 'dvwa';"
sudo mysql -e "GRANT ALL PRIVILEGES ON dvwa.* TO 'dvwa'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo "[INFO] Configuration config.inc.php..."
sudo cp /var/www/html/dvwa/config/config.inc.php.dist /var/www/html/dvwa/config/config.inc.php
sudo bash -c "cat > /var/www/html/dvwa/config/config.inc.php << 'EOF'
<?php
\$DBMS = 'MySQL';
\$_DVWA = array();
\$_DVWA['db_server']              = '127.0.0.1';
\$_DVWA['db_database']            = 'dvwa';
\$_DVWA['db_user']                = 'dvwa';
\$_DVWA['db_password']            = 'dvwa';
\$_DVWA['db_port']                = '3306';
\$_DVWA['recaptcha_public_key']   = '';
\$_DVWA['recaptcha_private_key']  = '';
\$_DVWA['default_security_level'] = 'low';
\$_DVWA['default_locale']         = 'en';
\$_DVWA['disable_authentication'] = false;
define('MYSQL', 'mysql');
define('SQLITE', 'sqlite');
\$_DVWA['SQLI_DB'] = MYSQL;
?>
EOF"
sudo chown www-data:www-data /var/www/html/dvwa/config/config.inc.php

echo "[INFO] Limitation du menu DVWA..."
sudo sed -i "/\$menuBlocks\[ 'vulnerabilities' \]\[\].*'id' => 'brute'/s/^/\/\//" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php
sudo sed -i "/\$menuBlocks\[ 'vulnerabilities' \]\[\].*'id' => 'csrf'/s/^/\/\//" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php
sudo sed -i "/\$menuBlocks\[ 'vulnerabilities' \]\[\].*'id' => 'fi'/s/^/\/\//" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php
sudo sed -i "/\$menuBlocks\[ 'vulnerabilities' \]\[\].*'id' => 'captcha'/s/^/\/\//" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php
sudo sed -i "/\$menuBlocks\[ 'vulnerabilities' \]\[\].*'id' => 'sqli_blind'/s/^/\/\//" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php
sudo sed -i "/\$menuBlocks\[ 'vulnerabilities' \]\[\].*'id' => 'weak_id'/s/^/\/\//" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php
sudo sed -i "/\$menuBlocks\[ 'vulnerabilities' \]\[\].*'id' => 'csp'/s/^/\/\//" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php
sudo sed -i "/\$menuBlocks\[ 'vulnerabilities' \]\[\].*'id' => 'javascript'/s/^/\/\//" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php
sudo sed -i "/\$menuBlocks\[ 'vulnerabilities' \]\[\].*'id' => 'authbypass'/s/^/\/\//" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php
sudo sed -i "/\$menuBlocks\[ 'vulnerabilities' \]\[\].*'id' => 'open_redirect'/s/^/\/\//" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php
sudo sed -i "/\$menuBlocks\[ 'vulnerabilities' \]\[\].*'id' => 'cryptography'/s/^/\/\//" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php
sudo sed -i "/\$menuBlocks\[ 'vulnerabilities' \]\[\].*'id' => 'encryption'/s/^/\/\//" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php
sudo sed -i "/\$menuBlocks\[ 'vulnerabilities' \]\[\].*'id' => 'api'/s/^/\/\//" /var/www/html/dvwa/dvwa/includes/dvwaPage.inc.php
echo "[+] Menu DVWA limité aux modules CTF actifs"

echo "[INFO] Finalisation Apache..."
sudo a2enmod rewrite
sudo systemctl restart apache2
sudo systemctl enable apache2
sudo systemctl enable mysql

echo "[+] config.sh terminé avec succès"