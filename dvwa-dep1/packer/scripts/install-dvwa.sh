#!/bin/bash
set -e

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y apache2 mysql-server php php-mysqli git curl

# Installer DVWA
git clone https://github.com/digininja/DVWA.git /var/www/html/dvwa || true
chown -R www-data:www-data /var/www/html/dvwa
chmod -R 755 /var/www/html/dvwa

# Configurer MySQL
mysql -e "CREATE DATABASE IF NOT EXISTS dvwa;"
mysql -e "CREATE USER IF NOT EXISTS 'dvwa'@'localhost' IDENTIFIED BY 'dvwa';"
mysql -e "GRANT ALL PRIVILEGES ON dvwa.* TO 'dvwa'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Activer services
systemctl enable apache2
systemctl restart apache2
systemctl enable mysql
systemctl restart mysql
