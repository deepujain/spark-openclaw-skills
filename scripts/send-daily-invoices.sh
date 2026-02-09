#!/bin/bash
# Daily Invoice Automation Script
# Fetches retail credit invoices from Spark and sends via WhatsApp
# Usage: ./send-daily-invoices.sh [--send]
#   --send    Actually send messages (default: dry run)
# Cron: 0 8 * * * /Users/dejain/.openclaw/scripts/send-daily-invoices.sh --send

set -e

# Parse arguments
SEND_ENABLED=false
if [ "$1" = "--send" ]; then
  SEND_ENABLED=true
fi

# Configuration
CUSTOMER_ID="customer-suryodayaservicestation-001"
FALLBACK_NUMBER="+919964445556"
API_BASE="https://1xaispark.com"

# Store name → WhatsApp group JID mapping
get_whatsapp_group() {
  local store_name="$1"
  case "$store_name" in
    "Adams Furnishers"*)
      echo "120363402548997487@g.us"
      ;;
    "DS Max Properties"*|"DSMAX"*)
      echo "120363400987473286@g.us"
      ;;
    "Veejay Associates"*|"Veejay"*)
      echo "120363417825856535@g.us"
      ;;
    "Vidyan Educational"*|"Sri Ramayogi Educational"*|"SRYET"*)
      echo "120363405195374618@g.us"
      ;;
    "RD Traders"*)
      echo "120363405074946339@g.us"
      ;;
    "Pratham"*)
      echo "120363402348569365@g.us"
      ;;
    "Vak"*)
      echo "120363417950363686@g.us"
      ;;
    "Arihant"*)
      echo "120363419443144512@g.us"
      ;;
    *)
      echo ""  # Unknown store
      ;;
  esac
}

# Calculate yesterday's date
YESTERDAY=$(date -v-1d +%Y-%m-%d)
YESTERDAY_DISPLAY=$(date -v-1d +"%d %b %Y")
echo "📅 Processing invoices for: $YESTERDAY_DISPLAY"

if [ "$SEND_ENABLED" = true ]; then
  echo "📤 Mode: SENDING ENABLED"
else
  echo "🔍 Mode: DRY RUN (use --send to actually send)"
fi

# Get list of stores with sales
echo "🔍 Fetching stores with credit sales..."
STORES_JSON=$(curl -s "${API_BASE}/api/retail-credit-sales/daily-invoices?date=${YESTERDAY}" \
  -H "x-customer-id: ${CUSTOMER_ID}")

# Check if we got valid response
STORE_COUNT=$(echo "$STORES_JSON" | jq -r '.storeCount // 0')

if [ "$STORE_COUNT" -eq 0 ]; then
  echo "ℹ️ No credit sales found for $YESTERDAY"
  if [ "$SEND_ENABLED" = true ]; then
    openclaw message send --channel whatsapp --target "$FALLBACK_NUMBER" --message "📊 No retail credit sales recorded on $YESTERDAY" </dev/null
  fi
  exit 0
fi

echo "📦 Found $STORE_COUNT stores with sales"

# Save stores to temp file to avoid stdin issues with openclaw
STORES_FILE="/tmp/stores-$$.json"
echo "$STORES_JSON" | jq -c '.stores[]' > "$STORES_FILE"

# Chrome path
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Process each store using for loop (avoids stdin conflicts)
while IFS= read -r store <&3; do
  STORE_ID=$(echo "$store" | jq -r '.id')
  STORE_NAME=$(echo "$store" | jq -r '.name')
  TOTAL=$(echo "$store" | jq -r '.totalAmount')
  
  # Get WhatsApp group for this store
  WHATSAPP_TARGET=$(get_whatsapp_group "$STORE_NAME")
  
  if [ -z "$WHATSAPP_TARGET" ]; then
    echo "  ⚠️ No group mapping for: $STORE_NAME → sending to fallback"
    WHATSAPP_TARGET="$FALLBACK_NUMBER"
  fi
  
  echo "  Processing: $STORE_NAME (₹$TOTAL) → $WHATSAPP_TARGET"
  
  # Download invoice HTML
  TEMP_HTML="/tmp/invoice-${STORE_ID}.html"
  TEMP_PDF_SIMPLE="/tmp/invoice-${STORE_ID}.pdf"
  TEMP_PDF="/tmp/Invoice Report - ${STORE_NAME} - ${YESTERDAY_DISPLAY}.pdf"
  
  curl -s "${API_BASE}/api/retail-credit-sales/combined-invoice/pdf?storeId=${STORE_ID}&date=${YESTERDAY}" \
    -H "x-customer-id: ${CUSTOMER_ID}" \
    -o "$TEMP_HTML"
  
  if [ "$SEND_ENABLED" = true ]; then
    if [ -x "$CHROME" ]; then
      # Use Chrome headless to convert HTML to PDF
      "$CHROME" --headless --disable-gpu --print-to-pdf="$TEMP_PDF_SIMPLE" \
        --no-pdf-header-footer --print-to-pdf-no-header \
        "file://$TEMP_HTML" 2>/dev/null
      
      # Rename to proper filename
      mv "$TEMP_PDF_SIMPLE" "$TEMP_PDF"
      
      # Send polite message first
      openclaw message send --channel whatsapp --target "$WHATSAPP_TARGET" \
        --message "Dear ${STORE_NAME},

Please find the invoice report of all credit sales on ${YESTERDAY_DISPLAY}.

Thank you for your business! 🙏" </dev/null
      
      # Then send the PDF with filename as caption
      openclaw message send --channel whatsapp --target "$WHATSAPP_TARGET" \
        --message "📎 Invoice Report - ${STORE_NAME} - ${YESTERDAY_DISPLAY}.pdf" --media "$TEMP_PDF" </dev/null
      
      echo "  ✅ Sent: $STORE_NAME → $WHATSAPP_TARGET"
      rm -f "$TEMP_HTML" "$TEMP_PDF"
    else
      echo "  ⚠️ Chrome not found, sending HTML"
      openclaw message send --channel whatsapp --target "$WHATSAPP_TARGET" \
        --message "Dear ${STORE_NAME},

Please find the invoice report of all credit sales on ${YESTERDAY_DISPLAY}.

Thank you for your business! 🙏" </dev/null
      openclaw message send --channel whatsapp --target "$WHATSAPP_TARGET" \
        --message "📎 Invoice Report - ${STORE_NAME} - ${YESTERDAY_DISPLAY}.html" --media "$TEMP_HTML" </dev/null
      rm -f "$TEMP_HTML"
    fi
  else
    echo "  ⏭️ Skipped (dry run): $STORE_NAME"
    rm -f "$TEMP_HTML"
  fi
done 3< "$STORES_FILE"

# Cleanup
rm -f "$STORES_FILE"

echo "✅ All invoices processed for $YESTERDAY"
