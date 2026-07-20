/**
 * Extract structured data from invoices using the Photon Commerce API.
 *
 * Submits an invoice (PDF, image, Word, HTML, or email) and returns 100+
 * structured fields including vendor, line items, amounts, PO numbers,
 * due dates, GL codes, payment terms, and bank details.
 * 25+ languages supported; handwriting, stamps, and tables handled.
 *
 * Processing times (Managed Agents):
 *   Trial accounts:  up to 24 hours
 *   Production:      5 minutes to 24 hours
 *
 * AI extraction (seconds, no Managed Agents):
 *   Contact support@photoncommerce.com to activate.
 *   Once active, submit to /api/v4 instead of /api/pro.
 *
 * Docs:    https://apidocs.photoncommerce.com
 * Sandbox: https://sandbox-api.photoncommerce.com/api/v4/register (20 free calls)
 */

const fs = require("fs");
const FormData = require("form-data");

// Credentials — all four headers are required.
// Get yours from the dashboard at app.photoncommerce.com
const CLIENT_ID  = "YOUR_CLIENT_ID";
const USERNAME   = "YOUR_USERNAME";
const API_KEY    = "YOUR_API_KEY";
const PASSWORD   = "YOUR_PASSWORD";
const SECRET_KEY = "YOUR_SECRET_KEY";

// Sandbox: https://sandbox-api.photoncommerce.com  (20 free calls, no card needed)
// Production: https://api.photoncommerce.com
const BASE_URL = "https://sandbox-api.photoncommerce.com";

const HEADERS = {
  "CLIENT-ID":     CLIENT_ID,
  "AUTHORIZATION": `apikey ${USERNAME}:${API_KEY}`,
  "PASSWORD":      PASSWORD,
  "SECRET-KEY":    SECRET_KEY,
};

/**
 * Submit an invoice for extraction. Returns the photon_key for result retrieval.
 * Supply either filePath (local file) or url (publicly accessible document URL).
 */
async function submitInvoice({ filePath, url, webhookUrl, authToken, id, subaccount, pageStart, pageEnd } = {}) {
  if (!filePath && !url) throw new Error("Provide either filePath or url.");

  const params = new URLSearchParams({ doctype: "invoice" });
  if (url)        params.set("url", url);
  if (webhookUrl) params.set("webhook_url", webhookUrl);
  if (authToken)  params.set("auth_token", authToken);
  if (id)         params.set("ID", id);
  if (subaccount) params.set("subaccount", subaccount);
  if (pageStart != null) params.set("page_start", pageStart);
  if (pageEnd   != null) params.set("page_end", pageEnd);

  let body, extraHeaders;
  if (filePath) {
    const form = new FormData();
    form.append("pdf", fs.createReadStream(filePath));
    body = form;
    extraHeaders = form.getHeaders();
  }

  // For AI extraction (seconds), replace /api/pro with /api/v4 — contact support@photoncommerce.com to activate.
  const response = await fetch(`${BASE_URL}/api/pro?${params}`, {
    method: "POST",
    headers: { ...HEADERS, ...extraHeaders },
    body,
  });

  if (!response.ok) throw new Error(`Submit failed: ${response.status} ${await response.text()}`);
  const data = await response.json();
  return data.photon_key;
}

/** Retrieve the extracted JSON for a submitted invoice. */
async function fetchResult(photonKey) {
  const response = await fetch(`${BASE_URL}/api/v4/json?photon_key=${photonKey}`, {
    headers: HEADERS,
  });
  if (!response.ok) throw new Error(`Fetch failed: ${response.status}`);
  const data = await response.json();
  return data.data ?? {};
}

/** Poll until the extraction is complete and return the result. */
async function waitForResult(photonKey, { pollInterval = 20000, timeout = 3600000 } = {}) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const result = await fetchResult(photonKey);
    const status = result.Status;
    if (status && status !== "pending" && status !== "processing") return result;
    console.log(`  Status: ${status ?? "pending"} — retrying in ${pollInterval / 1000}s...`);
    await new Promise((r) => setTimeout(r, pollInterval));
  }
  throw new Error(`Extraction not complete after ${timeout / 1000}s`);
}

(async () => {
  // --- Option A: submit from a local file ---
  const photonKey = await submitInvoice({ filePath: "invoice.pdf" });

  // --- Option B: submit via a publicly accessible URL ---
  // const photonKey = await submitInvoice({ url: "https://example.com/invoice.pdf" });

  console.log(`Submitted. photon_key: ${photonKey}`);
  console.log("Waiting for extraction to complete...");

  // Poll until ready (or pass webhookUrl to submitInvoice to receive a callback instead)
  const result = await waitForResult(photonKey);

  console.log("\n--- Invoice Data ---");
  console.log("Vendor:       ", result.Vendor_Name);
  console.log("Invoice No:   ", result.Invoice_Number);
  console.log("Invoice Date: ", result.Date);
  console.log("Due Date:     ", result.Due_Date);
  console.log("PO Number:    ", result.PO_Number);
  console.log("Subtotal:     ", result.Subtotal);
  console.log("Tax:          ", result.Tax);
  console.log("Total:        ", result.Total, result.Currency_Code);
  console.log("Payment Terms:", result.Payment_Terms);

  console.log("\n--- Line Items ---");
  for (const item of result.Line_Items ?? []) {
    console.log(`  Line ${item.Line}: ${item.Description} — Qty ${item.QTY} x ${item.Price} = ${item.Amount}`);
  }
})();
