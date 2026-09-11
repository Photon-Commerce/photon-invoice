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
// Docs:    https://apidocs.photoncommerce.com
// Sandbox: https://sandbox-api.photoncommerce.com/api/v4/register (20 free calls)

package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"time"
)

const (
	clientID  = "YOUR_CLIENT_ID"
	username  = "YOUR_USERNAME"
	apiKey    = "YOUR_API_KEY"
	password  = "YOUR_PASSWORD"
	secretKey = "YOUR_SECRET_KEY"

	// Sandbox: https://sandbox-api.photoncommerce.com  (20 free calls, no card needed)
	// Production: https://api.photoncommerce.com
	baseURL = "https://sandbox-api.photoncommerce.com"
)

func addAuthHeaders(req *http.Request) {
	req.Header.Set("CLIENT-ID", clientID)
	req.Header.Set("AUTHORIZATION", fmt.Sprintf("apikey %s:%s", username, apiKey))
	req.Header.Set("PASSWORD", password)
	req.Header.Set("SECRET-KEY", secretKey)
}

type SubmitOptions struct {
	FilePath   string
	URL        string
	WebhookURL string
	AuthToken  string
	ID         string
	Subaccount string
	PageStart  int
	PageEnd    int
}

// submitInvoice uploads an invoice and returns the photon_key for result retrieval.
// Supply either FilePath (local file) or URL (publicly accessible document URL).
func submitInvoice(opts SubmitOptions) (string, error) {
	if opts.FilePath == "" && opts.URL == "" {
		return "", fmt.Errorf("provide either FilePath or URL")
	}

	params := url.Values{"doctype": {"invoice"}}
	if opts.URL != ""        { params.Set("url", opts.URL) }
	if opts.WebhookURL != "" { params.Set("webhook_url", opts.WebhookURL) }
	if opts.AuthToken != ""  { params.Set("auth_token", opts.AuthToken) }
	if opts.ID != ""         { params.Set("ID", opts.ID) }
	if opts.Subaccount != "" { params.Set("subaccount", opts.Subaccount) }
	if opts.PageStart > 0    { params.Set("page_start", fmt.Sprint(opts.PageStart)) }
	if opts.PageEnd > 0      { params.Set("page_end", fmt.Sprint(opts.PageEnd)) }

	// For AI extraction (seconds), replace /api/pro with /api/v4 — contact support@photoncommerce.com to activate.
	endpoint := fmt.Sprintf("%s/api/pro?%s", baseURL, params.Encode())

	var req *http.Request
	if opts.FilePath != "" {
		var buf bytes.Buffer
		writer := multipart.NewWriter(&buf)
		file, err := os.Open(opts.FilePath)
		if err != nil {
			return "", err
		}
		defer file.Close()
		part, err := writer.CreateFormFile("pdf", filepath.Base(opts.FilePath))
		if err != nil {
			return "", err
		}
		if _, err = io.Copy(part, file); err != nil {
			return "", err
		}
		writer.Close()
		req, err = http.NewRequest("POST", endpoint, &buf)
		if err != nil {
			return "", err
		}
		req.Header.Set("Content-Type", writer.FormDataContentType())
	} else {
		var err error
		req, err = http.NewRequest("POST", endpoint, nil)
		if err != nil {
			return "", err
		}
	}

	addAuthHeaders(req)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	var result map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&result)
	photonKey, _ := result["photon_key"].(string)
	return photonKey, nil
}

// fetchResult retrieves the extracted JSON for a submitted invoice.
func fetchResult(photonKey string) (map[string]interface{}, error) {
	req, _ := http.NewRequest("GET", fmt.Sprintf("%s/api/v4/json?photon_key=%s", baseURL, photonKey), nil)
	addAuthHeaders(req)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var body map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&body)
	data, _ := body["data"].(map[string]interface{})
	return data, nil
}

// waitForResult polls until the extraction is complete and returns the result.
func waitForResult(photonKey string, pollInterval, timeout time.Duration) (map[string]interface{}, error) {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		result, err := fetchResult(photonKey)
		if err != nil {
			return nil, err
		}
		status, _ := result["Status"].(string)
		if status != "" && status != "pending" && status != "processing" {
			return result, nil
		}
		if status == "" {
			status = "pending"
		}
		fmt.Printf("  Status: %s — retrying in %s...\n", status, pollInterval)
		time.Sleep(pollInterval)
	}
	return nil, fmt.Errorf("extraction not complete after %s", timeout)
}

func str(m map[string]interface{}, key string) string {
	v, _ := m[key].(string)
	return v
}

func main() {
	// --- Option A: submit from a local file ---
	photonKey, err := submitInvoice(SubmitOptions{FilePath: "invoice.pdf"})

	// --- Option B: submit via a publicly accessible URL ---
	// photonKey, err := submitInvoice(SubmitOptions{URL: "https://example.com/invoice.pdf"})

	if err != nil {
		panic(err)
	}
	fmt.Println("Submitted. photon_key:", photonKey)
	fmt.Println("Waiting for extraction to complete...")

	// Poll until ready (or set WebhookURL in SubmitOptions to receive a callback instead)
	result, err := waitForResult(photonKey, 20*time.Second, time.Hour)
	if err != nil {
		panic(err)
	}

	fmt.Println("\n--- Invoice Data ---")
	fmt.Println("Vendor:       ", str(result, "Vendor_Name"))
	fmt.Println("Invoice No:   ", str(result, "Invoice_Number"))
	fmt.Println("Invoice Date: ", str(result, "Date"))
	fmt.Println("Due Date:     ", str(result, "Due_Date"))
	fmt.Println("PO Number:    ", str(result, "PO_Number"))
	fmt.Println("Subtotal:     ", str(result, "Subtotal"))
	fmt.Println("Tax:          ", str(result, "Tax"))
	fmt.Println("Total:        ", str(result, "Total"), str(result, "Currency_Code"))
	fmt.Println("Payment Terms:", str(result, "Payment_Terms"))

	fmt.Println("\n--- Line Items ---")
	if items, ok := result["Line_Items"].([]interface{}); ok {
		for _, i := range items {
			item, _ := i.(map[string]interface{})
			fmt.Printf("  Line %v: %v — Qty %v x %v = %v\n",
				item["Line"], item["Description"], item["QTY"], item["Price"], item["Amount"])
		}
	}
}
