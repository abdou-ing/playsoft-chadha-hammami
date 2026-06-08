#!/usr/bin/env bash
# ================================================================
# deploy-wazuh.sh — Wazuh Easy Lab
#
# PHASE 1 — Packer    : build templates (skip si déjà existantes)
# PHASE 2 — Terraform : clone templates + démarre VMs (idempotent)
# PHASE 3 — Ansible   : cleanup + connexions Guacamole + URLs
#
# Usage :
#   export VAULT_TOKEN="hvs.xxxxx"
#   bash deploy-wazuh.sh
# ================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"
ANSIBLE_DIR="$HOME/playsoft-jilani-gharbi/playsoft-infra/ansible"
OUTPUT_FILE="$HOME/playsoft-jilani-gharbi/playsoft-infra/packer/tf_output.json"
ANSIBLE_LOG="/tmp/ansible-guacamole-easy.log"

WAZUH_IP="10.0.30.142"
AGENT_IP="10.0.30.47"
UNIFIED_IP="10.0.30.65"
WAZUH_PASS="Playsoft@2026#Lab"

PROXMOX_URL="https://playsoft-proxmox:8006/api2/json"
PROXMOX_NODE="playsoft-proxmox"
TF_TOKEN_ID="chadha@pve!packer"

bash "$SCRIPT_DIR/setup-env.sh"

VAULT_ADDR="https://vault.dev.playsoft.io:8200"
if [ -z "${VAULT_TOKEN:-}" ]; then
  echo "[ERROR] Lance d'abord : export VAULT_TOKEN='ton_token'"
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

echo "[+] Secrets récupérés ✅"



# ================================================================
# PHASE 1 — PACKER (skip si template déjà existante)
# ================================================================
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  PHASE 1 — Packer : build des templates      ║"
echo "╚══════════════════════════════════════════════╝"

export PKR_VAR_proxmox_api_token_secret="$PROXMOX_SECRET"
export PKR_VAR_ssh_password="$SSH_PASS"
export PKR_VAR_testuser_password="$TESTUSER_PASS"

SKIP_PACKER="${SKIP_PACKER:-0}"
RECREATE_VMS="${RECREATE_VMS:-0}"
START_FROM="${START_FROM:-server}"
case "$START_FROM" in
  server|agent|unified) ;;
  *)
    echo "[ERROR] START_FROM doit valoir: server, agent ou unified"
    exit 1
    ;;
esac
echo "[*] Reprise depuis: $START_FROM"

cd "$SCRIPT_DIR"
packer init .
if [ "$SKIP_PACKER" = "1" ]; then
  echo "  [1/3] Skip Wazuh Server (SKIP_PACKER=1)"
  echo "  [2/3] Skip Wazuh Agent (SKIP_PACKER=1)"
  echo "  [3/3] Skip Unified VM (SKIP_PACKER=1)"
else

# ── 1/3 Wazuh Server ──────────────────────────────────────────
echo ""

if [ "$START_FROM" = "server" ]; then
  echo "  [1/3] Build template Wazuh Server (VMID 1206)..."
  packer build -only="wazuh-server.proxmox-clone.wazuh-server" .
  echo "  ✅ Template Wazuh Server créée"
else
  echo "  [1/3] Skip Wazuh Server (déjà créée)"
fi


# ── 2/3 Wazuh Agent ───────────────────────────────────────────

if [ "$START_FROM" = "server" ] || [ "$START_FROM" = "agent" ]; then
  echo "  [2/3] Build template Wazuh Agent (VMID 1207)..."
  packer build \
    -only="wazuh-agent.proxmox-clone.wazuh-agent" \
    -var "wazuh_ip=$WAZUH_IP" \
    .
  echo "  ✅ Template Wazuh Agent créée"
else
  echo "  [2/3] Skip Wazuh Agent (déjà créée)"
fi


# ── 3/3 Unified VM ────────────────────────────────────────────

if [ "$START_FROM" = "server" ] || [ "$START_FROM" = "agent" ] || [ "$START_FROM" = "unified" ]; then
  echo "  [3/3] Build template Unified VM (VMID 1208)..."
  packer build \
    -only="wazuh-unified.proxmox-clone.wazuh-unified" \
    -var "agent_ip=$AGENT_IP" \
    .
  echo "  ✅ Template Unified VM créée"
else
  echo "  [3/3] Skip Unified VM (déjà créée)"
fi


fi

# ── Récupération des VMIDs templates ──────────────────────────
echo ""
echo "[*] Récupération des VMIDs de templates depuis Proxmox..."

TEMPLATES_JSON=$(curl -sk \
  -H "Authorization: PVEAPIToken=$TF_TOKEN_ID=$PROXMOX_SECRET" \
  "$PROXMOX_URL/nodes/$PROXMOX_NODE/qemu" \
  | python3 -c "
import sys, json
vms = json.load(sys.stdin)['data']
result = {v['name']: v['vmid'] for v in vms if v.get('template') == 1}
print(json.dumps(result))
")

WAZUH_SERVER_TPL_ID=$(python3 -c "
import json
t = json.loads('$TEMPLATES_JSON')
items = sorted([(v,k) for k,v in t.items() if k.startswith('wazuh-server-')], reverse=True)
print(items[0][0] if items else '')
")

WAZUH_AGENT_TPL_ID=$(python3 -c "
import json
t = json.loads('$TEMPLATES_JSON')
items = sorted([(v,k) for k,v in t.items() if k.startswith('wazuh-agent-')], reverse=True)
print(items[0][0] if items else '')
")

WAZUH_UNIFIED_TPL_ID=$(python3 -c "
import json
t = json.loads('$TEMPLATES_JSON')
items = sorted([(v,k) for k,v in t.items() if k.startswith('wazuh-unified-')], reverse=True)
print(items[0][0] if items else '')
")

# Utilise les VMIDs fixes des templates Packer attendues.
# La détection par nom peut choisir une ancienne template avec un VMID plus grand.
WAZUH_SERVER_TPL_ID="${WAZUH_SERVER_TEMPLATE_ID:-1206}"
WAZUH_AGENT_TPL_ID="${WAZUH_AGENT_TEMPLATE_ID:-1207}"
WAZUH_UNIFIED_TPL_ID="${WAZUH_UNIFIED_TEMPLATE_ID:-1208}"

if [ -z "$WAZUH_SERVER_TPL_ID" ] || [ -z "$WAZUH_AGENT_TPL_ID" ] || [ -z "$WAZUH_UNIFIED_TPL_ID" ]; then
  echo "[ERROR] Template(s) introuvable(s). Vérifier le build Packer."
  exit 1
fi

echo "  ✅ wazuh-server  VMID : $WAZUH_SERVER_TPL_ID"
echo "  ✅ wazuh-agent   VMID : $WAZUH_AGENT_TPL_ID"
echo "  ✅ wazuh-unified VMID : $WAZUH_UNIFIED_TPL_ID"

# ================================================================
# PHASE 2 — TERRAFORM (idempotent grâce au tfstate)
# ================================================================
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  PHASE 2 — Terraform : création des VMs      ║"
echo "╚══════════════════════════════════════════════╝"

cd "$TERRAFORM_DIR"

cat > terraform.tfvars <<EOF
proxmox_url              = "$PROXMOX_URL"
proxmox_node             = "$PROXMOX_NODE"
proxmox_api_token_id     = "$TF_TOKEN_ID"
proxmox_api_token_secret = "$PROXMOX_SECRET"
proxmox_bastion_key      = "/home/chadha/.ssh/id_ecdsa"

wazuh_server_template_id  = $WAZUH_SERVER_TPL_ID
wazuh_agent_template_id   = $WAZUH_AGENT_TPL_ID
wazuh_unified_template_id = $WAZUH_UNIFIED_TPL_ID

wazuh_server_vmid  = 206
wazuh_agent_vmid   = 207
wazuh_unified_vmid = 208

wazuh_server_ip  = "$WAZUH_IP"
wazuh_agent_ip   = "$AGENT_IP"
wazuh_unified_ip = "$UNIFIED_IP"

storage_pool      = "local"
bastion_public_ip = "95.217.170.118"
EOF

terraform init -upgrade
if [ "$RECREATE_VMS" = "1" ]; then
  echo "[*] Suppression ciblée des VMs 206 / 207 / 208 avant recréation..."
  terraform destroy -auto-approve \
    -target=proxmox_virtual_environment_vm.wazuh_unified \
    -target=proxmox_virtual_environment_vm.wazuh_agent \
    -target=proxmox_virtual_environment_vm.wazuh_server
fi
terraform plan -out=tfplan
terraform apply tfplan

echo "[+] VMs 206 / 207 / 208 — état synchronisé ✅"

echo ""
echo "[*] Génération de $OUTPUT_FILE..."
mkdir -p "$(dirname "$OUTPUT_FILE")"
terraform output -json guacamole > "$OUTPUT_FILE"
echo "[+] tf_output.json généré ✅"

rm -f terraform.tfvars tfplan
echo "[+] terraform.tfvars supprimé ✅"

# ================================================================
# PHASE 3 — ANSIBLE : cleanup + connexions Guacamole
# ================================================================
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  PHASE 3 — Ansible : connexions Guacamole    ║"
echo "╚══════════════════════════════════════════════╝"

cd "$ANSIBLE_DIR"

ansible-playbook cleanup_vnc.yml
ansible-playbook site.yml \
  --tags "access_setup,guacamole_connection,guacamole_url" \
  -e "connection_prefix=wazuh-easy" \
  2>&1 | tee "$ANSIBLE_LOG"

echo "[+] Connexions Guacamole créées ✅"

# ── Parser les URLs depuis le log Ansible ─────────────────────
HOMEPAGE=$(grep -o 'http://[^ "]*guacamole/\?token=[^ "]*' "$ANSIBLE_LOG" | head -1 || true)
VNC_URLS=$(grep -o 'http://[^ "]*guacamole/#/client/[^ "]*' "$ANSIBLE_LOG" | sed 's/",$//' || true)

# ================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   Wazuh Easy Lab — Déploiement terminé !                     ║"
echo "╠══════════════════════════════════════════════════════════════╣"
printf  "║  VM 206  Wazuh Server   https://%-29s ║\n" "$WAZUH_IP"
printf  "║  VM 207  Agent          %-33s ║\n" "$AGENT_IP"
printf  "║  VM 208  Unified VM     %-33s ║\n" "$UNIFIED_IP"
echo "╠══════════════════════════════════════════════════════════════╣"
printf  "║  Login Wazuh: admin / %-39s ║\n" "$WAZUH_PASS"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Guacamole connections :                                     ║"
if [ -n "$HOMEPAGE" ]; then
  printf  "║  Homepage : %-49s ║\n" "$HOMEPAGE"
fi
if [ -n "$VNC_URLS" ]; then
  i=1
  while IFS= read -r url; do
    printf  "║  VNC (%s)  : %-49s ║\n" "$i" "$url"
    i=$((i+1))
  done <<< "$VNC_URLS"
else
  echo "║  (voir logs Ansible pour les URLs)                           ║"
fi
echo "╚══════════════════════════════════════════════════════════════╝"

rm -f "$ANSIBLE_LOG"
