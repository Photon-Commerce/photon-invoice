// Extract structured data from invoices using the Photon Commerce API.
//
// Submits an invoice (PDF, image, Word, HTML, or email) and returns 100+
// structured fields including vendor, line items, amounts, PO numbers,
// due dates, GL codes, payment terms, and bank details.
// 25+ languages supported; handwriting, stamps, and tables handled.
//
// Processing times (Managed Agents):
//   Trial accounts:  up to 24 hours
//   Production:      5 minutes to 24 hours
//
// AI extraction (seconds, no Managed Agents):
//   Contact support@photoncommerce.com to activate.
//   Once active, submit to /api/v4 instead of /api/pro.
//
// Requires: .NET 6+ (uses System.Net.Http and System.Text.Json)
//
// Docs:    https://apidocs.photoncommerce.com
// Sandbox: https://sandbox-api.photoncommerce.com/api/v4/register (20 free calls)

using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading.Tasks;

// Credentials — all four headers are required.
// Get yours from the dashboard at app.photoncommerce.com
const string ClientId  = "YOUR_CLIENT_ID";
const string Username  = "YOUR_USERNAME";
const string ApiKey    = "YOUR_API_KEY";
const string Password  = "YOUR_PASSWORD";
const string SecretKey = "YOUR_SECRET_KEY";

// Sandbox: https://sandbox-api.photoncommerce.com  (20 free calls, no card needed)
// Production: https://api.photoncommerce.com
const string BaseUrl = "https://sandbox-api.photoncommerce.com";

using var http = new HttpClient();
http.DefaultRequestHeaders.Add("CLIENT-ID", ClientId);
http.DefaultRequestHeaders.Add("AUTHORIZATION", $"apikey {Username}:{ApiKey}");
http.DefaultRequestHeaders.Add("PASSWORD", Password);
http.DefaultRequestHeaders.Add("SECRET-KEY", SecretKey);

/// <summary>
/// Submit an invoice for extraction. Returns the photon_key for result retrieval.
/// Supply either filePath (local file) or url (publicly accessible document URL).
/// </summary>
async Task<string> SubmitInvoice(
    string filePath = null, string url = null,
    string webhookUrl = null, string authToken = null,
    string id = null, string subaccount = null,
    int? pageStart = null, int? pageEnd = null)
{
    if (filePath == null && url == null)
        throw new ArgumentException("Provide either filePath or url.");

    var query = new List<string> { "doctype=invoice" };
    if (url != null)        query.Add($"url={Uri.EscapeDataString(url)}");
    if (webhookUrl != null) query.Add($"webhook_url={Uri.EscapeDataString(webhookUrl)}");
    if (authToken != null)  query.Add($"auth_token={Uri.EscapeDataString(authToken)}");
    if (id != null)         query.Add($"ID={Uri.EscapeDataString(id)}");
    if (subaccount != null) query.Add($"subaccount={Uri.EscapeDataString(subaccount)}");
    if (pageStart != null)  query.Add($"page_start={pageStart}");
    if (pageEnd != null)    query.Add($"page_end={pageEnd}");

    // For AI extraction (seconds), replace /api/pro with /api/v4 — contact support@photoncommerce.com to activate.
    var endpoint = $"{BaseUrl}/api/pro?{string.Join("&", query)}";

    HttpContent content;
    if (filePath != null)
    {
        var form = new MultipartFormDataContent();
        var fileBytes = await File.ReadAllBytesAsync(filePath);
        form.Add(new ByteArrayContent(fileBytes), "pdf", Path.GetFileName(filePath));
        content = form;
    }
    else
    {
        content = new StringContent("");
    }

    var response = await http.PostAsync(endpoint, content);
    response.EnsureSuccessStatusCode();
    var json = await response.Content.ReadFromJsonAsync<JsonElement>();
    return json.GetProperty("photon_key").GetString();
}

/// <summary>Retrieve the extracted JSON for a submitted invoice.</summary>
async Task<JsonElement> FetchResult(string photonKey)
{
    var response = await http.GetAsync($"{BaseUrl}/api/v4/json?photon_key={photonKey}");
    response.EnsureSuccessStatusCode();
    var json = await response.Content.ReadFromJsonAsync<JsonElement>();
    return json.GetProperty("data");
}

/// <summary>Poll until the extraction is complete and return the result.</summary>
async Task<JsonElement> WaitForResult(string photonKey, int pollIntervalSec = 20, int timeoutSec = 3600)
{
    var deadline = DateTime.UtcNow.AddSeconds(timeoutSec);
    while (DateTime.UtcNow < deadline)
    {
        var result = await FetchResult(photonKey);
        var status = result.TryGetProperty("Status", out var s) ? s.GetString() : null;
        if (!string.IsNullOrEmpty(status) && status != "pending" && status != "processing")
            return result;
        Console.WriteLine($"  Status: {status ?? "pending"} — retrying in {pollIntervalSec}s...");
        await Task.Delay(pollIntervalSec * 1000);
    }
    throw new TimeoutException($"Extraction not complete after {timeoutSec}s");
}

string str(JsonElement el, string key) =>
    el.TryGetProperty(key, out var v) ? v.GetString() ?? "" : "";

// --- Option A: submit from a local file ---
var photonKey = await SubmitInvoice(filePath: "invoice.pdf");

// --- Option B: submit via a publicly accessible URL ---
// var photonKey = await SubmitInvoice(url: "https://example.com/invoice.pdf");

Console.WriteLine($"Submitted. photon_key: {photonKey}");
Console.WriteLine("Waiting for extraction to complete...");

// Poll until ready (or pass webhookUrl to SubmitInvoice to receive a callback instead)
var result = await WaitForResult(photonKey);

Console.WriteLine("\n--- Invoice Data ---");
Console.WriteLine($"Vendor:        {str(result, "Vendor_Name")}");
Console.WriteLine($"Invoice No:    {str(result, "Invoice_Number")}");
Console.WriteLine($"Invoice Date:  {str(result, "Date")}");
Console.WriteLine($"Due Date:      {str(result, "Due_Date")}");
Console.WriteLine($"PO Number:     {str(result, "PO_Number")}");
Console.WriteLine($"Subtotal:      {str(result, "Subtotal")}");
Console.WriteLine($"Tax:           {str(result, "Tax")}");
Console.WriteLine($"Total:         {str(result, "Total")} {str(result, "Currency_Code")}");
Console.WriteLine($"Payment Terms: {str(result, "Payment_Terms")}");

Console.WriteLine("\n--- Line Items ---");
if (result.TryGetProperty("Line_Items", out var lineItems))
{
    foreach (var item in lineItems.EnumerateArray())
    {
        Console.WriteLine($"  Line {str(item, "Line")}: {str(item, "Description")} — " +
                          $"Qty {str(item, "QTY")} x {str(item, "Price")} = {str(item, "Amount")}");
    }
}
