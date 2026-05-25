#!/usr/bin/env bash
# ================================================================
# deploy-wazuh-medium.sh — Wazuh Medium Lab
#
# PHASE 1 — Packer    : build templates (skip si déjà existantes)
# PHASE 2 — Terraform : clone templates + démarre VMs (idempotent)
# PHASE 3 — Ansible   : cleanup + connexions Guacamole + URLs
#
# Usage :
#   export VAULT_TOKEN="hvs.xxxxx"
#   bash deploy-wazuh-medium.sh
# ================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"
ANSIBLE_DIR="$HOME/playsoft-jilani-gharbi/playsoft-infra/ansible"
OUTPUT_FILE="$HOME/playsoft-jilani-gharbi/playsoft-infra/packer/tf_output.json"
ANSIBLE_LOG="/tmp/ansible-guacamole-medium.log"

WAZUH_IP="10.0.30.142"
AGENT_IP="10.0.30.147"
UNIFIED_IP="10.0.30.165"

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

# ── Helper : vérifie si une template existe déjà sur Proxmox ──
template_exists() {
  local prefix="$1"
  curl -sk \
    -H "Authorization: PVEAPIToken=$TF_TOKEN_ID=$PROXMOX_SECRET" \
    "$PROXMOX_URL/nodes/$PROXMOX_NODE/qemu" \
    | python3 -c "
import sys, json
vms = json.load(sys.stdin)['data']
names = [v['name'] for v in vms if v.get('template') == 1 and v['name'].startswith('$prefix')]
print(names[0] if names else '')
"
}

# ================================================================
# PHASE 1 — PACKER (skip si template déjà existante)
# ================================================================
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  PHASE 1 — Packer : build des templates          ║"
echo "║  Server→1211  Agent→1212  Unified→1213           ║"
echo "╚══════════════════════════════════════════════════╝"

export PKR_VAR_proxmox_api_token_secret="$PROXMOX_SECRET"
export PKR_VAR_ssh_password="$SSH_PASS"
export PKR_VAR_testuser_password="$TESTUSER_PASS"

cd "$SCRIPT_DIR"
packer init .

# ── 1/3 Wazuh Server Medium ───────────────────────────────────
echo ""
EXISTING=$(template_exists "wazuh-server-medium")
if [ -n "$EXISTING" ]; then
  echo "  ⏭️  Template wazuh-server-medium déjà existante ($EXISTING) — skip"
else
  echo "  [1/3] Build template Wazuh Server Medium (VMID 1211)..."
  packer build -only="wazuh-server-medium.proxmox-clone.wazuh-server-medium" .
  echo "  ✅ Template wazuh-server-medium créée"
fi

# ── 2/3 Wazuh Agent Medium ────────────────────────────────────
echo ""
EXISTING=$(template_exists "wazuh-agent-medium")
if [ -n "$EXISTING" ]; then
  echo "  ⏭️  Template wazuh-agent-medium déjà existante ($EXISTING) — skip"
else
  echo "  [2/3] Build template Wazuh Agent Medium (VMID 1212)..."
  packer build \
    -only="wazuh-agent-medium.proxmox-clone.wazuh-agent-medium" \
    -var "wazuh_ip=$WAZUH_IP" \
    .
  echo "  ✅ Template wazuh-agent-medium créée"
fi

# ── 3/3 Unified VM Medium ─────────────────────────────────────
echo ""
EXISTING=$(template_exists "wazuh-unified-medium")
if [ -n "$EXISTING" ]; then
  echo "  ⏭️  Template wazuh-unified-medium déjà existante ($EXISTING) — skip"
else
  echo "  [3/3] Build template Unified VM Medium (VMID 1213)..."
  packer build \
    -only="wazuh-unified-medium.proxmox-clone.wazuh-unified-medium" \
    -var "agent_ip=$AGENT_IP" \
    .
  echo "  ✅ Template wazuh-unified-medium créée"
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
items = sorted([(v,k) for k,v in t.items() if k.startswith('wazuh-server-medium')], reverse=True)
print(items[0][0] if items else '')
")

WAZUH_AGENT_TPL_ID=$(python3 -c "
import json
t = json.loads('$TEMPLATES_JSON')
items = sorted([(v,k) for k,v in t.items() if k.startswith('wazuh-agent-medium')], reverse=True)
print(items[0][0] if items else '')
")

WAZUH_UNIFIED_TPL_ID=$(python3 -c "
import json
t = json.loads('$TEMPLATES_JSON')
items = sorted([(v,k) for k,v in t.items() if k.startswith('wazuh-unified-medium')], reverse=True)
print(items[0][0] if items else '')
")

if [ -z "$WAZUH_SERVER_TPL_ID" ] || [ -z "$WAZUH_AGENT_TPL_ID" ] || [ -z "$WAZUH_UNIFIED_TPL_ID" ]; then
  echo "[ERROR] Template(s) introuvable(s). Vérifier le build Packer."
  exit 1
fi

echo "  ✅ wazuh-server-medium  VMID : $WAZUH_SERVER_TPL_ID"
echo "  ✅ wazuh-agent-medium   VMID : $WAZUH_AGENT_TPL_ID"
echo "  ✅ wazuh-unified-medium VMID : $WAZUH_UNIFIED_TPL_ID"

# ================================================================
# PHASE 2 — TERRAFORM (idempotent grâce au tfstate)
# ================================================================
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  PHASE 2 — Terraform : création des VMs          ║"
echo "║  Server→211  Agent→212  Unified→213              ║"
echo "╚══════════════════════════════════════════════════╝"

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

wazuh_server_vmid  = 211
wazuh_agent_vmid   = 212
wazuh_unified_vmid = 213

wazuh_server_ip  = "$WAZUH_IP"
wazuh_agent_ip   = "$AGENT_IP"
wazuh_unified_ip = "$UNIFIED_IP"

storage_pool      = "local"
bastion_public_ip = "188.245.215.21"
EOF

terraform init -upgrade
terraform plan -out=tfplan
terraform apply tfplan

echo "[+] VMs 211 / 212 / 213 — état synchronisé ✅"

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
echo "╔══════════════════════════════════════════════════╗"
echo "║  PHASE 3 — Ansible : connexions Guacamole        ║"
echo "╚══════════════════════════════════════════════════╝"

cd "$ANSIBLE_DIR"

ansible-playbook cleanup_vnc.yml 

ansible-playbook site.yml \
  --tags "access_setup,guacamole_connection,guacamole_url" \
  -e "connection_prefix=wazuh-medium" \
  2>&1 | tee "$ANSIBLE_LOG"

echo "[+] Connexions Guacamole créées ✅"

# ── Parser les URLs depuis le log Ansible ─────────────────────
HOMEPAGE=$(grep -o 'http://[^ "]*guacamole/\?token=[^ "]*' "$ANSIBLE_LOG" | head -1 || true)
VNC_URLS=$(grep -o 'http://[^ "]*guacamole/#/client/[^ "]*' "$ANSIBLE_LOG" | sed 's/",$//' || true)

# ================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   Wazuh Medium Lab — Déploiement terminé !                   ║"
echo "╠══════════════════════════════════════════════════════════════╣"
printf  "║  VM 211  Wazuh Server  (vide) %-31s ║\n" "$WAZUH_IP"
printf  "║  VM 212  Wazuh Agent   (vide) %-31s ║\n" "$AGENT_IP"
printf  "║  VM 213  Unified VM           %-31s ║\n" "$UNIFIED_IP"
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
