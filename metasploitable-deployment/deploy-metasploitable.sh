#!/usr/bin/env bash
# ============================================================
# deploy-metasploitable.sh — Déploiement Metasploitable CTF
# ============================================================
set -euo pipefail

# ─── Setup environnement (TLS + /etc/hosts) ───────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/setup-env.sh"

# ─── Vérification secret Proxmox ──────────────────────────
if [ -z "${PKR_VAR_proxmox_api_token_secret:-}" ]; then
  echo "[ERROR] Exporter d'abord: export PKR_VAR_proxmox_api_token_secret='votre_secret'"
  exit 1
fi

# ─── Lire les variables depuis le fichier HCL ─────────────
VARS_FILE="$SCRIPT_DIR/variables.auto.pkrvars.hcl"

get_var() {
  grep "^$1" "$VARS_FILE" | sed 's/.*= *"\(.*\)"/\1/'
}

PROXMOX_HOST="playsoft-proxmox"
PROXMOX_NODE=$(get_var "proxmox_node")
PROXMOX_TOKEN_ID=$(get_var "proxmox_api_token_id")
PROXMOX_TOKEN_SECRET="${PKR_VAR_proxmox_api_token_secret}"
PROXMOX_BASTION_KEY=$(get_var "proxmox_bastion_key")
META_VM_ID=$(get_var "vm_id")
META_IP=$(get_var "ssh_host")
KALI_TEMPLATE_ID="104"
OUTPUT_FILE="$HOME/playsoft-jilani-gharbi/playsoft-infra/packer/tf_output.json"

auth_header='Authorization: PVEAPIToken='"$PROXMOX_TOKEN_ID"'='"$PROXMOX_TOKEN_SECRET"

cd "$(dirname "$0")"
packer init .

# ─── 1. Build Metasploitable via Packer ───────────────────
echo ""
echo "========================================="
echo "  [1/4] Build VM $META_VM_ID — Metasploitable CTF"
echo "========================================="
packer build .
echo "✅ Metasploitable buildé"

# ─── 2. Cloner Kali depuis template 104 ───────────────────
echo ""
echo "[2/4] Clonage de Kali depuis template $KALI_TEMPLATE_ID..."

KALI_VM_ID=$(curl -s \
  -H "$auth_header" \
  "https://$PROXMOX_HOST:8006/api2/json/cluster/nextid" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data'])")

echo "  Kali VM ID généré: $KALI_VM_ID"

curl -s -X POST \
  -H "$auth_header" \
  -H "Content-Type: application/json" \
  "https://$PROXMOX_HOST:8006/api2/json/nodes/$PROXMOX_NODE/qemu/$KALI_TEMPLATE_ID/clone" \
  -d "{\"newid\": $KALI_VM_ID, \"name\": \"kali-ctf\", \"full\": 1, \"target\": \"$PROXMOX_NODE\"}"

echo "  Attente fin du clonage..."
sleep 30

curl -s -X POST \
  -H "$auth_header" \
  "https://$PROXMOX_HOST:8006/api2/json/nodes/$PROXMOX_NODE/qemu/$KALI_VM_ID/status/start"

echo "  ✅ Kali démarrée"

# ─── 3. Récupérer IP Kali ─────────────────────────────────
echo ""
echo "[3/4] Récupération IP Kali (VM $KALI_VM_ID)..."
KALI_IP=""
ATTEMPTS=0
while [ -z "$KALI_IP" ] && [ $ATTEMPTS -lt 24 ]; do
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 10
  KALI_IP=$(curl -s \
    -H "$auth_header" \
    "https://$PROXMOX_HOST:8006/api2/json/nodes/$PROXMOX_NODE/qemu/$KALI_VM_ID/agent/network-get-interfaces" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin).get('data', {})
for iface in data.get('result', []):
    if iface.get('name') not in ('lo',):
        for addr in iface.get('ip-addresses', []):
            if addr.get('ip-address-type') == 'ipv4' and not addr.get('ip-address', '').startswith('127.'):
                print(addr.get('ip-address'))
                sys.exit()
" 2>/dev/null || true)
  echo "  Tentative $ATTEMPTS/24 — Kali IP: ${KALI_IP:-en attente...}"
done

if [ -z "$KALI_IP" ]; then
  echo "❌ Impossible de récupérer l'IP de Kali"
  exit 1
fi
echo "✅ Kali IP: $KALI_IP"

# ─── 4. Générer tf_output.json ────────────────────────────
echo ""
echo "[4/4] Génération de $OUTPUT_FILE..."
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
    'value': [$META_VM_ID, $KALI_VM_ID]
  },
  'vnc_vm_ips': {
    'sensitive': False,
    'type': ['tuple', ['string']],
    'value': ['$META_IP', '$KALI_IP']
  },
  'windows_vm_ids': {'sensitive': False, 'type': ['tuple', []], 'value': []},
  'windows_vm_ips': {'sensitive': False, 'type': ['tuple', []], 'value': []}
}
print(json.dumps(data, indent=2))
" > "$OUTPUT_FILE"

echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║   Metasploitable CTF — Déploiement terminé !   ║"
echo "╠════════════════════════════════════════════════╣"
echo "║  VM $META_VM_ID   Metasploitable   $META_IP         ║"
echo "║  VM $KALI_VM_ID   Kali             $KALI_IP  ║"
echo "╠════════════════════════════════════════════════╣"
echo "║  SSH     msfadmin / msfadmin                   ║"
echo "╠════════════════════════════════════════════════╣"
echo "║  tf_output.json généré                         ║"
echo "╚════════════════════════════════════════════════╝"
