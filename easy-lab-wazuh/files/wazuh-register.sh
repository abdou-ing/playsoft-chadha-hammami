#!/bin/bash
# ================================================================
# wazuh-register.sh — Premier boot uniquement
# S'exécute via wazuh-register.service (systemd one-shot)
# Attend que le Wazuh Manager soit joignable, enregistre l'agent,
# puis démarre wazuh-agent.
# Ce script se trouve dans /usr/local/bin/ sur la VM.
# ================================================================
set -e

LOG="/var/log/wazuh-register.log"
exec >> "$LOG" 2>&1

echo "[$(date)] Démarrage wazuh-register..."

# Les variables WAZUH_IP et AGENT_NAME sont écrites dans
# /etc/wazuh-register.env par Packer (via config-agent.sh)
source /etc/wazuh-register.env

echo "[$(date)] Manager cible : $WAZUH_IP"
echo "[$(date)] Nom agent     : $AGENT_NAME"

# ── Attente que le manager soit joignable ─────────────────────
echo "[$(date)] Attente connectivité Wazuh Manager..."
for i in $(seq 1 60); do
  if nc -z -w3 "$WAZUH_IP" 1515 2>/dev/null; then
    echo "[$(date)] Manager joignable (tentative $i) ✅"
    break
  fi
  echo "[$(date)] Tentative $i/60 — attente 10s..."
  sleep 10
done

# Vérification finale
if ! nc -z -w3 "$WAZUH_IP" 1515 2>/dev/null; then
  echo "[$(date)] ERREUR : Manager inaccessible après 10 min. Abandon."
  exit 1
fi

# ── Enregistrement de l'agent ─────────────────────────────────
echo "[$(date)] Enregistrement de l'agent..."
/var/ossec/bin/agent-auth -m "$WAZUH_IP" -A "$AGENT_NAME"
echo "[$(date)] Enregistrement OK ✅"

# ── Démarrage de l'agent ──────────────────────────────────────
echo "[$(date)] Démarrage wazuh-agent..."
systemctl enable wazuh-agent
systemctl start wazuh-agent
echo "[$(date)] wazuh-agent démarré ✅"

# ── Désactivation du service (ne s'exécute qu'une seule fois) ─
echo "[$(date)] Désactivation wazuh-register.service..."
systemctl disable wazuh-register.service
echo "[$(date)] wazuh-register terminé avec succès ✅"
