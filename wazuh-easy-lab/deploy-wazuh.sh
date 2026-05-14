#!/usr/bin/env bash
# ============================================================
# deploy-wazuh.sh — Déploiement Wazuh Lab (5 VMs) via Packer
# ============================================================
set -euo pipefail

if [ -z "${PKR_VAR_proxmox_api_token_secret:-}" ]; then
  echo "[ERROR] Exporter d'abord: export PKR_VAR_proxmox_api_token_secret='votre_secret'"
  exit 1
fi

PROXMOX_HOST="138.201.200.168"
API_URL="https://proxmox.playsoft.io:8006/api2/json"
NODE="playsoft-proxmox"
TOKEN_ID="chadha@pve!packer"
TOKEN_SECRET="$PKR_VAR_proxmox_api_token_secret"

# Password admin fixé par Packer — pas besoin de SSH pour le récupérer
WAZUH_PASS="Playsoft@2026#Lab"

# ── Fonction : attente IP via API Proxmox ────────────────────
get_vm_ip() {
  local VMID=$1
  local IP=""
  local ATTEMPTS=0
  echo "  [*] Attente IP pour VM $VMID..." >&2
  while [ -z "$IP" ] && [ $ATTEMPTS -lt 30 ]; do
    ATTEMPTS=$((ATTEMPTS + 1))
    sleep 10
    IP=$(curl -sk \
      -H "Authorization: PVEAPIToken=$TOKEN_ID=$TOKEN_SECRET" \
      "$API_URL/nodes/$NODE/qemu/$VMID/agent/network-get-interfaces" \
      | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for iface in data.get('data', {}).get('result', []):
        if iface.get('name') in ('eth0', 'ens18', 'enp6s18'):
            for ip in iface.get('ip-addresses', []):
                if ip.get('ip-address-type') == 'ipv4' and not ip['ip-address'].startswith('127'):
                    print(ip['ip-address'])
                    sys.exit(0)
except: pass
" 2>/dev/null || true)
    echo "  Tentative $ATTEMPTS/30 — IP VM $VMID: ${IP:-en attente...}" >&2
  done
  echo "$IP"
}

cd "$(dirname "$0")"
packer init .

# ════════════════════════════════════════════════════════════
echo ""
echo "========================================="
echo "  [1/5] Build VM 206 — Wazuh Server"
echo "========================================="
packer build -only="wazuh-server.proxmox-clone.wazuh-server" .

echo ""
echo "  [2/5] Récupération IP Wazuh Server (VM 206)..."
WAZUH_IP="10.0.30.42"
if [ -z "$WAZUH_IP" ]; then
  echo "[ERROR] IP Wazuh introuvable. Vérifier VM 206 dans Proxmox."
  exit 1
fi
echo "  ✅ Wazuh Server IP : $WAZUH_IP"
echo "  ✅ Wazuh admin password : $WAZUH_PASS (fixé par Packer)"

# ════════════════════════════════════════════════════════════
echo ""
echo "========================================="
echo "  [3/5] Build VM 207 — Wazuh Agent"
echo "  wazuh_ip = $WAZUH_IP"
echo "========================================="
packer build \
  -only="wazuh-agent.proxmox-clone.wazuh-agent" \
  -var "wazuh_ip=$WAZUH_IP" \
  .

echo ""
echo "  [4/5] Récupération IP Agent (VM 207)..."
AGENT_IP="10.0.30.47"
if [ -z "$AGENT_IP" ]; then
  echo "[ERROR] IP Agent introuvable. Vérifier VM 207 dans Proxmox."
  exit 1
fi
echo "  ✅ Agent IP : $AGENT_IP"

# ════════════════════════════════════════════════════════════
echo ""
echo "========================================="
echo "  [5/5a] Build VM 208 — Brute Force"
echo "  agent_ip = $AGENT_IP"
echo "========================================="
packer build \
  -only="wazuh-attack.proxmox-clone.wazuh-attack" \
  -var "agent_ip=$AGENT_IP" \
  .

echo ""
echo "========================================="
echo "  [5/5b] Build VM 209 — Faux Positifs"
echo "  agent_ip = $AGENT_IP"
echo "========================================="
packer build \
  -only="wazuh-fauxpositif.proxmox-clone.wazuh-fauxpositif" \
  -var "agent_ip=$AGENT_IP" \
  .

echo ""
echo "========================================="
echo "  [5/5c] Build VM 210 — Legit SSH"
echo "  agent_ip = $AGENT_IP"
echo "========================================="
packer build \
  -only="wazuh-legit.proxmox-clone.wazuh-legit" \
  -var "agent_ip=$AGENT_IP" \
  .

# ════════════════════════════════════════════════════════════
echo "╔════════════════════════════════════════════════╗"
echo "║   Wazuh Lab — Déploiement terminé !            ║"
echo "╠════════════════════════════════════════════════╣"
printf  "║  VM 206  Wazuh Server   https://%-15s ║\n" "$WAZUH_IP"
printf  "║  VM 207  Agent          %-22s ║\n" "$AGENT_IP"
printf  "║  VM 208  Brute Force    %-22s ║\n" "10.0.30.65"
printf  "║  VM 209  Faux Positifs  %-22s ║\n" "10.0.30.56"
printf  "║  VM 210  Legit SSH      %-22s ║\n" "10.0.30.100"
echo "╠════════════════════════════════════════════════╣"
printf  "║  Login Wazuh: admin / %-25s ║\n" "$WAZUH_PASS"
echo "╚════════════════════════════════════════════════╝"