#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# UPhone Messenger - Production Deployment Script
# Target: Ubuntu/Debian with MariaDB + Apache2
# ============================================================

APP_NAME="uphone"
DEPLOY_DIR="/opt/${APP_NAME}"
DATA_DIR="/var/lib/${APP_NAME}"
CONF_DIR="/etc/${APP_NAME}"
WEB_DIR="/var/www/${APP_NAME}"
REPO_URL="https://github.com/BlkDem/uphone.git"
DB_NAME="uphone"
DB_USER="uphone"
GO_VERSION="1.24.4"
FLUTTER_CHANNEL="stable"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ---- Pre-flight checks ----
[[ $EUID -eq 0 ]] || error "Run as root: sudo bash deploy.sh"

DETECTED_IP=$(hostname -I | awk '{print $1}')
log "Detected server IP: ${DETECTED_IP}"

# ---- 1. System packages ----
log "Installing system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
    git curl wget unzip \
    mariadb-server mariadb-client \
    apache2 libapache2-mod-proxy-html libproxy-mod-proxy-wstunnel \
    build-essential

# Enable Apache modules
a2enmod proxy proxy_http proxy_wstunnel rewrite headers -qq

# ---- 2. Go ----
if ! command -v go &>/dev/null || [[ "$(go version 2>/dev/null | grep -oP 'go\d+\.\d+')" != "go${GO_VERSION%.*}" ]]; then
    log "Installing Go ${GO_VERSION}..."
    cd /tmp
    wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O go.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf go.tar.gz
    rm go.tar.gz
    export PATH="/usr/local/go/bin:$PATH"
    echo 'export PATH="/usr/local/go/bin:$PATH"' > /etc/profile.d/golang.sh
fi
log "Go: $(go version)"

# ---- 3. Flutter ----
if ! command -v flutter &>/dev/null; then
    log "Installing Flutter..."
    cd /opt
    git clone -b ${FLUTTER_CHANNEL} --depth 1 https://github.com/flutter/flutter.git flutter-sdk
    export PATH="/opt/flutter-sdk/bin:$PATH"
    echo 'export PATH="/opt/flutter-sdk/bin:$PATH"' > /etc/profile.d/flutter.sh
    flutter precache --web
else
    log "Flutter already installed"
fi
export PATH="/opt/flutter-sdk/bin:$PATH"

# ---- 4. MariaDB ----
log "Configuring MariaDB..."
systemctl enable --now mariadb

# Generate random password if not set
DB_PASS="${DB_PASSWORD:-$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)}"

mysql -u root <<-EOSQL
    CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
    CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
    GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';
    GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
    FLUSH PRIVILEGES;
EOSQL
log "Database ready. User: ${DB_USER}, Pass: ${DB_PASS}"

# ---- 5. Deploy application ----
log "Deploying application..."
mkdir -p "${DEPLOY_DIR}" "${DATA_DIR}/uploads" "${CONF_DIR}" "${WEB_DIR}"

if [[ -d "${DEPLOY_DIR}/.git" ]]; then
    log "Pulling latest changes..."
    cd "${DEPLOY_DIR}"
    git fetch origin master
    git reset --hard origin/master
else
    log "Cloning repository..."
    rm -rf "${DEPLOY_DIR}"
    git clone --depth 1 -b master "${REPO_URL}" "${DEPLOY_DIR}"
fi

# ---- 6. Build Go server ----
log "Building Go server..."
cd "${DEPLOY_DIR}/server"
export PATH="/usr/local/go/bin:$PATH"
CGO_ENABLED=0 go build -o uphone-server ./cmd/server/

# ---- 7. Build Flutter web client ----
log "Building Flutter web client..."
cd "${DEPLOY_DIR}/client"
export PATH="/opt/flutter-sdk/bin:$PATH"
flutter pub get
flutter build web \
    --dart-define=API_BASE_URL=http://${DEPLOYED_IP:-$DETECTED_IP} \
    --dart-define=WS_URL=ws://${DEPLOYED_IP:-$DETECTED_IP}/ws

# Copy web build to Apache document root
rm -rf "${WEB_DIR:?}"/*
cp -r build/web/* "${WEB_DIR}/"

# ---- 8. Configuration ----
JWT_SECRET=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 64)

if [[ ! -f "${CONF_DIR}/uphone.env" ]]; then
    log "Creating environment file..."
    cat > "${CONF_DIR}/uphone.env" <<EOF
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASS}
DB_NAME=${DB_NAME}
SERVER_PORT=8080
UPLOAD_DIR=${DATA_DIR}/uploads
UPLOAD_BASE_URL=http://${DEPLOYED_IP:-$DETECTED_IP}
JWT_SECRET=${JWT_SECRET}
GOOGLE_CLIENT_ID=
EOF
    chmod 600 "${CONF_DIR}/uphone.env"
    log "Config written to ${CONF_DIR}/uphone.env"
    log ">>> EDIT THIS FILE to set GOOGLE_CLIENT_ID and verify settings <<<"
else
    warn "Config file exists at ${CONF_DIR}/uphone.env, skipping creation"
fi

# ---- 9. Systemd service ----
log "Installing systemd service..."
cat > /etc/systemd/system/${APP_NAME}.service <<EOF
[Unit]
Description=UPhone Messenger Server
After=network.target mariadb.service
Wants=mariadb.service

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=${DEPLOY_DIR}/server
EnvironmentFile=${CONF_DIR}/uphone.env
ExecStart=${DEPLOY_DIR}/server/uphone-server
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now ${APP_NAME}

# ---- 10. Apache virtual host ----
log "Configuring Apache2..."
cat > /etc/apache2/sites-available/${APP_NAME}.conf <<EOF
<VirtualHost *:80>
    ServerName ${DEPLOYED_IP:-$DETECTED_IP}

    DocumentRoot ${WEB_DIR}

    <Directory ${WEB_DIR}>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted

        RewriteEngine On
        RewriteBase /
        RewriteRule ^index\.html\$ - [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.html [L]
    </Directory>

    ProxyPreserveHost On
    ProxyRequests Off

    ProxyPass /api/ http://127.0.0.1:8080/api/
    ProxyPassReverse /api/ http://127.0.0.1:8080/api/

    ProxyPass /uploads/ http://127.0.0.1:8080/uploads/
    ProxyPassReverse /uploads/ http://127.0.0.1:8080/uploads/

    RewriteCond %{HTTP:Upgrade} =websocket [NC]
    RewriteCond %{HTTP:Connection} =upgrade [NC]
    RewriteRule ^/ws(.*) ws://127.0.0.1:8080/ws\$1 [P,L]

    ProxyPass /ws http://127.0.0.1:8080/ws
    ProxyPassReverse /ws http://127.0.0.1:8080/ws

    ErrorLog \${APACHE_LOG_DIR}/uphone_error.log
    CustomLog \${APACHE_LOG_DIR}/uphone_access.log combined
</VirtualHost>
EOF

a2dissite 000-default.conf -qq 2>/dev/null || true
a2ensite ${APP_NAME}.conf -qq
systemctl reload apache2

# ---- 11. Firewall ----
if command -v ufw &>/dev/null; then
    log "Opening firewall ports..."
    ufw allow 80/tcp comment "HTTP" >/dev/null 2>&1 || true
    ufw allow 443/tcp comment "HTTPS" >/dev/null 2>&1 || true
fi

# ---- Done ----
echo ""
echo "============================================"
echo -e "${GREEN}  UPhone deployed successfully!${NC}"
echo "============================================"
echo ""
echo "  Web client:  http://${DEPLOYED_IP:-$DETECTED_IP}"
echo "  API:         http://${DEPLOYED_IP:-$DETECTED_IP}/api/v1"
echo "  WebSocket:   ws://${DEPLOYED_IP:-$DETECTED_IP}/ws"
echo ""
echo "  Config:      ${CONF_DIR}/uphone.env"
echo "  Logs:        journalctl -u ${APP_NAME} -f"
echo "  Apache logs: /var/log/apache2/uphone_*.log"
echo ""
echo "  DB user:     ${DB_USER}"
echo "  DB pass:     ${DB_PASS}"
echo ""
echo "  To update: cd ${DEPLOY_DIR} && git pull && sudo bash $0"
echo "============================================"
