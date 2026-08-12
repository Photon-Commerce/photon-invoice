<?php
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
 * Requires: guzzlehttp/guzzle (composer require guzzlehttp/guzzle)
 *
 * Docs:    https://apidocs.photoncommerce.com
 * Sandbox: https://sandbox-api.photoncommerce.com/api/v4/register (20 free calls)
 */

require 'vendor/autoload.php';

use GuzzleHttp\Client;

// Credentials — all four headers are required.
// Get yours from the dashboard at app.photoncommerce.com
define('CLIENT_ID',  'YOUR_CLIENT_ID');
define('USERNAME',   'YOUR_USERNAME');
define('API_KEY',    'YOUR_API_KEY');
define('PASSWORD',   'YOUR_PASSWORD');
define('SECRET_KEY', 'YOUR_SECRET_KEY');

// Sandbox: https://sandbox-api.photoncommerce.com  (20 free calls, no card needed)
// Production: https://api.photoncommerce.com
define('BASE_URL', 'https://sandbox-api.photoncommerce.com');

$client = new Client([
    'base_uri' => BASE_URL,
    'headers'  => [
        'CLIENT-ID'     => CLIENT_ID,
        'AUTHORIZATION' => 'apikey ' . USERNAME . ':' . API_KEY,
        'PASSWORD'      => PASSWORD,
        'SECRET-KEY'    => SECRET_KEY,
    ],
]);

/**
 * Submit an invoice for extraction. Returns the photon_key for result retrieval.
 * Supply either $filePath (local file) or $url (publicly accessible document URL).
 */
function submitInvoice(
    Client $client,
    string $filePath = null,
    string $url = null,
    string $webhookUrl = null,
    string $authToken = null,
    string $id = null,
    string $subaccount = null,
    int    $pageStart = null,
    int    $pageEnd = null
): string {
    if (!$filePath && !$url) {
        throw new InvalidArgumentException('Provide either filePath or url.');
    }

    $query = ['doctype' => 'invoice'];
    if ($url)        $query['url']         = $url;
    if ($webhookUrl) $query['webhook_url'] = $webhookUrl;
    if ($authToken)  $query['auth_token']  = $authToken;
    if ($id)         $query['ID']          = $id;
    if ($subaccount) $query['subaccount']  = $subaccount;
    if ($pageStart !== null) $query['page_start'] = $pageStart;
    if ($pageEnd   !== null) $query['page_end']   = $pageEnd;

    $options = ['query' => $query];

    if ($filePath) {
        $options['multipart'] = [
            ['name' => 'pdf', 'contents' => fopen($filePath, 'r'), 'filename' => basename($filePath)],
        ];
    }

    // For AI extraction (seconds), replace /api/pro with /api/v4 — contact support@photoncommerce.com to activate.
    $response = $client->post('/api/pro', $options);
    $data = json_decode($response->getBody(), true);
    return $data['photon_key'];
}

/** Retrieve the extracted JSON for a submitted invoice. */
function fetchResult(Client $client, string $photonKey): array
{
    $response = $client->get('/api/v4/json', ['query' => ['photon_key' => $photonKey]]);
    $data = json_decode($response->getBody(), true);
    return $data['data'] ?? [];
}

/** Poll until the extraction is complete and return the result. */
function waitForResult(Client $client, string $photonKey, int $pollInterval = 20, int $timeout = 3600): array
{
    $deadline = time() + $timeout;
    while (time() < $deadline) {
        $result = fetchResult($client, $photonKey);
        $status = $result['Status'] ?? null;
        if ($status && $status !== 'pending' && $status !== 'processing') {
            return $result;
        }
        echo "  Status: " . ($status ?? 'pending') . " — retrying in {$pollInterval}s...\n";
        sleep($pollInterval);
    }
    throw new RuntimeException("Extraction not complete after {$timeout}s");
}

// --- Option A: submit from a local file ---
$photonKey = submitInvoice($client, filePath: 'invoice.pdf');

// --- Option B: submit via a publicly accessible URL ---
// $photonKey = submitInvoice($client, url: 'https://example.com/invoice.pdf');

echo "Submitted. photon_key: $photonKey\n";
echo "Waiting for extraction to complete...\n";

// Poll until ready (or pass webhookUrl to submitInvoice to receive a callback instead)
$result = waitForResult($client, $photonKey);

echo "\n--- Invoice Data ---\n";
echo "Vendor:        " . ($result['Vendor_Name']    ?? '') . "\n";
echo "Invoice No:    " . ($result['Invoice_Number'] ?? '') . "\n";
echo "Invoice Date:  " . ($result['Date']           ?? '') . "\n";
echo "Due Date:      " . ($result['Due_Date']        ?? '') . "\n";
echo "PO Number:     " . ($result['PO_Number']       ?? '') . "\n";
echo "Subtotal:      " . ($result['Subtotal']        ?? '') . "\n";
echo "Tax:           " . ($result['Tax']             ?? '') . "\n";
echo "Total:         " . ($result['Total']           ?? '') . ' ' . ($result['Currency_Code'] ?? '') . "\n";
echo "Payment Terms: " . ($result['Payment_Terms']   ?? '') . "\n";

echo "\n--- Line Items ---\n";
foreach ($result['Line_Items'] ?? [] as $item) {
    echo "  Line {$item['Line']}: {$item['Description']} — Qty {$item['QTY']} x {$item['Price']} = {$item['Amount']}\n";
}
