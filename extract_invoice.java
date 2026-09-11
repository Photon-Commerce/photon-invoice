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
 * Requires: OkHttp 4.x (https://square.github.io/okhttp/)
 *           org.json (https://mvnrepository.com/artifact/org.json/json)
 *
 * Docs:    https://apidocs.photoncommerce.com
 * Sandbox: https://sandbox-api.photoncommerce.com/api/v4/register (20 free calls)
 */

import okhttp3.*;
import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.IOException;
import java.util.concurrent.TimeUnit;

public class ExtractInvoice {

    // Credentials — all four headers are required.
    // Get yours from the dashboard at app.photoncommerce.com
    private static final String CLIENT_ID  = "YOUR_CLIENT_ID";
    private static final String USERNAME   = "YOUR_USERNAME";
    private static final String API_KEY    = "YOUR_API_KEY";
    private static final String PASSWORD   = "YOUR_PASSWORD";
    private static final String SECRET_KEY = "YOUR_SECRET_KEY";

    // Sandbox: https://sandbox-api.photoncommerce.com  (20 free calls, no card needed)
    // Production: https://api.photoncommerce.com
    private static final String BASE_URL = "https://sandbox-api.photoncommerce.com";

    private static final OkHttpClient client = new OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build();

    private static Request.Builder authBuilder() {
        return new Request.Builder()
                .header("CLIENT-ID", CLIENT_ID)
                .header("AUTHORIZATION", "apikey " + USERNAME + ":" + API_KEY)
                .header("PASSWORD", PASSWORD)
                .header("SECRET-KEY", SECRET_KEY);
    }

    /**
     * Submit an invoice for extraction. Returns the photon_key for result retrieval.
     * Supply either filePath (local file) or url (publicly accessible document URL).
     */
    public static String submitInvoice(
            String filePath, String url,
            String webhookUrl, String authToken,
            String id, String subaccount,
            Integer pageStart, Integer pageEnd) throws IOException {

        if (filePath == null && url == null)
            throw new IllegalArgumentException("Provide either filePath or url.");

        // For AI extraction (seconds), replace /api/pro with /api/v4 — contact support@photoncommerce.com to activate.
        HttpUrl.Builder urlBuilder = HttpUrl.parse(BASE_URL + "/api/pro").newBuilder()
                .addQueryParameter("doctype", "invoice");
        if (url != null)        urlBuilder.addQueryParameter("url", url);
        if (webhookUrl != null) urlBuilder.addQueryParameter("webhook_url", webhookUrl);
        if (authToken != null)  urlBuilder.addQueryParameter("auth_token", authToken);
        if (id != null)         urlBuilder.addQueryParameter("ID", id);
        if (subaccount != null) urlBuilder.addQueryParameter("subaccount", subaccount);
        if (pageStart != null)  urlBuilder.addQueryParameter("page_start", String.valueOf(pageStart));
        if (pageEnd != null)    urlBuilder.addQueryParameter("page_end", String.valueOf(pageEnd));

        RequestBody body;
        if (filePath != null) {
            body = new MultipartBody.Builder().setType(MultipartBody.FORM)
                    .addFormDataPart("pdf", new File(filePath).getName(),
                            RequestBody.create(new File(filePath), MediaType.parse("application/octet-stream")))
                    .build();
        } else {
            body = RequestBody.create(new byte[0]);
        }

        Request request = authBuilder().url(urlBuilder.build()).post(body).build();
        try (Response response = client.newCall(request).execute()) {
            JSONObject json = new JSONObject(response.body().string());
            return json.getString("photon_key");
        }
    }

    /** Retrieve the extracted JSON for a submitted invoice. */
    public static JSONObject fetchResult(String photonKey) throws IOException {
        HttpUrl url = HttpUrl.parse(BASE_URL + "/api/v4/json").newBuilder()
                .addQueryParameter("photon_key", photonKey).build();
        Request request = authBuilder().url(url).get().build();
        try (Response response = client.newCall(request).execute()) {
            JSONObject json = new JSONObject(response.body().string());
            return json.optJSONObject("data");
        }
    }

    /** Poll until the extraction is complete and return the result. */
    public static JSONObject waitForResult(String photonKey, int pollIntervalSec, int timeoutSec)
            throws IOException, InterruptedException {
        long deadline = System.currentTimeMillis() + (long) timeoutSec * 1000;
        while (System.currentTimeMillis() < deadline) {
            JSONObject result = fetchResult(photonKey);
            String status = result != null ? result.optString("Status", "") : "";
            if (!status.isEmpty() && !status.equals("pending") && !status.equals("processing")) {
                return result;
            }
            System.out.println("  Status: " + (status.isEmpty() ? "pending" : status)
                    + " — retrying in " + pollIntervalSec + "s...");
            Thread.sleep(pollIntervalSec * 1000L);
        }
        throw new RuntimeException("Extraction not complete after " + timeoutSec + "s");
    }

    public static void main(String[] args) throws Exception {
        // --- Option A: submit from a local file ---
        String photonKey = submitInvoice("invoice.pdf", null, null, null, null, null, null, null);

        // --- Option B: submit via a publicly accessible URL ---
        // String photonKey = submitInvoice(null, "https://example.com/invoice.pdf", null, null, null, null, null, null);

        System.out.println("Submitted. photon_key: " + photonKey);
        System.out.println("Waiting for extraction to complete...");

        // Poll until ready (or pass webhookUrl to submitInvoice to receive a callback instead)
        JSONObject result = waitForResult(photonKey, 20, 3600);

        System.out.println("\n--- Invoice Data ---");
        System.out.println("Vendor:        " + result.optString("Vendor_Name"));
        System.out.println("Invoice No:    " + result.optString("Invoice_Number"));
        System.out.println("Invoice Date:  " + result.optString("Date"));
        System.out.println("Due Date:      " + result.optString("Due_Date"));
        System.out.println("PO Number:     " + result.optString("PO_Number"));
        System.out.println("Subtotal:      " + result.optString("Subtotal"));
        System.out.println("Tax:           " + result.optString("Tax"));
        System.out.println("Total:         " + result.optString("Total") + " " + result.optString("Currency_Code"));
        System.out.println("Payment Terms: " + result.optString("Payment_Terms"));

        System.out.println("\n--- Line Items ---");
        JSONArray lineItems = result.optJSONArray("Line_Items");
        if (lineItems != null) {
            for (int i = 0; i < lineItems.length(); i++) {
                JSONObject item = lineItems.getJSONObject(i);
                System.out.printf("  Line %s: %s — Qty %s x %s = %s%n",
                        item.opt("Line"), item.opt("Description"),
                        item.opt("QTY"), item.opt("Price"), item.opt("Amount"));
            }
        }
    }
}
