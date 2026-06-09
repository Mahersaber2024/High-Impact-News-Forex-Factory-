#!/usr/bin/env bash
set -e

APP_DIR="/opt/forexfactory-api"
REPO_URL="https://github.com/Mahersaber2024/High-Impact-News-Forex-Factory-.git"
SERVICE_USER="root"

echo "1) Flask only"
echo "2) Flask + Telegram Bot"
read -p "Choose install mode [1/2]: " INSTALL_MODE

read -p "Enter Flask port [default: 45869]: " FLASK_PORT
FLASK_PORT=${FLASK_PORT:-45869}

read -p "Do you need a public URL now? [y/N]: " NEED_PUBLIC_URL
NEED_PUBLIC_URL=${NEED_PUBLIC_URL:-N}

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
    echo "Git clone failed. Check repository URL."
    exit 1
  }
else
  cd "$APP_DIR"
  git pull || {
    echo "Git pull failed."
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

cat > .env <<EOF
FLASK_HOST=0.0.0.0
FLASK_PORT=$FLASK_PORT
FLASK_DEBUG=false
API_BASE_URL=http://127.0.0.1:$FLASK_PORT/api/forex
RUN_BOT=$RUN_BOT
TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN
ADMIN_CHAT_ID=$ADMIN_CHAT_ID
PUBLIC_BASE_URL=
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

echo "Flask API started on port $FLASK_PORT"

if [[ "$NEED_PUBLIC_URL" =~ ^[Yy]$ ]]; then
  curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb
  dpkg -i /tmp/cloudflared.deb || apt-get install -f -y
  echo "Run this command for a temporary public URL:"
  echo "cloudflared tunnel --url http://127.0.0.1:$FLASK_PORT"
fi

echo "Done."
echo "Check Flask status with: systemctl status flask.service"
echo "Check Bot status with: systemctl status telegram-bot.service"
