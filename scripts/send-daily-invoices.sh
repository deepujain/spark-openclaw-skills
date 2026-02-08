#!/bin/bash
# Daily Invoice Automation Script
# Fetches retail credit invoices from Spark and sends via WhatsApp
# Run via: crontab -e -> 0 8 * * * /Users/dejain/.openclaw/scripts/send-daily-invoices.sh

set -e

# Configuration - UPDATE THESE VALUES
CUSTOMER_ID="customer-suryodayaservicestation-001"
WHATSAPP_TO="+919964445556"
API_BASE="https://1xaispark.com"

# Calculate yesterday's date
YESTERDAY=$(date -v-1d +%Y-%m-%d)
echo "📅 Processing invoices for: $YESTERDAY"

# Get list of stores with sales
echo "🔍 Fetching stores with credit sales..."
STORES_JSON=$(curl -s "${API_BASE}/api/retail-credit-sales/daily-invoices?date=${YESTERDAY}" \
  -H "x-customer-id: ${CUSTOMER_ID}")

# Check if we got valid response
STORE_COUNT=$(echo "$STORES_JSON" | jq -r '.storeCount // 0')

if [ "$STORE_COUNT" -eq 0 ]; then
  echo "ℹ️ No credit sales found for $YESTERDAY"
  # Optionally notify via WhatsApp
  openclaw message send --channel whatsapp --target "$WHATSAPP_TO" --message "📊 No retail credit sales recorded on $YESTERDAY"
  exit 0
fi

echo "📦 Found $STORE_COUNT stores with sales"

# Process each store
echo "$STORES_JSON" | jq -c '.stores[]' | while read -r store; do
  STORE_ID=$(echo "$store" | jq -r '.id')
  STORE_NAME=$(echo "$store" | jq -r '.name')
  TOTAL=$(echo "$store" | jq -r '.totalAmount')
  
  echo "  Processing: $STORE_NAME (₹$TOTAL)"
  
  # Download invoice HTML
  TEMP_HTML="/tmp/invoice-${STORE_ID}.html"
  TEMP_PDF="/tmp/invoice-${STORE_NAME}-${YESTERDAY}.pdf"
  
  curl -s "${API_BASE}/api/retail-credit-sales/combined-invoice/pdf?storeId=${STORE_ID}&date=${YESTERDAY}" \
    -H "x-customer-id: ${CUSTOMER_ID}" \
    -o "$TEMP_HTML"
  
  # Convert HTML to PDF using Chrome headless
  CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  
  if [ -x "$CHROME" ]; then
    # Use Chrome headless to convert HTML to PDF
    "$CHROME" --headless --disable-gpu --print-to-pdf="$TEMP_PDF" \
      --no-pdf-header-footer --print-to-pdf-no-header \
      "file://$TEMP_HTML" 2>/dev/null
    
    # Send via OpenClaw WhatsApp
    openclaw message send --channel whatsapp --target "$WHATSAPP_TO" \
      --message "📄 Invoice Report: ${STORE_NAME} - ${YESTERDAY}" \
      --media "$TEMP_PDF"
    
    echo "  ✅ Sent: $STORE_NAME"
    rm -f "$TEMP_HTML" "$TEMP_PDF"
  else
    echo "  ⚠️ Chrome not found, sending HTML"
    openclaw message send --channel whatsapp --target "$WHATSAPP_TO" \
      --message "📄 Invoice Report: ${STORE_NAME} - ${YESTERDAY}" \
      --media "$TEMP_HTML"
    rm -f "$TEMP_HTML"
  fi
done

echo "✅ All invoices processed for $YESTERDAY"
