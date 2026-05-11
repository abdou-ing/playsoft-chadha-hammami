
#!/usr/bin/env bash
# ============================================================
# deploy-wazuh-medium.sh — Déploiement Wazuh Medium Lab (5 VMs)
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/setup-env.sh"

VAULT_ADDR="https://vault.dev.playsoft.io:8200"
PROXMOX_HOST="138.201.200.168"
NODE="playsoft-proxmox"

# ─── Vault Token ──────────────────────────────────────────
if [ -z "${VAULT_TOKEN:-}" ]; then
  echo "[ERROR] Exporter d'abord: export VAULT_TOKEN='votre_token'"
  exit 1
fi

echo "[*] Récupération des secrets depuis Vault..."

# Proxmox token secret — kv-dev/chadha/proxmox
PROXMOX_SECRET=$(curl -sk \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/kv-dev/data/chadha/proxmox" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['data']['token_secret'])")

# SSH password bob — kv-dev/chadha/vm
SSH_PASS=$(curl -sk \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/kv-dev/data/chadha/vm" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['data']['bob-password'])")

# Testuser password — kv-dev/chadha/passwords
TESTUSER_PASS=$(curl -sk \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/kv-dev/data/chadha/passwords" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['data']['testuser_password'])")

echo "[+] Secrets récupérés depuis Vault ✅"

# ─── Export pour Packer ───────────────────────────────────
export PKR_VAR_proxmox_api_token_secret="$PROXMOX_SECRET"
export PKR_VAR_ssh_password="$SSH_PASS"
export PKR_VAR_testuser_password="$TESTUSER_PASS"

# IPs fixes
WAZUH_IP="10.0.30.42"
AGENT_IP="10.0.30.47"
ATTACK_IP="10.0.30.65"
FAUXPOSITIF_IP="10.0.30.56"
LEGIT_IP="10.0.30.100"

cd "$(dirname "$0")"
packer init .

# ════════════════════════════════════════════════════════════
echo ""
echo "========================================="
echo "  [1/5] Build VM 211 — Wazuh Server Medium"
echo "========================================="
packer build -only="wazuh-server-medium.proxmox-clone.wazuh-server-medium" .
echo "  ✅ Wazuh Server IP : $WAZUH_IP"

# ════════════════════════════════════════════════════════════
echo ""
echo "========================================="
echo "  [2/5] Build VM 212 — Wazuh Agent Medium"
echo "========================================="
packer build -only="wazuh-agent-medium.proxmox-clone.wazuh-agent-medium" .
echo "  ✅ Agent IP : $AGENT_IP (port 1514 bloqué)"

# ════════════════════════════════════════════════════════════
echo ""
echo "========================================="
echo "  [3/5] Build VM 213 — Brute Force"
echo "========================================="
packer build \
  -only="wazuh-attack-medium.proxmox-clone.wazuh-attack-medium" \
  -var "agent_ip=$AGENT_IP" \
  .
echo "  ✅ Brute Force IP : $ATTACK_IP"

echo ""
echo "========================================="
echo "  [4/5] Build VM 214 — Faux Positifs"
echo "========================================="
packer build \
  -only="wazuh-fauxpositif-medium.proxmox-clone.wazuh-fauxpositif-medium" \
  -var "agent_ip=$AGENT_IP" \
  .
echo "  ✅ Faux Positifs IP : $FAUXPOSITIF_IP"

echo ""
echo "========================================="
echo "  [5/5] Build VM 215 — Legit SSH"
echo "========================================="
packer build \
  -only="wazuh-legit-medium.proxmox-clone.wazuh-legit-medium" \
  -var "agent_ip=$AGENT_IP" \
  .
echo "  ✅ Legit SSH IP : $LEGIT_IP"

# ════════════════════════════════════════════════════════════
echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║   Wazuh Medium Lab — Déploiement terminé !     ║"
echo "╠════════════════════════════════════════════════╣"
printf  "║  VM 211  Wazuh Server   %-22s ║\n" "$WAZUH_IP"
printf  "║  VM 212  Agent          %-22s ║\n" "$AGENT_IP"
printf  "║  VM 213  Brute Force    %-22s ║\n" "$ATTACK_IP"
printf  "║  VM 214  Faux Positifs  %-22s ║\n" "$FAUXPOSITIF_IP"
printf  "║  VM 215  Legit SSH      %-22s ║\n" "$LEGIT_IP"
echo "╠════════════════════════════════════════════════╣"
echo "║  ⚠️  Étudiant doit installer Wazuh Manager & Agent ║"
echo "║  ⚠️  Blocage port 1514 sur Agent à diagnostiquer   ║"
echo "╚════════════════════════════════════════════════╝"