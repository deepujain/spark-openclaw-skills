#!/bin/bash
# Daily Ledger Automation Script
# Sends monthly ledger statements (1st of month to today) to WhatsApp groups
# Run via: crontab -e -> 5 8 * * * /Users/dejain/.openclaw/scripts/send-daily-ledger.sh

set -e

# Configuration
CUSTOMER_ID="customer-suryodayaservicestation-001"
FALLBACK_GROUP="120363302492976094@g.us"  # Suryodaya Petrol Pump internal group
API_BASE="https://1xaispark.com"

# Store name → WhatsApp group JID mapping (same as invoices)
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

# Calculate date range: 1st of current month to today
START_DATE=$(date +%Y-%m-01)
END_DATE=$(date +%Y-%m-%d)
START_DISPLAY=$(date -j -f "%Y-%m-%d" "$START_DATE" +"%d %b %Y")
END_DISPLAY=$(date +"%d %b %Y")

echo "📅 Processing ledger statements: $START_DISPLAY to $END_DISPLAY"

# Get list of stores with ledger data
echo "🔍 Fetching stores with ledger data..."
STORES_JSON=$(curl -s "${API_BASE}/api/stores/ledger?startDate=${START_DATE}&endDate=${END_DATE}" \
  -H "x-customer-id: ${CUSTOMER_ID}")

# Filter stores with BOTH "credit" AND "external" labels AND outstanding > 0
# Save to temp file for processing
STORES_FILE="/tmp/ledger-stores-$$.json"
echo "$STORES_JSON" | jq -c '.[] | select((.labels | map(.name | ascii_downcase) | (contains(["credit"]) and contains(["external"]))) and .outstanding > 0)' > "$STORES_FILE"

STORE_COUNT=$(wc -l < "$STORES_FILE" | tr -d ' ')

if [ "$STORE_COUNT" -eq 0 ]; then
  echo "ℹ️ No stores with credit/external labels found"
  rm -f "$STORES_FILE"
  exit 0
fi

echo "📦 Found $STORE_COUNT stores with credit/external labels"

# Chrome path
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Process each store
while IFS= read -r store <&3; do
  STORE_ID=$(echo "$store" | jq -r '.id')
  STORE_NAME=$(echo "$store" | jq -r '.name')
  OUTSTANDING=$(echo "$store" | jq -r '.outstanding')
  
  # Get WhatsApp group for this store
  WHATSAPP_TARGET=$(get_whatsapp_group "$STORE_NAME")
  
  if [ -z "$WHATSAPP_TARGET" ]; then
    echo "  ⚠️ No group mapping for: $STORE_NAME → sending to internal group"
    WHATSAPP_TARGET="$FALLBACK_GROUP"
  fi
  
  echo "  Processing: $STORE_NAME (Outstanding: ₹$OUTSTANDING) → $WHATSAPP_TARGET"
  
  # Download ledger HTML
  TEMP_HTML="/tmp/ledger-${STORE_ID}.html"
  TEMP_PDF_SIMPLE="/tmp/ledger-${STORE_ID}.pdf"
  TEMP_PDF="/tmp/Ledger Statement - ${STORE_NAME} - ${END_DISPLAY}.pdf"
  
  curl -s "${API_BASE}/api/stores/ledger/${STORE_ID}/pdf?startDate=${START_DATE}&endDate=${END_DATE}" \
    -H "x-customer-id: ${CUSTOMER_ID}" \
    -o "$TEMP_HTML"
  
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

Please find the ledger statement from ${START_DISPLAY} to ${END_DISPLAY}.

Thank you for your business! 🙏" </dev/null
    
    # Then send the PDF with filename as caption
    openclaw message send --channel whatsapp --target "$WHATSAPP_TARGET" \
      --message "📎 Ledger Statement - ${STORE_NAME} - ${END_DISPLAY}.pdf" --media "$TEMP_PDF" </dev/null
    
    echo "  ✅ Sent: $STORE_NAME → $WHATSAPP_TARGET"
    rm -f "$TEMP_HTML" "$TEMP_PDF"
  else
    echo "  ⚠️ Chrome not found, sending HTML"
    openclaw message send --channel whatsapp --target "$WHATSAPP_TARGET" \
      --message "Dear ${STORE_NAME},

Please find the ledger statement from ${START_DISPLAY} to ${END_DISPLAY}.

Thank you for your business! 🙏" </dev/null
    openclaw message send --channel whatsapp --target "$WHATSAPP_TARGET" \
      --message "📎 Ledger Statement - ${STORE_NAME} - ${END_DISPLAY}.html" --media "$TEMP_HTML" </dev/null
    rm -f "$TEMP_HTML"
  fi
done 3< "$STORES_FILE"

# Cleanup
rm -f "$STORES_FILE"

echo "✅ All ledger statements processed for $START_DISPLAY to $END_DISPLAY"
