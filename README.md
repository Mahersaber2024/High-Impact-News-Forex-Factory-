# ForexFactory Flask API + Telegram Bot

This project provides:

- Flask API for ForexFactory economic calendar data
- Optional Telegram bot
- Optional public URL support for MetaTrader 5 or external clients

## Files

- `flask_server.py` → Flask API
- `telegram_bot.py` → Optional Telegram bot
- `forexFactoryScrapper.py` → Scraper logic
- `requirements.txt` → Python dependencies
- `install.sh` → Interactive installer
- `.env` → Runtime configuration

## Quick Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh)
```

## Install Options

The installer asks:

- Flask only
- Flask + Telegram bot
- Telegram bot token
- Flask port
- Whether a temporary public URL is needed

## Local API Endpoints

- `/api/forex/today`
- `/api/forex/tomorrow`
- `/api/forex/weekly`

Example:

```bash
curl http://127.0.0.1:45869/api/forex/today
```

## MetaTrader 5

In MT5, set:

```mql5
input string NewsURL = "http://YOUR_SERVER_IP:45869";
```

If you use a domain:

```mql5
input string NewsURL = "https://news.example.com";
```

Then the expert will request:

```text
/api/forex/today
```

## Temporary Public URL

If selected during install, Cloudflare Tunnel can be used:

```bash
cloudflared tunnel --url http://127.0.0.1:45869
```

This gives a temporary public HTTPS URL.

## Domain Setup

If you want a domain instead of raw server IP:

1. Point your domain or subdomain A record to your server IP.
2. Install Nginx.
3. Reverse proxy the domain to Flask on port 45869.
4. Install SSL certificate with Certbot.

## Nginx Example

```nginx
server {
    server_name news.example.com;

    location / {
        proxy_pass http://127.0.0.1:45869;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## SSL Certificate with Certbot

Install:

```bash
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx
```

Then:

```bash
sudo certbot --nginx -d news.example.com
```

After that your API will be available at:

```text
https://news.example.com/api/forex/today
```

## Services

Systemd services created by installer:

- `flask.service`
- `telegram-bot.service` (only if enabled)

Check status:

```bash
sudo systemctl status flask.service
sudo systemctl status telegram-bot.service
```