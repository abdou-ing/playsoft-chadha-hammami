#!/usr/bin/env bash
# ================================================================
# deploy-metasploitable.sh — Metasploitable CTF Lab
#
# PHASE 1 — Packer    : build template Metasploitable (skip si existante)
#                       Kali → template existante 104 (pas de build)
# PHASE 2 — Terraform : clone templates + démarre VMs
#                       Metasploitable IP statique / Kali IP DHCP
#                       génère tf_output.json
# PHASE 3 — Ansible   : cleanup + connexions Guacamole + URLs
#
# Usage :
#   export PKR_VAR_proxmox_api_token_secret="ton_secret"
#   bash deploy-metasploitable.sh
# ================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"
ANSIBLE_DIR="$HOME/playsoft-jilani-gharbi/playsoft-infra/ansible"
OUTPUT_FILE="$HOME/playsoft-jilani-gharbi/playsoft-infra/packer/tf_output.json"
ANSIBLE_LOG="/tmp/ansible-guacamole-meta.log"

PROXMOX_URL="https://playsoft-proxmox:8006/api2/json"
PROXMOX_NODE="playsoft-proxmox"
TF_TOKEN_ID="chadha@pve!packer"
KALI_TEMPLATE_ID=104
META_IP="10.0.30.99"

bash "$SCRIPT_DIR/setup-env.sh"

# ── Secret Proxmox ────────────────────────────────────────────
if [ -z "${PKR_VAR_proxmox_api_token_secret:-}" ]; then
  echo "[ERROR] Lance d'abord : export PKR_VAR_proxmox_api_token_secret='ton_secret'"
  exit 1
fi

PROXMOX_SECRET="$PKR_VAR_proxmox_api_token_secret"
echo "[+] Secret Proxmox récupéré ✅"

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
# PHASE 1 — PACKER : build template Metasploitable (skip si existante)
# ================================================================
echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║  PHASE 1 — Packer : build template Metasploitable  ║"
echo "║  Kali → template existante 104 (pas de build)      ║"
echo "╚════════════════════════════════════════════════════╝"

cd "$SCRIPT_DIR"
packer init .

echo ""
EXISTING=$(template_exists "TPL-Metasploitable-CTF-")
if [ -n "$EXISTING" ]; then
  echo "  ⏭️  Template Metasploitable déjà existante ($EXISTING) — skip"
else
  echo "  [1/1] Build template Metasploitable (VMID 1301)..."
  packer build .
  echo "  ✅ Template Metasploitable créée"
fi

# ── Récupération du VMID template Metasploitable ──────────────
echo ""
echo "[*] Récupération du VMID template depuis Proxmox..."

TEMPLATES_JSON=$(curl -sk \
  -H "Authorization: PVEAPIToken=$TF_TOKEN_ID=$PROXMOX_SECRET" \
  "$PROXMOX_URL/nodes/$PROXMOX_NODE/qemu" \
  | python3 -c "
import sys, json
vms = json.load(sys.stdin)['data']
result = {v['name']: v['vmid'] for v in vms if v.get('template') == 1}
print(json.dumps(result))
")

META_TPL_ID=$(python3 -c "
import json
t = json.loads('$TEMPLATES_JSON')
items = sorted([(v,k) for k,v in t.items() if k.startswith('TPL-Metasploitable-CTF-')], reverse=True)
print(items[0][0] if items else '')
")

if [ -z "$META_TPL_ID" ]; then
  echo "[ERROR] Template Metasploitable introuvable. Vérifier le build Packer."
  exit 1
fi

echo "  ✅ Metasploitable template VMID : $META_TPL_ID"
echo "  ✅ Kali template VMID           : $KALI_TEMPLATE_ID (existante)"

# ================================================================
# PHASE 2 — TERRAFORM : création des VMs
# ================================================================
echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║  PHASE 2 — Terraform : création des VMs            ║"
echo "║  Metasploitable→301  Kali→302                      ║"
echo "╚════════════════════════════════════════════════════╝"

cd "$TERRAFORM_DIR"

cat > terraform.tfvars <<EOF
proxmox_url              = "$PROXMOX_URL"
proxmox_node             = "$PROXMOX_NODE"
proxmox_api_token_id     = "$TF_TOKEN_ID"
proxmox_api_token_secret = "$PROXMOX_SECRET"
proxmox_bastion_key      = "/home/chadha/.ssh/id_ecdsa"

meta_template_id = $META_TPL_ID
kali_template_id = $KALI_TEMPLATE_ID

meta_vmid = 301
kali_vmid = 302

meta_ip           = "$META_IP"
storage_pool      = "local"
bastion_public_ip = "188.245.215.21"
EOF

terraform init -upgrade
terraform plan -out=tfplan
terraform apply tfplan

echo "[+] VMs 301 (Metasploitable) / 302 (Kali) créées et démarrées ✅"

# ── Récupération des IPs ───────────────────────────────────────
echo ""
echo "[*] Récupération des IPs..."

KALI_IP=$(terraform output -raw kali_ip)

echo "  ✅ Metasploitable IP : $META_IP (statique)"
echo "  ✅ Kali IP           : $KALI_IP (DHCP)"

# ── Génération tf_output.json ─────────────────────────────────
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
echo "╔════════════════════════════════════════════════════╗"
echo "║  PHASE 3 — Ansible : connexions Guacamole          ║"
echo "╚════════════════════════════════════════════════════╝"

cd "$ANSIBLE_DIR"

ansible-playbook cleanup_vnc.yml || true
ansible-playbook site.yml \
  --tags "access_setup,guacamole_connection,guacamole_url" \
  -e "connection_prefix=metasploitable-ctf" \
  2>&1 | tee "$ANSIBLE_LOG"

echo "[+] Connexions Guacamole créées ✅"

# ── Parser les URLs depuis le log Ansible ─────────────────────
HOMEPAGE=$(grep -o 'http://[^ "]*guacamole/\?token=[^ "]*' "$ANSIBLE_LOG" | head -1 || true)
VNC_URLS=$(grep -o 'http://[^ "]*guacamole/#/client/[^ "]*' "$ANSIBLE_LOG" | sed 's/",$//' || true)

# ================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   Metasploitable CTF Lab — Déploiement terminé !             ║"
echo "╠══════════════════════════════════════════════════════════════╣"
printf  "║  VM 301  Metasploitable  IP: %-33s ║\n" "$META_IP"
printf  "║  VM 302  Kali            IP: %-33s ║\n" "$KALI_IP"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  SSH Metasploitable : msfadmin / msfadmin                    ║"
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
