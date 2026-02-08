---
name: spark-invoice
emoji: 📄
description: Send daily retail credit invoice PDFs from Spark to WhatsApp
requires:
  bins:
    - bash
---

# Spark Invoice Automation

Send retail credit invoices from the Spark petrol pump system to WhatsApp.

## When to Use

Use this skill when the user asks to:
- Send invoices / invoice reports
- Send yesterday's credit sales
- Send pump invoices
- Check credit sales and send reports

## How to Execute

**IMPORTANT**: Simply run this script. Do NOT try to make API calls yourself.

```bash
/Users/dejain/.openclaw/scripts/send-daily-invoices.sh
```

The script will:
1. Fetch yesterday's retail credit sales from Spark API
2. Generate PDF invoices using Chrome headless
3. Send each invoice to WhatsApp (+919964445556)
4. Output progress and confirmation

## Example User Requests

- "Send yesterday's invoices"
- "Send pump invoices" 
- "Send credit sales reports"
- "Send invoice reports to WhatsApp"

## Expected Output

The script outputs:
```
📅 Processing invoices for: 2026-02-07
🔍 Fetching stores with credit sales...
📦 Found 5 stores with sales
  Processing: Store Name (₹5619.49)
  ✅ Sent: Store Name
...
✅ All invoices processed for 2026-02-07
```

## After Running

Tell the user:
- How many invoices were sent
- Which stores received invoices
- Confirm they should check WhatsApp

## Notes

- Script is pre-configured with customer ID and WhatsApp number
- Runs automatically via cron at 8 AM daily
- Can be triggered manually anytime via this skill
