#!/usr/bin/env bash
# ============================================================
# deploy-wazuh.sh — Déploiement Wazuh Easy Lab (5 VMs) via Packer
# ============================================================
set -euo pipefail

# ─── Setup environnement (TLS + /etc/hosts) ───────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/setup-env.sh"

# ─── Vault ────────────────────────────────────────────────
VAULT_ADDR="https://vault.dev.playsoft.io:8200"

if [ -z "${VAULT_TOKEN:-}" ]; then
  echo "[ERROR] Exporter d'abord: export VAULT_TOKEN='votre_token'"
  exit 1
fi

echo "[*] Récupération des secrets depuis Vault..."

PROXMOX_SECRET=$(curl -sk \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/kv-dev/data/chadha/proxmox" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['data']['token_secret'])")

SSH_PASS=$(curl -sk \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/kv-dev/data/chadha/vm" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['data']['bob-password'])")

TESTUSER_PASS=$(curl -sk \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/kv-dev/data/chadha/passwords" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['data']['testuser_password'])")

echo "[+] Secrets récupérés depuis Vault ✅"

# ─── Export pour Packer ───────────────────────────────────
export PKR_VAR_proxmox_api_token_secret="$PROXMOX_SECRET"
export PKR_VAR_ssh_password="$SSH_PASS"
export PKR_VAR_testuser_password="$TESTUSER_PASS"

# ─── IPs statiques ────────────────────────────────────────
WAZUH_PASS="Playsoft@2026#Lab"
WAZUH_IP="10.0.30.42"
AGENT_IP="10.0.30.47"
ATTACK_IP="10.0.30.65"
FAUXPOSITIF_IP="10.0.30.56"
LEGIT_IP="10.0.30.100"

OUTPUT_FILE="$HOME/playsoft-jilani-gharbi/playsoft-infra/packer/tf_output.json"

cd "$(dirname "$0")"
packer init .

# ════════════════════════════════════════════════════════════
echo ""
echo "========================================="
echo "  [1/5] Build VM 206 — Wazuh Server"
echo "========================================="
packer build -only="wazuh-server.proxmox-clone.wazuh-server" .
echo "  ✅ Wazuh Server IP : $WAZUH_IP"
echo "  ✅ Wazuh admin password : $WAZUH_PASS"

# ════════════════════════════════════════════════════════════
echo ""
echo "========================================="
echo "  [2/5] Build VM 207 — Wazuh Agent"
echo "  wazuh_ip = $WAZUH_IP"
echo "========================================="
packer build \
  -only="wazuh-agent.proxmox-clone.wazuh-agent" \
  -var "wazuh_ip=$WAZUH_IP" \
  .
echo "  ✅ Agent IP : $AGENT_IP"

# ════════════════════════════════════════════════════════════
echo ""
echo "========================================="
echo "  [3/5] Build VM 208 — Brute Force"
echo "  agent_ip = $AGENT_IP"
echo "========================================="
packer build \
  -only="wazuh-attack.proxmox-clone.wazuh-attack" \
  -var "agent_ip=$AGENT_IP" \
  .

echo ""
echo "========================================="
echo "  [4/5] Build VM 209 — Faux Positifs"
echo "  agent_ip = $AGENT_IP"
echo "========================================="
packer build \
  -only="wazuh-fauxpositif.proxmox-clone.wazuh-fauxpositif" \
  -var "agent_ip=$AGENT_IP" \
  .

echo ""
echo "========================================="
echo "  [5/5] Build VM 210 — Legit SSH"
echo "  agent_ip = $AGENT_IP"
echo "========================================="
packer build \
  -only="wazuh-legit.proxmox-clone.wazuh-legit" \
  -var "agent_ip=$AGENT_IP" \
  .

# ─── Générer tf_output.json ───────────────────────────────
echo ""
echo "Génération de $OUTPUT_FILE..."
mkdir -p "$(dirname "$OUTPUT_FILE")"

python3 -c "
import json
data = {
  'bastion_public_ip': {'sensitive': False, 'type': 'string', 'value': '188.245.215.21'},
  'k8s_master_private_ip': {'sensitive': False, 'type': 'string', 'value': '10.20.0.10'},
  'k8s_worker_private_ips': {'sensitive': False, 'type': ['tuple', ['string']], 'value': []},
  'vnc_vm_ids': {
    'sensitive': False,
    'type': ['tuple', ['number']],
    'value': [206, 207, 208, 209, 210]
  },
  'vnc_vm_ips': {
    'sensitive': False,
    'type': ['tuple', ['string']],
    'value': ['$WAZUH_IP', '$AGENT_IP', '$ATTACK_IP', '$FAUXPOSITIF_IP', '$LEGIT_IP']
  },
  'windows_vm_ids': {'sensitive': False, 'type': ['tuple', []], 'value': []},
  'windows_vm_ips': {'sensitive': False, 'type': ['tuple', []], 'value': []}
}
print(json.dumps(data, indent=2))
" > "$OUTPUT_FILE"

# ════════════════════════════════════════════════════════════
echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║   Wazuh Easy Lab — Déploiement terminé !       ║"
echo "╠════════════════════════════════════════════════╣"
printf  "║  VM 206  Wazuh Server   https://%-15s ║\n" "$WAZUH_IP"
printf  "║  VM 207  Agent          %-22s ║\n" "$AGENT_IP"
printf  "║  VM 208  Brute Force    %-22s ║\n" "$ATTACK_IP"
printf  "║  VM 209  Faux Positifs  %-22s ║\n" "$FAUXPOSITIF_IP"
printf  "║  VM 210  Legit SSH      %-22s ║\n" "$LEGIT_IP"
echo "╠════════════════════════════════════════════════╣"
printf  "║  Login Wazuh: admin / %-25s ║\n" "$WAZUH_PASS"
echo "╠════════════════════════════════════════════════╣"
echo "║  tf_output.json généré                         ║"
echo "╚════════════════════════════════════════════════╝"