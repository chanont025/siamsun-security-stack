#!/bin/bash
set -euo pipefail

WAZUH_VERSION="4.14.6"
BASE_URL="https://packages.wazuh.com/4.14"

echo "=== Wazuh Security Stack Setup (v$WAZUH_VERSION) ==="
echo ""

# ---- Check dependencies ----
command -v python3 >/dev/null 2>&1 || { echo "Need python3"; exit 1; }
python3 -c "import bcrypt" 2>/dev/null || pip3 install bcrypt 2>/dev/null || { echo "Need: pip3 install bcrypt"; exit 1; }

# ---- .env ----
if [ ! -f .env ]; then
  echo "[1/5] Generating .env with random passwords..."
  INDEXER_PASS=$(python3 -c "import secrets; print(secrets.token_urlsafe(16))")
  API_PASS=$(python3 -c "import secrets; print(secrets.token_urlsafe(16))")
  DASHBOARD_PASS=$(python3 -c "import secrets; print(secrets.token_urlsafe(16))")

  cat > .env << ENVEOF
WAZUH_VERSION=${WAZUH_VERSION}
WAZUH_IMAGE_VERSION=${WAZUH_VERSION}
WAZUH_REGISTRY=docker.io
IMAGE_TAG=${WAZUH_VERSION}

INDEXER_PASSWORD=${INDEXER_PASS}
API_USERNAME=wazuh-wui
API_PASSWORD=${API_PASS}
DASHBOARD_PASSWORD=${DASHBOARD_PASS}
ENVEOF
  echo "  .env created with secure passwords"
  echo "  INDEXER_PASSWORD: ${INDEXER_PASS}"
  echo "  API_PASSWORD: ${API_PASS}"
  echo "  DASHBOARD_PASSWORD: ${DASHBOARD_PASS}"
else
  echo "[1/5] .env exists, sourcing..."
  source .env
fi

source .env

# ---- Directories ----
echo "[2/5] Creating directories..."
mkdir -p .secrets/{root-ca,wazuh_manager,wazuh_indexer,wazuh_dashboard}/certs
mkdir -p config/wazuh_indexer

# ---- Certificates ----
echo "[3/5] Generating certificates..."
if [ ! -f .secrets/root-ca/certs/root-ca.pem ]; then
  curl -sO "${BASE_URL}/wazuh-certs-tool.sh"
  bash wazuh-certs-tool.sh -A
  cp wazuh-certificates/root-ca* .secrets/root-ca/certs/
  cp wazuh-certificates/wazuh.manager* .secrets/wazuh_manager/certs/
  cp wazuh-certificates/wazuh.indexer* .secrets/wazuh_indexer/certs/
  cp wazuh-certificates/admin* .secrets/wazuh_indexer/certs/
  cp wazuh-certificates/wazuh.dashboard* .secrets/wazuh_dashboard/certs/
  chmod 600 .secrets/*/certs/*key*
  rm -rf wazuh-certificates wazuh-certs-tool.sh
  echo "  Certificates created and deployed"
else
  echo "  Certificates already exist, skipping"
fi

# ---- Password hashes ----
echo "[4/5] Generating password hashes..."

gen_hash() {
  python3 -c "
import bcrypt, sys
pw = sys.argv[1].encode()
h = bcrypt.hashpw(pw, bcrypt.gensalt(12)).decode()
print(h.replace('\$2b\$', '\$2a\$'))
" "$1"
}

ADMIN_HASH=$(gen_hash "$INDEXER_PASSWORD")
KIBA_HASH=$(gen_hash "$DASHBOARD_PASSWORD")

cat > config/wazuh_indexer/internal_users.yml << IUEOF
---
_meta:
  type: "internalusers"
  config_version: 2

admin:
  hash: "${ADMIN_HASH}"
  reserved: true
  backend_roles:
  - "admin"
  description: "Admin user"

kibanaserver:
  hash: "${KIBA_HASH}"
  reserved: true
  description: "Dashboard internal user"
IUEOF
echo "  internal_users.yml generated with secure hashes"

# ---- Dashboard API config ----
echo "[5/5] Generating dashboard API config..."

cat > .secrets/wazuh.yml << WAZUHEOF
hosts:
  - 0000000000000:
      url: "https://localhost"
      port: 55000
      username: wazuh-wui
      password: "${API_PASSWORD}"
      run_as: false
enrollment.dns: ""
WAZUHEOF
echo "  .secrets/wazuh.yml generated"

# ---- Summary ----
echo ""
echo "=== Setup Complete ==="
echo "Run: docker compose up -d"
echo "Dashboard: http://<HOST_IP>:5601"
echo "Login: admin / <INDEXER_PASSWORD in .env>"
echo ""
echo "⚠️  SAVE these passwords (in .env):"
grep -E "^INDEXER_PASSWORD|^API_PASSWORD|^DASHBOARD_PASSWORD" .env
