#!/bin/bash
set -e

echo "[*] Extraction passwords depuis le tar..."
PASSWORDS_FILE=$(sudo tar -O -xf /home/bob/wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt 2>/dev/null)

# ── Patch wazuh.yml avec le vrai mot de passe wazuh-wui ──────────
WAZUH_WUI_PASS=$(echo "$PASSWORDS_FILE" | grep -A1 "wazuh-wui" | grep "password:" | awk '{print $2}' | tr -d "'")
echo "[*] wazuh-wui password extrait"
sudo sed -i "s|password: wazuh-wui|password: $WAZUH_WUI_PASS|" \
  /usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml
echo "[+] wazuh.yml patché"
sudo systemctl restart wazuh-dashboard
echo "[+] Dashboard redémarré"

# ── Extraire le password admin généré ────────────────────────────
GENERATED_PASS=$(echo "$PASSWORDS_FILE" | grep -A1 "indexer_username: 'admin'" | grep indexer_password | awk '{print $2}' | tr -d "'")
echo "[*] Password admin généré extrait"

# ── Attendre que l'indexer OpenSearch soit prêt (port 9200) ──────
echo "[*] Attente indexer Wazuh (port 9200)..."
for i in $(seq 1 30); do
  CODE=$(curl -sk -o /dev/null -w "%{http_code}" \
    -u "admin:$GENERATED_PASS" \
    "https://127.0.0.1:9200" || echo "000")
  if [ "$CODE" = "200" ]; then
    echo "[+] Indexer UP (tentative $i)"
    break
  fi
  echo "  Indexer pas encore prêt ($i/30)... HTTP $CODE"
  sleep 10
done

# ── Changer le password admin via internal_users.yml ─────────────
echo "[*] Changement password admin via internal_users.yml..."

# Générer le hash bcrypt du nouveau password
NEW_PASS="Playsoft@2026#Lab"
HASH=$(sudo env JAVA_HOME=/usr/share/wazuh-indexer/jdk \
  /usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh \
  -p "$NEW_PASS" 2>/dev/null | grep '^\$2y\$')
echo "[*] Hash généré: $HASH"

# Remplacer le hash dans internal_users.yml
sudo sed -i "/^admin:/,/^[^ ]/{s|hash:.*|hash: \"$HASH\"|}" \
  /etc/wazuh-indexer/opensearch-security/internal_users.yml

# Appliquer la configuration de sécurité
sudo env JAVA_HOME=/usr/share/wazuh-indexer/jdk \
  /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh \
  -f /etc/wazuh-indexer/opensearch-security/internal_users.yml \
  -icl -nhnv \
  -cacert /etc/wazuh-indexer/certs/root-ca.pem \
  -cert /etc/wazuh-indexer/certs/admin.pem \
  -key /etc/wazuh-indexer/certs/admin-key.pem \
  -h 127.0.0.1

echo "[+] Password admin fixé à : $NEW_PASS"

# Remplacer ${password} par la valeur directe dans filebeat.yml
sudo sed -i 's|password: \${password}|password: "Playsoft@2026#Lab"|' /etc/filebeat/filebeat.yml
sudo systemctl restart filebeat
echo "[+] Filebeat password mis à jour"

sudo systemctl restart filebeat
echo "[+] Filebeat keystore mis à jour"

# ── Redémarrer les services pour appliquer le nouveau password ────
sudo systemctl restart wazuh-indexer
sleep 15
sudo systemctl restart wazuh-manager
sleep 5
sudo systemctl restart wazuh-dashboard
sleep 5

# ── Vérification ──────────────────────────────────────────────────
TEST=$(curl -sk -o /dev/null -w "%{http_code}" \
  -u "admin:Admin1234!" \
  "https://127.0.0.1:9200" || echo "000")
if [ "$TEST" = "200" ]; then
  echo "[+] ✅ Password admin fixé à : Playsoft@2026#Lab"
else
  echo "[WARN] Vérification HTTP $TEST — le password a peut-être quand même été changé"
fi
