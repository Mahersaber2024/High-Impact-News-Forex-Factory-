#!/usr/bin/env bash
set -e

APP_DIR="/opt/forexfactory-api"
REPO_URL="https://github.com/Mahersaber2024/High-Impact-News-Forex-Factory-.git"
SERVICE_USER="root"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "1) Flask only"
echo "2) Flask + Telegram Bot"
read -p "Choose install mode [1/2]: " INSTALL_MODE

read -p "Enter Flask port [default: 45869]: " FLASK_PORT
FLASK_PORT=${FLASK_PORT:-45869}

read -p "Do you need a temporary public URL now? [y/N]: " NEED_PUBLIC_URL
NEED_PUBLIC_URL=${NEED_PUBLIC_URL:-N}

read -p "Enter domain for HTTPS (press Enter to skip): " DOMAIN_NAME
DOMAIN_NAME=${DOMAIN_NAME:-}

CERTBOT_EMAIL=""
if [ -n "$DOMAIN_NAME" ]; then
  read -p "Enter email for SSL certificate [default: admin@$DOMAIN_NAME]: " CERTBOT_EMAIL
  CERTBOT_EMAIL=${CERTBOT_EMAIL:-admin@$DOMAIN_NAME}
fi

RUN_BOT=false
TELEGRAM_BOT_TOKEN=""
ADMIN_CHAT_ID="0"

if [ "$INSTALL_MODE" = "2" ]; then
  RUN_BOT=true
  read -s -p "Enter Telegram bot token: " TELEGRAM_BOT_TOKEN
  echo
  read -p "Enter Admin chat ID [default: 0]: " ADMIN_CHAT_ID
  ADMIN_CHAT_ID=${ADMIN_CHAT_ID:-0}
fi

export DEBIAN_FRONTEND=noninteractive
unset GIT_ASKPASS
unset SSH_ASKPASS
export GIT_TERMINAL_PROMPT=0

apt update
apt install -y git python3 python3-venv python3-pip curl

if [ ! -d "$APP_DIR/.git" ]; then
  rm -rf "$APP_DIR"
  git clone --depth 1 "$REPO_URL" "$APP_DIR" || {
    echo -e "${RED}Git clone failed. Check repository URL.${NC}"
    exit 1
  }
else
  cd "$APP_DIR"
  git pull || {
    echo -e "${RED}Git pull failed.${NC}"
    exit 1
  }
fi

cd "$APP_DIR"

if [ ! -f requirements.txt ] && [ -f requirements-6.txt ]; then
  cp requirements-6.txt requirements.txt
fi

if [ ! -f flask_server.py ] && [ -f flask_server-3.py ]; then
  cp flask_server-3.py flask_server.py
fi

if [ ! -f telegram_bot.py ] && [ -f telegram_bot-7.py ]; then
  cp telegram_bot-7.py telegram_bot.py
fi

if [ ! -f forexFactoryScrapper.py ] && [ -f forexFactoryScrapper-5.py ]; then
  cp forexFactoryScrapper-5.py forexFactoryScrapper.py
fi

python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

PUBLIC_BASE_URL=""
if [ -n "$DOMAIN_NAME" ]; then
  PUBLIC_BASE_URL="https://$DOMAIN_NAME"
fi

cat > .env <<EOF
FLASK_HOST=0.0.0.0
FLASK_PORT=$FLASK_PORT
FLASK_DEBUG=false
API_BASE_URL=http://127.0.0.1:$FLASK_PORT/api/forex
RUN_BOT=$RUN_BOT
TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN
ADMIN_CHAT_ID=$ADMIN_CHAT_ID
PUBLIC_BASE_URL=$PUBLIC_BASE_URL
EOF

cat > /etc/systemd/system/flask.service <<EOF
[Unit]
Description=ForexFactory Flask API
After=network.target

[Service]
User=$SERVICE_USER
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/.venv/bin/python $APP_DIR/flask_server.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable flask.service
systemctl restart flask.service

if [ "$RUN_BOT" = "true" ]; then
cat > /etc/systemd/system/telegram-bot.service <<EOF
[Unit]
Description=ForexFactory Telegram Bot
After=network.target flask.service

[Service]
User=$SERVICE_USER
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/.venv/bin/python $APP_DIR/telegram_bot.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable telegram-bot.service
systemctl restart telegram-bot.service
fi

if [ -n "$DOMAIN_NAME" ]; then
  apt install -y nginx certbot python3-certbot-nginx

  cat > /etc/nginx/sites-available/forexfactory-api <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;

    location / {
        proxy_pass http://127.0.0.1:$FLASK_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

  ln -sf /etc/nginx/sites-available/forexfactory-api /etc/nginx/sites-enabled/forexfactory-api
  rm -f /etc/nginx/sites-enabled/default
  nginx -t
  systemctl enable nginx
  systemctl restart nginx

  certbot --nginx --non-interactive --agree-tos -m "$CERTBOT_EMAIL" -d "$DOMAIN_NAME" --redirect || true
fi

FLASK_STATUS=$(systemctl is-active flask.service || true)
BOT_STATUS="disabled"

if [ "$RUN_BOT" = "true" ]; then
  BOT_STATUS=$(systemctl is-active telegram-bot.service || true)
fi

PUBLIC_URL="Not created"

if [[ "$NEED_PUBLIC_URL" =~ ^[Yy]$ ]]; then
  curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb
  dpkg -i /tmp/cloudflared.deb >/dev/null 2>&1 || apt-get install -f -y >/dev/null 2>&1

  nohup cloudflared tunnel --url http://127.0.0.1:$FLASK_PORT > /tmp/cloudflared.log 2>&1 &
  sleep 8

  PUBLIC_URL=$(grep -o 'https://[-a-zA-Z0-9.]*trycloudflare.com' /tmp/cloudflared.log | head -n 1)
  if [ -z "$PUBLIC_URL" ]; then
    PUBLIC_URL="Failed to create"
  fi
fi

echo
echo -e "${CYAN}_________________________________${NC}"
echo -e "${CYAN}_________________________________${NC}"

if [ "$FLASK_STATUS" = "active" ]; then
  echo -e "${GREEN}Flask API: ACTIVE${NC}"
else
  echo -e "${RED}Flask API: FAILED${NC}"
fi

if [ "$RUN_BOT" = "true" ]; then
  if [ "$BOT_STATUS" = "active" ]; then
    echo -e "${GREEN}Telegram Bot: ACTIVE${NC}"
  else
    echo -e "${RED}Telegram Bot: FAILED${NC}"
  fi
else
  echo -e "${YELLOW}Telegram Bot: DISABLED${NC}"
fi

echo -e "${GREEN}Local API:${NC} http://127.0.0.1:$FLASK_PORT/api/forex/today"

if [ -n "$DOMAIN_NAME" ]; then
  echo -e "${GREEN}Domain URL:${NC} https://$DOMAIN_NAME/api/forex/today"
fi

echo -e "${GREEN}Temporary Public URL:${NC} $PUBLIC_URL"

echo -e "${CYAN}_________________________________${NC}"
echo -e "${CYAN}_________________________________${NC}"
