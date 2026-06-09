# ForexFactory Flask API + Telegram Bot

A lightweight Flask API for ForexFactory high-impact news, with optional Telegram bot support and optional domain-based HTTPS access for external clients such as MetaTrader 5.

Sponsor: [@HeySoloATM](https://t.me/HeySoloATM)

## Features

- Flask API for ForexFactory economic calendar data
- Optional Telegram bot
- Public API access through server IP
- Optional domain setup with Nginx reverse proxy
- Optional HTTPS with Let's Encrypt and Certbot
- Interactive installer with systemd service setup

## Files

- `flask_server.py` → Flask API
- `telegram_bot.py` → Optional Telegram bot
- `forexFactoryScrapper.py` → Scraper logic
- `requirements.txt` → Python dependencies
- `install.sh` → Interactive installer
- `.env` → Runtime configuration

## Quick Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Mahersaber2024/High-Impact-News-Forex-Factory-/main/install.sh)
```

## Installer Prompts

The installer asks for:

- Install mode: Flask only or Flask + Telegram Bot
- Flask port
- Optional domain name for HTTPS
- SSL email address if a domain is provided
- Telegram bot token if bot mode is selected
- Telegram admin chat ID

If you press Enter on the domain question, domain setup is skipped.

## API Endpoints

- `/api/forex/today`
- `/api/forex/tomorrow`
- `/api/forex/weekly`

Example:

```bash
curl http://127.0.0.1:45869/api/forex/today
```

## API Access Modes

### Local access

```text
http://127.0.0.1:45869/api/forex/today
```

### Public access by server IP

If Nginx is installed and running on port 80, the API can be accessed from outside the server using:

```text
http://YOUR_SERVER_IP/api/forex/today
```

Example:

```text
http://185.28.119.231/api/forex/today
```

### Public access by domain

If you provide a domain during installation and its DNS points to your server, the installer configures Nginx and tries to obtain an SSL certificate automatically.

Example:

```text
https://news.example.com/api/forex/today
```

## MetaTrader 5

If you are using direct server IP access:

```mql5
input string NewsURL = "http://YOUR_SERVER_IP";
```

If you are using a domain with HTTPS:

```mql5
input string NewsURL = "https://news.example.com";
```

Then your EA can request:

```text
/api/forex/today
```

## Services

The installer creates these systemd services:

- `flask.service`
- `telegram-bot.service` only if bot mode is enabled

Check service status:

```bash
sudo systemctl status flask.service
sudo systemctl status telegram-bot.service
```

Restart services:

```bash
sudo systemctl restart flask.service
sudo systemctl restart telegram-bot.service
```

View logs:

```bash
sudo journalctl -u flask.service -n 100 --no-pager
sudo journalctl -u telegram-bot.service -n 100 --no-pager
```

## Domain Setup Later

If you skip the domain during installation, you can add it later.

### 1. Point DNS to your server

Create an `A` record for your domain or subdomain and point it to your server IP.

Example:

- `news.example.com` → `185.28.119.231`

### 2. Install Nginx and Certbot

```bash
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx
```

### 3. Create Nginx config

Replace `news.example.com` with your real domain and `45869` with your Flask port if different.

```bash
sudo tee /etc/nginx/sites-available/forexfactory-api > /dev/null <<'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name news.example.com;

    location / {
        proxy_pass http://127.0.0.1:45869;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
```

Enable it:

```bash
sudo ln -sf /etc/nginx/sites-available/forexfactory-api /etc/nginx/sites-enabled/forexfactory-api
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

### 4. Get SSL certificate

```bash
sudo certbot --nginx -d news.example.com
```

After successful issuance, your API should be available at:

```text
https://news.example.com/api/forex/today
```

### 5. Optional: update `.env`

If you want to store the public base URL in the app config:

```bash
sudo nano /opt/forexfactory-api/.env
```

Set:

```env
PUBLIC_BASE_URL=https://news.example.com
```

Then restart Flask:

```bash
sudo systemctl restart flask.service
```

## Troubleshooting

### Flask is not starting

Check logs:

```bash
sudo journalctl -u flask.service -n 100 --no-pager
```

### Telegram bot is running but news is not received

Make sure Flask is active first, because the bot depends on the API.

### Domain certificate was not issued

Check these items:

- Domain DNS is pointed to the correct server IP
- Port 80 is open
- Nginx is running
- The domain is reachable from the public internet

Then run Certbot again:

```bash
sudo certbot --nginx -d news.example.com
```

## Notes

- Server IP access works over HTTP on port 80 through Nginx.
- Domain access can work over HTTPS after SSL is issued.
- If you do not need the Telegram bot, choose Flask only during install.
