#!/usr/bin/env bash
set -euo pipefail

# Setup environnement
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/setup-env.sh"

cd "$(dirname "$0")"
packer init .
packer build .

echo "✅ DVWA déployé avec succès"