# Spark OpenClaw Skills

OpenClaw AI automation skills for Spark petrol pump management system.

## Skills

### spark-invoice
Automatically sends daily retail credit invoice PDFs to WhatsApp.

- **Trigger**: "Send yesterday's invoices" or similar
- **Schedule**: Daily at 8 AM IST via cron
- **Target**: +919964445556

## Scripts

### send-daily-invoices.sh
Shell script that fetches invoices from Spark API and sends via WhatsApp.

## Installation

1. Copy skills to OpenClaw skills directory:
```bash
cp -r skills/* ~/.openclaw/skills/
```

2. Copy scripts:
```bash
cp scripts/* ~/.openclaw/scripts/
chmod +x ~/.openclaw/scripts/*.sh
```

3. Set up cron (optional - for scheduled runs):
```bash
crontab -e
# Add: 0 8 * * * ~/.openclaw/scripts/send-daily-invoices.sh >> ~/.openclaw/logs/invoice-cron.log 2>&1
```

## Configuration

Edit `scripts/send-daily-invoices.sh` to update:
- `CUSTOMER_ID` - Your Spark customer ID
- `WHATSAPP_TO` - Target WhatsApp number
- `API_BASE` - Spark API URL

## Requirements

- OpenClaw with WhatsApp linked
- Google Chrome (for PDF generation)
- curl, jq
