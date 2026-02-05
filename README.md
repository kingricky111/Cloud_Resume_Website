
````markdown
# Cloud Resume Challenge – Azure Edition

Live site: **https://www.rickycloudresume.com**

This project is my implementation of the **Cloud Resume Challenge** on **Microsoft Azure**.  
It’s a fully automated, Terraform-driven, cloud-hosted resume site with a serverless backend and CI/CD pipelines.

I currently work as an **Associate Systems Engineer** in a hybrid on-prem/cloud environment and am transitioning into Cloud / DevOps roles.

---

## ✨ Features

- **Static resume website** built from a Figma developer portfolio template  
- **Custom domain** – `www.rickycloudresume.com`  
- **HTTPS everywhere** using Azure Front Door managed certificates  
- **Visitor counter** implemented with:
  - Azure Functions (Python)
  - Azure Table Storage
  - JavaScript frontend
- **Infrastructure as Code** using Terraform:
  - Resource Group
  - Storage Accounts (static site + function + data)
  - Azure Front Door (profile, endpoint, origin, routes, custom domain)
  - Function App (Linux, Python)
  - Log Analytics + Application Insights
- **CI/CD with GitHub Actions**:
  - Frontend: deploy static site to Azure Storage `$web`
  - Backend: package and deploy function app code

---

## 🧱 Architecture

**High-level flow:**

1. User opens `https://www.rickycloudresume.com`.
2. DNS (Cloudflare) routes `www` to the Azure Front Door endpoint.
3. Azure Front Door forwards traffic to the static website in Azure Storage.
4. The page loads and a small JavaScript snippet calls:
   `https://cloudresume-crc-api.azurewebsites.net/api/visits`
5. Azure Functions (Python) reads/increments a record in **Azure Table Storage** and returns the updated count.
6. The visitor count is rendered in the navbar as **Visitors: N**.

**Main Azure components:**

- **Azure Storage (static website)** – hosts `index.html`, `styles.css`, assets
- **Azure Front Door** – global entry point, HTTPS offload, routing
- **Azure Storage (data)** – holds `visitors` table
- **Azure Storage (function)** – backing storage for the Function App
- **Azure Functions (Python)** – serverless API for the visitor counter
- **Log Analytics + Application Insights** – logging, metrics, tracing
- **Cloudflare DNS** – public DNS + CNAME to the Front Door endpoint

---

## 🧰 Tech Stack

- **Cloud:** Azure
- **IaC:** Terraform
- **Frontend:** HTML, CSS, JavaScript
- **DNS:** Cloudflare
- **Edge / CDN:** Azure Front Door
- **Backend:** Azure Functions (Python)
- **Data:** Azure Table Storage
- **Monitoring:** Azure Monitor, Application Insights, Log Analytics
- **CI/CD:** GitHub Actions

---

## 📁 Repository Structure

```text
.
├── site/                       # Static front-end site
│   ├── index.html
│   ├── styles.css
│   └── assets/
│
├── ├── backend/
│   └── crc-api/
│       ├── host.json
│       ├── requirements.txt
│       ├── visits/                   # Azure Functions implementation (Project 1)
│       │   ├── __init__.py
│       │   └── function.json
│       └── api-container/            # Containerized API (Project 2)
│           ├── app.py
│           └── requirements.txt
│
├── Infrastructure/
│   └── docker/                       # Docker + Compose (Project 2)
│       ├── dockerfile
│       ├── docker-compose.yml
│       └── README.md
│
├── terraform-azure-CRC/        # Terraform IaC for all Azure infrastructure
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
└── .github/
    └── workflows/
        ├── deploy.yml          # Deploy static site to Azure Storage
        └── backend-deploy.yml  # Deploy Azure Function from backend/crc-api
````
---

## Extensions Beyond the Base Challenge

After completing the Cloud Resume Challenge using Azure-native services (Azure Functions + Front Door + Terraform), I extended the same backend functionality into additional deployment models:

## Extensions Beyond the Base Challenge

After completing the Cloud Resume Challenge using Azure-native services (Azure Functions + Front Door + Terraform), I extended the project in two directions:

- **Project 2 (Docker):** A containerized FastAPI version of the `/visits` API that connects to the same Azure Table Storage, enabling portability, local development, and future orchestration.

- **Project 3 (Monitoring & Observability):** Production-style monitoring and alerting added to the live Azure deployment using Azure Monitor, Application Insights, and Log Analytics. This work focuses on operating and observing an existing cloud application rather than introducing new infrastructure.

These extensions live alongside the Azure Functions implementation — they do not replace it.

### Planned work
- **Kubernetes:** Deploy the containerized API to Kubernetes to explore orchestration, scaling, and service management.
---

## 🌐 Frontend

The frontend is a single-page static site in `site/`, built from a modern developer portfolio Figma template and customized with my own:

* Summary & headline (Associate Systems Engineer → Cloud / DevOps)
* Skills and technology stack
* Projects (including this Cloud Resume)
* Contact section and social links (GitHub, LinkedIn, resume PDF)

### Visitor Counter (JavaScript)

The visitor counter shows up in the navbar as:

```html
<p class="visit-counter">
  Visitors: <span id="visit-count">...</span>
</p>
```

The script at the bottom of `index.html` calls the Azure Function:

```html
<script>
  (async () => {
    const el = document.getElementById("visit-count");
    if (!el) return;

    try {
      const response = await fetch("https://cloudresume-crc-api.azurewebsites.net/api/visits");
      if (!response.ok) throw new Error("Network error");

      const data = await response.json();
      el.textContent = data.count ?? data.Count ?? "—";
    } catch (err) {
      console.error("Failed to load visit count", err);
      el.textContent = "—";
    }
  })();
</script>
```

---

## 🧮 Backend – Azure Function + Table Storage

The backend is a simple **HTTP-triggered** Azure Function in `backend/crc-api/visits`.

Every time the JS loads the page, it hits `/api/visits`:

* Reads a single entity from the `visitors` table (`PartitionKey="counter"`, `RowKey="site"`)
* If it exists, increments the `Count` property
* If it doesn’t exist, creates it with `Count = 1`
* Returns `{ "count": <currentCount> }` as JSON

Key parts of `__init__.py`:

```python
import logging
import os
import json

import azure.functions as func
from azure.data.tables import TableServiceClient
from azure.core.exceptions import ResourceNotFoundError


def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("Processing visit count request")

    conn_str = os.getenv("TABLES_CONNECTION_STRING")
    table_name = os.getenv("TABLES_TABLE_NAME")

    service = TableServiceClient.from_connection_string(conn_str)
    table_client = service.get_table_client(table_name)

    partition_key = "counter"
    row_key = "site"

    try:
        entity = table_client.get_entity(partition_key=partition_key, row_key=row_key)
        current_count = int(entity.get("Count", 0))
        new_count = current_count + 1
        entity["Count"] = new_count
        table_client.update_entity(entity)
    except ResourceNotFoundError:
        new_count = 1
        entity = {
            "PartitionKey": partition_key,
            "RowKey": row_key,
            "Count": new_count,
        }
        table_client.create_entity(entity)

    body = json.dumps({"count": new_count})

    return func.HttpResponse(
        body,
        status_code=200,
        mimetype="application/json",
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, OPTIONS",
        },
    )
```

The Function App is configured via Terraform to expose:

* `TABLES_CONNECTION_STRING`
* `TABLES_TABLE_NAME`

as app settings.

---

## ☁️ Infrastructure as Code (Terraform)

All Azure resources are declared in `terraform-azure-CRC/`. Highlights:

* **Resource Group**
* **Static Website Storage Account**

  * Enables `$web` static site hosting
* **Function Host Storage Account**
* **Data Storage Account**

  * Creates `visitors` table
* **Azure Front Door (Standard/Premium)**

  * Profile, endpoint, origin group, origin
  * Routes for:

    * Front Door default hostname
    * `www.rickycloudresume.com` custom domain
* **Custom Domain**

  * `www.rickycloudresume.com` bound to Front Door
  * AFD-managed certificate + DNS validation
* **App Service Plan (Linux, Y1 consumption)**
* **Linux Function App**

  * Python 3.10 stack
  * CORS configured for:

    * `https://www.rickycloudresume.com`
    * Front Door endpoint hostname
* **Log Analytics Workspace + Application Insights**

Terraform outputs expose key values such as:

* Static website primary endpoint
* Front Door endpoint hostname
* Function default hostname

---

## 🔁 CI/CD – GitHub Actions

### Frontend deploy (`.github/workflows/deploy.yml`)

Triggered on pushes to `main` that touch `site/`:

1. Checks out the repo
2. Uses `az storage blob upload-batch` to sync `./site` → `$web` container in the static site Storage Account
3. Connection string is stored as GitHub secret:

   * `AZURE_STORAGE_CONNECTION_STRING`

### Backend deploy (`.github/workflows/backend-deploy.yml`)

Triggered on pushes to `main` that touch `backend/**`:

1. Checks out the repo
2. Installs Python 3.10
3. Installs function dependencies into `backend/crc-api`
4. Zips the function app
5. Deploys it to `cloudresume-crc-api` via `Azure/functions-action@v1` using a publish profile secret:

   * `AZURE_FUNCTIONAPP_PUBLISH_PROFILE`

This gives me continuous deployment for both the **static frontend** and the **serverless backend** from the same repository.

---

## 📊 Monitoring & Observability

This project includes production-style monitoring and alerting to ensure visibility into application health and behavior.

Monitoring is implemented using **Azure Application Insights**, **Azure Monitor**, and **Log Analytics**, and focuses on the following signals:

- **Request volume** – tracking total incoming API requests over time
- **Failed requests** – identifying error conditions and unsuccessful responses
- **Response time (latency)** – measuring backend performance and degradation
- **Application logs & traces** – enabling debugging and root-cause analysis

Metric-based alerts are configured in **Azure Monitor** to notify on:
- Elevated error rates
- Increased average response time

Dashboards and metrics were validated using real traffic and test requests to confirm correct telemetry and alert behavior.

This monitoring work is treated as a separate portfolio project focused on operating and observing a live cloud application, rather than building new infrastructure.

---

## 

This project demonstrates:

* Designing and deploying a **production-style cloud architecture** on Azure
* Managing **all infrastructure via Terraform**
* Configuring **Azure Front Door** with a **custom domain** and managed TLS certificates
* Building a **serverless backend** with Azure Functions + Table Storage
* Implementing **CI/CD pipelines** with GitHub Actions for both frontend and backend
* Integrating **monitoring and logging** with Log Analytics and Application Insights
* Managing **Cloudflare DNS** in front of Azure resources
* Debugging real-world issues: regional quotas, workspace-based Application Insights, custom domain validation, CORS, etc.


---

## 🚀 Future Improvements
* Extend the site with additional projects and blog posts
* Add a contact form backed by another Azure Function or Logic App

```


