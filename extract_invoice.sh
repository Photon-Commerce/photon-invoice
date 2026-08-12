#!/bin/bash
# Extract structured data from invoices using the Photon Commerce API.
#
# Submits an invoice (PDF, image, Word, HTML, or email) and returns 100+
# structured fields including vendor, line items, amounts, PO numbers,
# due dates, GL codes, payment terms, and bank details.
# 25+ languages supported; handwriting, stamps, and tables handled.
#
# Processing times (Managed Agents):
#   Trial accounts:  up to 24 hours
#   Production:      5 minutes to 24 hours
#
# AI extraction (seconds, no Managed Agents):
#   Contact support@photoncommerce.com to activate.
#   Once active, submit to /api/v4 instead of /api/pro.
#
# Docs:    https://apidocs.photoncommerce.com
# Sandbox: https://sandbox-api.photoncommerce.com/api/v4/register (20 free calls)

CLIENT_ID="YOUR_CLIENT_ID"
USERNAME="YOUR_USERNAME"
API_KEY="YOUR_API_KEY"
PASSWORD="YOUR_PASSWORD"
SECRET_KEY="YOUR_SECRET_KEY"

# Sandbox: https://sandbox-api.photoncommerce.com  (20 free calls, no card needed)
# Production: https://api.photoncommerce.com
BASE_URL="https://sandbox-api.photoncommerce.com"

# --- Option A: submit from a local file ---
# For AI extraction (seconds), replace /api/pro with /api/v4 — contact support@photoncommerce.com to activate.
RESPONSE=$(curl -s -X POST "$BASE_URL/api/pro?doctype=invoice" \
  -H "CLIENT-ID: $CLIENT_ID" \
  -H "AUTHORIZATION: apikey $USERNAME:$API_KEY" \
  -H "PASSWORD: $PASSWORD" \
  -H "SECRET-KEY: $SECRET_KEY" \
  -F "pdf=@invoice.pdf")

# --- Option B: submit via a publicly accessible URL ---
# RESPONSE=$(curl -s -X POST "$BASE_URL/api/pro?doctype=invoice&url=https://example.com/invoice.pdf" \
#   -H "CLIENT-ID: $CLIENT_ID" \
#   -H "AUTHORIZATION: apikey $USERNAME:$API_KEY" \
#   -H "PASSWORD: $PASSWORD" \
#   -H "SECRET-KEY: $SECRET_KEY")

# Optional parameters (append to the query string as needed):
#   &webhook_url=https://your-server.com/webhook
#   &auth_token=YOUR_TOKEN
#   &ID=YOUR_CUSTOM_ID
#   &subaccount=SUBACCOUNT_NAME
#   &page_start=1&page_end=3

PHOTON_KEY=$(echo "$RESPONSE" | grep -o '"photon_key":"[^"]*"' | cut -d'"' -f4)
echo "Submitted. photon_key: $PHOTON_KEY"
echo "Waiting for extraction to complete..."

# Poll until ready (or use webhook_url above to receive a callback instead)
POLL_INTERVAL=20
while true; do
  RESULT=$(curl -s "$BASE_URL/api/v4/json?photon_key=$PHOTON_KEY" \
    -H "CLIENT-ID: $CLIENT_ID" \
    -H "AUTHORIZATION: apikey $USERNAME:$API_KEY" \
    -H "PASSWORD: $PASSWORD" \
    -H "SECRET-KEY: $SECRET_KEY")

  STATUS=$(echo "$RESULT" | grep -o '"Status":"[^"]*"' | cut -d'"' -f4)
  if [ "$STATUS" != "pending" ] && [ "$STATUS" != "processing" ] && [ -n "$STATUS" ]; then
    break
  fi
  echo "  Status: ${STATUS:-pending} — retrying in ${POLL_INTERVAL}s..."
  sleep $POLL_INTERVAL
done

echo ""
echo "--- Invoice Data ---"
echo "$RESULT" | python3 -c "
import sys, json
data = json.load(sys.stdin).get('data', {})
print('Vendor:       ', data.get('Vendor_Name'))
print('Invoice No:   ', data.get('Invoice_Number'))
print('Invoice Date: ', data.get('Date'))
print('Due Date:     ', data.get('Due_Date'))
print('PO Number:    ', data.get('PO_Number'))
print('Subtotal:     ', data.get('Subtotal'))
print('Tax:          ', data.get('Tax'))
print('Total:        ', data.get('Total'), data.get('Currency_Code'))
print('Payment Terms:', data.get('Payment_Terms'))
print()
print('--- Line Items ---')
for item in data.get('Line_Items', []):
    print(f\"  Line {item.get('Line')}: {item.get('Description')} — Qty {item.get('QTY')} x {item.get('Price')} = {item.get('Amount')}\")
"
