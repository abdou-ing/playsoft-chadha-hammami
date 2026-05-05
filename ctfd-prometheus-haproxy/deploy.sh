#!/bin/bash
# ============================================================
# deploy.sh — Déploiement complet CTFd HA
#
# Usage : ./deploy.sh
#
# Prérequis :
#   - Packer installé
#   - Ansible installé
#   - sshpass installé
#   - Variable d'environnement PKR_VAR_proxmox_api_token_secret exportée
#
# Ce script :
#   1. Build Machine 1 via Packer + Ansible
#   2. Récupère l'IP de Machine 1 via API Proxmox
#   3. Lit le binlog depuis binlog_info.json sur Machine 1
#   4. Build Machine 2 via Packer + Ansible avec les infos de Machine 1
# ============================================================

set -e

# ============================================================
# CONFIG
# ============================================================
PROXMOX_URL="https://proxmox.playsoft.io:8006/api2/json"
PROXMOX_TOKEN_ID="chadha@pve!packer"
PROXMOX_TOKEN_SECRET="${PKR_VAR_proxmox_api_token_secret}"
PROXMOX_NODE="playsoft-proxmox"
PROXMOX_BASTION="138.201.200.168"
PROXMOX_BASTION_KEY="/home/chadha/.ssh/id_ecdsa"
SSH_USER="bob"
SSH_PASS="123456"

VM_ID_MASTER="201"
VM_ID_REPLICA="202"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================
# VÉRIFICATIONS
# ============================================================
if [ -z "$PKR_VAR_proxmox_api_token_secret" ]; then
  echo "ERREUR : PKR_VAR_proxmox_api_token_secret non défini"
  echo "Exporter le secret : export PKR_VAR_proxmox_api_token_secret='votre_secret'"
  exit 1
fi

command -v packer >/dev/null 2>&1 || { echo "ERREUR : packer non installé"; exit 1; }
command -v ansible-playbook >/dev/null 2>&1 || { echo "ERREUR : ansible non installé"; exit 1; }
command -v sshpass >/dev/null 2>&1 || { echo "ERREUR : sshpass non installé"; exit 1; }

echo "============================================="
echo " CTFd HA — Déploiement automatisé"
echo "============================================="

# ============================================================
# ÉTAPE 1 — BUILD MACHINE 1
# ============================================================
echo ""
echo "[1/4] Build Machine 1 (CTFd Master)..."
cd "$SCRIPT_DIR/packer/ctfd-master"
packer init .
packer build .

# ============================================================
# ÉTAPE 2 — RÉCUPÉRER L'IP DE MACHINE 1 VIA API PROXMOX
# ============================================================
# ============================================================
# ÉTAPE 2 — RÉCUPÉRER L'IP DE MACHINE 1 VIA API PROXMOX
# ============================================================
echo ""
echo "[2/4] Récupération IP Machine 1 via API Proxmox..."

MACHINE1_IP=""
ATTEMPTS=0
MAX_ATTEMPTS=24  # 24 x 10s = 4 minutes max

while [ -z "$MACHINE1_IP" ] && [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
  ATTEMPTS=$((ATTEMPTS + 1))
  echo "  Tentative $ATTEMPTS/$MAX_ATTEMPTS..."
  sleep 10

  MACHINE1_IP=$(curl -sk \
    -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN_ID}=${PROXMOX_TOKEN_SECRET}" \
    "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/qemu/${VM_ID_MASTER}/agent/network-get-interfaces" \
    | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for iface in data['data']['result']:
        if iface['name'] != 'lo':
            for addr in iface.get('ip-addresses', []):
                if addr['ip-address-type'] == 'ipv4':
                    print(addr['ip-address'])
                    sys.exit(0)
except:
    pass
" 2>/dev/null || true)
done

if [ -z "$MACHINE1_IP" ]; then
  echo "ERREUR : Impossible de récupérer l'IP de Machine 1 après $MAX_ATTEMPTS tentatives"
  exit 1
fi

echo "Machine 1 IP : $MACHINE1_IP"

# ============================================================
# ÉTAPE 3 — LIRE LE BINLOG DEPUIS MACHINE 1
# ============================================================
echo ""
echo "[3/4] Lecture binlog depuis Machine 1..."

BINLOG_JSON=$(sshpass -p "$SSH_PASS" \
  ssh -o StrictHostKeyChecking=no \
  -o ProxyJump=abdou@${PROXMOX_BASTION} \
  ${SSH_USER}@${MACHINE1_IP} \
  "cat /home/bob/binlog_info.json")

BINLOG_FILE=$(echo "$BINLOG_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['binlog_file'])")
BINLOG_POS=$(echo "$BINLOG_JSON"  | python3 -c "import sys,json; print(json.load(sys.stdin)['binlog_pos'])")

if [ -z "$BINLOG_FILE" ] || [ -z "$BINLOG_POS" ]; then
  echo "ERREUR : Impossible de lire le binlog depuis Machine 1"
  exit 1
fi

echo "Binlog File : $BINLOG_FILE"
echo "Binlog Pos  : $BINLOG_POS"

# ============================================================
# ÉTAPE 4 — BUILD MACHINE 2 AVEC INFOS DE MACHINE 1
# ============================================================
echo ""
echo "[4/4] Build Machine 2 (CTFd Replica)..."
cd "$SCRIPT_DIR/packer/ctfd-replica"
packer init .
packer build \
  -var "machine1_ip=${MACHINE1_IP}" \
  -var "binlog_file=${BINLOG_FILE}" \
  -var "binlog_pos=${BINLOG_POS}" \
  .



# ============================================================
# ÉTAPE 5 — RÉCUPÉRER L'IP DE MACHINE 2
# ============================================================
echo ""
echo "[5/6] Récupération IP Machine 2 via API Proxmox..."

MACHINE2_IP=""
ATTEMPTS=0
MAX_ATTEMPTS=24

while [ -z "$MACHINE2_IP" ] && [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
  ATTEMPTS=$((ATTEMPTS + 1))
  echo "  Tentative $ATTEMPTS/$MAX_ATTEMPTS..."
  sleep 10
  MACHINE2_IP=$(curl -sk \
    -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN_ID}=${PROXMOX_TOKEN_SECRET}" \
    "${PROXMOX_URL}/nodes/${PROXMOX_NODE}/qemu/${VM_ID_REPLICA}/agent/network-get-interfaces" \
    | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for iface in data['data']['result']:
        if iface['name'] != 'lo':
            for addr in iface.get('ip-addresses', []):
                if addr['ip-address-type'] == 'ipv4':
                    print(addr['ip-address'])
                    sys.exit(0)
except:
    pass
" 2>/dev/null || true)
done

if [ -z "$MACHINE2_IP" ]; then
  echo "ERREUR : Impossible de récupérer l'IP de Machine 2"
  exit 1
fi

echo "Machine 2 IP : $MACHINE2_IP"

# ============================================================
# ÉTAPE 6 — BUILD MACHINE 3 PROMETHEUS
# ============================================================
echo ""
echo "[6/6] Build Machine 3 (Prometheus)..."
cd "$SCRIPT_DIR/packer/ctfd-prometheus"
packer init .
packer build \
  -var "machine1_ip=${MACHINE1_IP}" \
  -var "machine2_ip=${MACHINE2_IP}" \
  .



# ============================================================
# ÉTAPE 7 — BUILD MACHINE 4 HAPROXY
# ============================================================
echo ""
echo "[7/7] Build Machine 4 (HAProxy Load Balancer)..."
cd "$SCRIPT_DIR/packer/ctfd-haproxy"
packer init .
packer build \
  -var "machine1_ip=${MACHINE1_IP}" \
  -var "machine2_ip=${MACHINE2_IP}" \
  .
# ============================================================
# RÉSUMÉ FINAL
# ============================================================
echo ""
echo "============================================="
echo " CTFd HA — Déploiement terminé !"
echo "============================================="
echo " Machine 1 (Master)  : http://${MACHINE1_IP}:8000"
echo " Machine 2 (Replica) : récupérer IP dans Proxmox VM ${VM_ID_REPLICA}"
echo " MariaDB Master  : ${MACHINE1_IP}:3307"
echo " Redis           : ${MACHINE1_IP}:6380"
echo " node_exporter M1: ${MACHINE1_IP}:9100"
echo " blackbox_exp M1 : ${MACHINE1_IP}:9115"
echo " Machine 3 (Prometheus) : récupérer IP dans Proxmox VM 203"
echo " Prometheus             : VM203:9090"
echo " Alertmanager           : VM203:9093"
echo " Machine 4 (HAProxy)     : http://VM204_IP:80"
echo " Load Balancer CTFd      : VM204_IP:80"
echo " Load Balancer MariaDB   : VM204_IP:3306"
echo "============================================="