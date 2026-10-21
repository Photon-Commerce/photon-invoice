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

require "net/http"
require "uri"
require "json"

# Credentials — all four headers are required.
# Get yours from the dashboard at app.photoncommerce.com
CLIENT_ID  = "YOUR_CLIENT_ID"
USERNAME   = "YOUR_USERNAME"
API_KEY    = "YOUR_API_KEY"
PASSWORD   = "YOUR_PASSWORD"
SECRET_KEY = "YOUR_SECRET_KEY"

# Sandbox: https://sandbox-api.photoncommerce.com  (20 free calls, no card needed)
# Production: https://api.photoncommerce.com
BASE_URL = "https://sandbox-api.photoncommerce.com"

AUTH_HEADERS = {
  "CLIENT-ID"     => CLIENT_ID,
  "AUTHORIZATION" => "apikey #{USERNAME}:#{API_KEY}",
  "PASSWORD"      => PASSWORD,
  "SECRET-KEY"    => SECRET_KEY,
}.freeze

# Submit an invoice for extraction. Returns the photon_key for result retrieval.
# Supply either file_path (local file) or url (publicly accessible document URL).
def submit_invoice(file_path: nil, url: nil, webhook_url: nil, auth_token: nil,
                   id: nil, subaccount: nil, page_start: nil, page_end: nil)
  raise ArgumentError, "Provide either file_path or url." if file_path.nil? && url.nil?

  params = { doctype: "invoice" }
  params[:url]         = url         if url
  params[:webhook_url] = webhook_url if webhook_url
  params[:auth_token]  = auth_token  if auth_token
  params[:ID]          = id          if id
  params[:subaccount]  = subaccount  if subaccount
  params[:page_start]  = page_start  if page_start
  params[:page_end]    = page_end    if page_end

  # For AI extraction (seconds), replace /api/pro with /api/v4 — contact support@photoncommerce.com to activate.
  uri = URI("#{BASE_URL}/api/pro")
  uri.query = URI.encode_www_form(params)

  if file_path
    boundary = "PhotonBoundary#{rand(1_000_000)}"
    body = "--#{boundary}\r\n" \
           "Content-Disposition: form-data; name=\"pdf\"; filename=\"#{File.basename(file_path)}\"\r\n" \
           "Content-Type: application/octet-stream\r\n\r\n" +
           File.binread(file_path) +
           "\r\n--#{boundary}--\r\n"
    headers = AUTH_HEADERS.merge("Content-Type" => "multipart/form-data; boundary=#{boundary}")
    response = Net::HTTP.post(uri, body, headers)
  else
    response = Net::HTTP.post(uri, "", AUTH_HEADERS)
  end

  JSON.parse(response.body)["photon_key"]
end

# Retrieve the extracted JSON for a submitted invoice.
def fetch_result(photon_key)
  uri = URI("#{BASE_URL}/api/v4/json?photon_key=#{photon_key}")
  response = Net::HTTP.get_response(uri, AUTH_HEADERS)
  JSON.parse(response.body)["data"] || {}
end

# Poll until the extraction is complete and return the result.
def wait_for_result(photon_key, poll_interval: 20, timeout: 3600)
  deadline = Time.now + timeout
  while Time.now < deadline
    result = fetch_result(photon_key)
    status = result["Status"]
    return result if status && status != "pending" && status != "processing"
    puts "  Status: #{status || 'pending'} — retrying in #{poll_interval}s..."
    sleep poll_interval
  end
  raise "Extraction not complete after #{timeout}s"
end

# --- Option A: submit from a local file ---
photon_key = submit_invoice(file_path: "invoice.pdf")

# --- Option B: submit via a publicly accessible URL ---
# photon_key = submit_invoice(url: "https://example.com/invoice.pdf")

puts "Submitted. photon_key: #{photon_key}"
puts "Waiting for extraction to complete..."

# Poll until ready (or pass webhook_url to submit_invoice to receive a callback instead)
result = wait_for_result(photon_key)

puts "\n--- Invoice Data ---"
puts "Vendor:        #{result["Vendor_Name"]}"
puts "Invoice No:    #{result["Invoice_Number"]}"
puts "Invoice Date:  #{result["Date"]}"
puts "Due Date:      #{result["Due_Date"]}"
puts "PO Number:     #{result["PO_Number"]}"
puts "Subtotal:      #{result["Subtotal"]}"
puts "Tax:           #{result["Tax"]}"
puts "Total:         #{result["Total"]} #{result["Currency_Code"]}"
puts "Payment Terms: #{result["Payment_Terms"]}"

puts "\n--- Line Items ---"
(result["Line_Items"] || []).each do |item|
  puts "  Line #{item["Line"]}: #{item["Description"]} — Qty #{item["QTY"]} x #{item["Price"]} = #{item["Amount"]}"
end
