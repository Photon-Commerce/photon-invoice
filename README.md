<div align="center">
  <img src="https://images.squarespace-cdn.com/content/v1/607861b10c0e3b4816f56581/3eea3ca7-58ca-402d-9edf-b8e9e72eca3c/lightning.png?format=300w" alt="Photon Commerce">

  <h1>INVOICE</h1>
  <p><strong>Extract structured data from invoices with 99%+ accuracy</strong></p>
  <p><strong>Powered by [Photon Commerce](https://www.photoncommerce.com) — Managed AI Agents with Managed Agents verification</strong></p>

  <p>
    <a href="https://www.photoncommerce.com"><img src="https://img.shields.io/badge/SOC%202-Compliant-blue?style=for-the-badge" alt="SOC 2"></a>
    &nbsp;&nbsp;
    <a href="https://www.photoncommerce.com"><img src="https://img.shields.io/badge/GDPR-Attested-blue?style=for-the-badge" alt="GDPR"></a>
    &nbsp;&nbsp;
    <a href="https://www.photoncommerce.com/pricing"><img src="https://img.shields.io/badge/Accuracy-99%25%2B-00C853?style=for-the-badge" alt="Accuracy"></a>
    &nbsp;&nbsp;
    <a href="https://www.photoncommerce.com/platform"><img src="https://img.shields.io/badge/Languages-25%2B-FF6D00?style=for-the-badge" alt="Languages"></a>
  </p>

  [Website](https://www.photoncommerce.com) &nbsp;·&nbsp; [API Docs](https://apidocs.photoncommerce.com) &nbsp;·&nbsp; [Pricing](https://www.photoncommerce.com/pricing) &nbsp;·&nbsp; [Free Trial](https://app.photoncommerce.com)
</div>

---

## Overview

This repository contains ready-to-run code samples for extracting structured data from invoices using the **Photon PRO API**.

Submit any invoice — PDF, image, Word, HTML, or email — and receive a structured JSON response with 100+ fields, verified to 99%+ accuracy by Photon's Managed Agents network of 2,300+ expert reviewers across 7+ countries.

---

## Extracted Fields

| Category | Fields |
|----------|--------|
| **Amounts** | Balance due, total, subtotal, tax, discounts, currency |
| **Vendor** | Name, address, phone, email, tax ID |
| **Bill To** | Name, address, phone, email, tax ID |
| **Metadata** | Invoice number, date, due date, PO number |
| **Line Items** | Description, quantity, unit price, amount, SKU, GL code |
| **Payment** | Payment terms, bank details, IBAN, routing number |

100+ standardised fields · 25+ document languages · Handwriting, stamps, barcodes, and tables supported

---

## Quick Start

```python
import requests

HEADERS = {
    "CLIENT-ID":     "YOUR_CLIENT_ID",
    "AUTHORIZATION": "apikey YOUR_USERNAME:YOUR_API_KEY",
    "PASSWORD":      "YOUR_PASSWORD",
    "SECRET-KEY":    "YOUR_SECRET_KEY",
}

# Step 1 — Submit
response = requests.post(
    "https://sandbox-api.photoncommerce.com/api/pro",
    headers=HEADERS,
    params={"doctype": "invoice"},
    files={"pdf": open("invoice.pdf", "rb")},
)
photon_key = response.json()["photon_key"]

# Step 2 — Retrieve
result = requests.get(
    "https://sandbox-api.photoncommerce.com/api/v4/json",
    headers=HEADERS,
    params={"photon_key": photon_key},
).json()["data"]

print(result["Vendor_Name"])    # Acme Supplies
print(result["Invoice_Number"]) # INV-2024-00842
print(result["Total"])          # 4750.00
print(result["Currency_Code"])  # USD
```

[Get your free sandbox credentials →](https://sandbox-api.photoncommerce.com/api/v4/register)

---

## Code Examples

| Language | File | Library |
|----------|------|---------|
| ![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white) | [extract_invoice.py](extract_invoice.py) | requests |
| ![JavaScript](https://img.shields.io/badge/Node.js-339933?style=flat-square&logo=nodedotjs&logoColor=white) | [extract_invoice.js](extract_invoice.js) | fetch + form-data |


Every example supports both **local file upload** and **URL-based submission**, plus optional webhook callbacks.

---

## How It Works

```
Invoice In (PDF / Image / Word / HTML / Email)
    ↓
Photon Engine  —  AI + OCR + NLP
    ↓
Managed Agents QA  —  2,300+ expert reviewers
    ↓
Structured JSON Out  —  100+ verified fields
```

### Submission

```
POST /api/pro?doctype=invoice
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `doctype` | string | `invoice` |
| `url` | string | URL of a publicly accessible document (alternative to file upload) |
| `webhook_url` | string | Receive a callback when extraction is complete |
| `auth_token` | string | Token to verify the webhook callback |
| `ID` | string | Your own reference ID for this submission |
| `subaccount` | string | Route to a subaccount |
| `page_start` | integer | First page to process (multi-page PDFs) |
| `page_end` | integer | Last page to process (multi-page PDFs) |

### Retrieval

```
GET /api/v4/json?photon_key=YOUR_PHOTON_KEY
```

Or pass `webhook_url` at submission and Photon will POST the result to your endpoint when ready.

---

## Processing Times

| Account Type | Turnaround |
|-------------|------------|
| Trial | Up to 24 hours (Managed Agents included) |
| Production | 5 minutes to 24 hours (Managed Agents included) |
| AI Extraction | Seconds (contact [support@photoncommerce.com](mailto:support@photoncommerce.com) to activate) |

> **AI Extraction:** Once activated, submit to `/api/v4` instead of `/api/pro` for near-instant results.

---

## Authentication

All requests require four headers:

```
CLIENT-ID:     your-client-id
AUTHORIZATION: apikey your-username:your-api-key
PASSWORD:      your-password
SECRET-KEY:    your-secret-key
```

Get credentials: [Register a free sandbox account](https://sandbox-api.photoncommerce.com/api/v4/register) (20 free calls, no credit card required) or sign up at [app.photoncommerce.com](https://app.photoncommerce.com).

---

## Sample Response

```json
{
  "data": {
    "Balance_Due": 22001.38,
    "Total": 22001.38,
    "Subtotal": 22001.38,
    "Shipping": 0,
    "Tax": 0,
    "Tip": 0,
    "Cashback": 0,
    "Discount": 0,
    "Document_Type": "Invoice",
    "Invoice_Number": "2/02/2021",
    "Check_Number": "",
    "PO_Number": "",
    "Date": "2021-02-03",
    "Created": "2022-01-06 07:40:15",
    "Order_Date": "",
    "Due_Date": "2021-02-10",
    "Ship_Date": "",
    "Delivery_Date": "",
    "Service_Start_Date": "",
    "Service_End_Date": "",
    "Category": "Office Supplies & Software",
    "Currency_Code": "USD",
    "Payment_Terms": "",
    "Account_Number": "",
    "Bill_To_Name": "MOBILE REALITY sp. z o. o",
    "Bill_To_Recipient": "",
    "Bill_To_Address": "03-901 Warszawa, Poland",
    "Bill_To_Address_Line": "03-901 Warszawa, Poland",
    "Bill_To_City": "",
    "Bill_To_State": "",
    "Bill_To_Zipcode": "",
    "Bill_To_Vat_Number": "",
    "Bill_To_Email": "",
    "Card_Number": "",
    "Payment_Display_Name": "",
    "Payment_Type": "",
    "Phone_Number": "",
    "Vat_Number": "7010559296",
    "Vendor_Name": "TUNEGO, INC.",
    "Vendor_Raw_Name": "Mobile Reality",
    "Vendor_Recipient": "",
    "Vendor_Email": "biuro@mobilereality.pl",
    "Vendor_Address": "32505 Anthem Village Drive, Suite E283, Henderson, NV 89052",
    "Vendor_Address_Line": "32505 Anthem Village Drive",
    "Vendor_City": "Henderson",
    "Vendor_State": "NV",
    "Vendor_Zipcode": "89052",
    "Vendor_Country": "United States",
    "Vendor_Type": "",
    "Vendor_Phone": "",
    "Vendor_Fax": "",
    "Vendor_Website": "",
    "Vendor_ABN_Number": "",
    "Vendor_Bank_Name": "",
    "Vendor_Bank_Number": "084009519",
    "Vendor_Bank_Swift": "CMFGUS33",
    "Vendor_IBAN": "",
    "Vendor_Account_Number": "9600000000220961",
    "Remit_To_Name": "TUNEGO, INC.",
    "Remit_To_Address": "",
    "All_Email_Addresses": "biuro@mobilereality.pl",
    "Ship_To_Name": "TUNEGO, INC",
    "Ship_To_Address": "",
    "Carrier": "",
    "Tracking_Number": "",
    "Pages": 1,
    "Is_Duplicate": 0,
    "Notes": "\"odwrotne obciążenie",
    "Tax_Lines": [],
    "Line_Items": [
      {
        "Line": 1,
        "SKU": "",
        "Date": "",
        "Order": 0,
        "Reference": "",
        "Description": "TuneGO 2.0] React.JS frontend development\nN/A\nservices",
        "QTY": 160,
        "Unit": "hrs",
        "Tax": 0,
        "Tax_Rate": 0,
        "Type": "service",
        "Price": 42.5,
        "Discount": 0,
        "Amount": 6800
      },
      {
        "Line": 2,
        "SKU": "",
        "Date": "",
        "Order": 1,
        "Reference": "",
        "Description": "TuneGO 2.0] React Native mobile development\nN/A\nservices",
        "QTY": 146.25,
        "Unit": "hrs",
        "Tax": 0,
        "Tax_Rate": 0,
        "Type": "service",
        "Price": 42.5,
        "Discount": 0,
        "Amount": 6215.63
      },
      {
        "Line": 3,
        "SKU": "",
        "Date": "",
        "Order": 2,
        "Reference": "",
        "Description": "TuneGO 2.0] Node.JS back-end development\nN/A\n TuneGO 2.0] UX/UI/graphics design support\nN/A",
        "QTY": 205.5,
        "Unit": "hrs",
        "Tax": 0,
        "Tax_Rate": 0,
        "Type": "service",
        "Price": 42.5,
        "Discount": 0,
        "Amount": 8733.75
      },
      {
        "Line": 4,
        "SKU": "",
        "Date": "",
        "Order": 4,
        "Reference": "",
        "Description": "[TuneGO 2.0] UX/UI/graphics design support",
        "QTY": 9,
        "Unit": "",
        "Tax": 0,
        "Tax_Rate": 0,
        "Type": "service",
        "Price": 28,
        "Discount": 0,
        "Amount": 252
      }
    ],
    "Raw_Text": "Invoice No. 2/02/2021\nIssue date: Warszawa, 2021-02-03\nData wykonania usługi: 2021-02-03\n\tMobile Reality\nDue date: 2021-02-10\nPayment type: Transfer\n\nSeller\t\t\t\t\t\t\tBuyer\nMOBILE REALITY sp. z o. o.\t\t\t\t\tTUNEGO, INC.\nAl. Ks. J. Poniatowskiego 1/K4\t\t\t\t32505 Anthem Village Drive, Suite E283\n03-901 Warszawa, Poland\t\t\t\t\tHenderson, NV 89052\nVAT ID 7010559296\t\t\t\t\tUnited States\nbiuro@mobilereality.pl\t\t\t\t\tFile Number: 6094078\nAccount's owner : Mobile Reality Sp. z o.o.\nTransferWise\n19 W 24th Street\nNew York 10010 United States\nWire/ACH: 084009519\nAccount number: 9600000000220961\nSWIFT : CMFGUS33\n\nNo. Item\t\t\t\t\t\tQty\tUnit net\tTotal net VAT % VAT amount Total gross\n\tprice\n1\t[TuneGO 2.0] React.JS frontend development\t160 hrs\t42.50\t6,800.00\tN/A\t0.00\t6,800.00\nservices\n2\t[TuneGO 2.0] React Native mobile development\t146.25 hrs\t42.50\t6,215.63\tN/A\t0.00\t6,215.63\nservices\n3 [TuneGO 2.0] Node.JS back-end development\t205.5 hrs\t42.50\t8,733.75\tN/A\t0.00\t8,733.75\n4 [TuneGO 2.0] UX/UI/graphics design support\t9 hrs\t28.00\t252.00\tN/A\t0.00\t252.00\n\tTax rate\t22,001.38\tN/A\t0.00\t22,001.38\n\tTotal\t22,001.38\t\t0.00\t22,001.38\n\tTotal net price\tUSD 22,001.38\n\tVAT amount\tUSD 0.00\n\tTotal gross price\tUSD 22,001.38\n\nNotes:\t\t\"odwrotne obciążenie\"\nTuneGO 2.0: development period 18.01-29.01.2021\n\nTotal due\tUSD 22,001.38\nIn words: twenty two thousand and one USD thirty eight cents\n\n\tSeller's signature\n\tMateusz Sadowski\n\nPage 1 of 1\t\t\t\t\t\t\t\t\t\t\t\t\tgenerated in Fakturownia.pl",
    "Reference_Number": "",
    "Fraud_Score": 5,
    "Risk_Score": 5,
    "Anomaly_Score": 5,
    "doc_path": "data/johndoe@abc.com/2026-01-05/23-40-12-067728_02022021__TuneGO_20.pdf",
    "photon_key": "data/johndoe@abc.com/2026-01-05/23-40-12-067728_02022021__TuneGO_20.json"
  },
  "message": "success",
  "status": "success"
}
```


---

## Links

| | |
|-|-|
| **API Docs** | [apidocs.photoncommerce.com](https://apidocs.photoncommerce.com) |
| **Free Trial** | [app.photoncommerce.com](https://app.photoncommerce.com) |
| **Pricing** | [photoncommerce.com/pricing](https://www.photoncommerce.com/pricing) |
| **Support** | [support@photoncommerce.com](mailto:support@photoncommerce.com) |
| **Enterprise** | [developers@photoncommerce.com](mailto:developers@photoncommerce.com) |
