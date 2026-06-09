#!/usr/bin/env bash
set -e

APP_DIR="/opt/forexfactory-api"
REPO_URL="https://github.com/YOUR_USERNAME/YOUR_REPO.git"

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
  read -p "Enter Telegram bot token: " TELEGRAM_BOT_TOKEN
  read -p "Enter Admin chat ID [default: 0]: " ADMIN_CHAT_ID
  ADMIN_CHAT_ID=${ADMIN_CHAT_ID:-0}
fi

sudo apt update
sudo apt install -y git python3 python3-venv python3-pip curl

if [ ! -d "$APP_DIR" ]; then
  sudo git clone "$REPO_URL" "$APP_DIR"
else
  cd "$APP_DIR"
  sudo git pull
fi

sudo chown -R $USER:$USER "$APP_DIR"
cd "$APP_DIR"

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

cat > flask.service <<EOF
[Unit]
Description=ForexFactory Flask API
After=network.target

[Service]
User=$USER
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/.venv/bin/python flask_server.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo mv flask.service /etc/systemd/system/flask.service
sudo systemctl daemon-reload
sudo systemctl enable flask.service
sudo systemctl restart flask.service

if [ "$RUN_BOT" = "true" ]; then
cat > telegram-bot.service <<EOF
[Unit]
Description=ForexFactory Telegram Bot
After=network.target flask.service

[Service]
User=$USER
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/.venv/bin/python telegram_bot.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo mv telegram-bot.service /etc/systemd/system/telegram-bot.service
sudo systemctl daemon-reload
sudo systemctl enable telegram-bot.service
sudo systemctl restart telegram-bot.service
fi

echo "Flask API started on port $FLASK_PORT"

if [[ "$NEED_PUBLIC_URL" =~ ^[Yy]$ ]]; then
  curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb
  sudo dpkg -i cloudflared.deb || sudo apt-get install -f -y
  echo "Run this command for a temporary public URL:"
  echo "cloudflared tunnel --url http://127.0.0.1:$FLASK_PORT"
fi
