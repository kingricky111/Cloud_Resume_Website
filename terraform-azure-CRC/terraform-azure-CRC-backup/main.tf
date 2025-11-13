
# Terraform & Provider

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.113" # or latest
    }
  }
}

provider "azurerm" {
  features {}
}


# Resource Group

resource "azurerm_resource_group" "rg" {
  name     = "${var.project}-rg"
  location = var.location
}


# Storage Account

resource "azurerm_storage_account" "crc" {
  name                     = "${var.project}crc"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  static_website {
    index_document = "index.html"
    error_404_document = "404.html"
  }

  tags = {
    Project = var.project
    Managed = "Terraform"
  }
}


# Output the static website URL

output "static_website_url" {
  value       = azurerm_storage_account.crc.primary_web_endpoint
  description = "Public URL of your Cloud Resume static website"
}




# Azure Front Door (Standard/Premium) profile

resource "azurerm_cdn_frontdoor_profile" "fd_profile" {
  name                = "${var.project}-fd-profile"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = var.frontdoor_sku_name
}


# Front Door endpoint (public entrypoint)

resource "azurerm_cdn_frontdoor_endpoint" "fd_endpoint" {
  name                     = "${var.project}-fd-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd_profile.id
}


# Origin group (load balancing / health)

resource "azurerm_cdn_frontdoor_origin_group" "fd_origin_group" {
  name                     = "${var.project}-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd_profile.id
  session_affinity_enabled = false

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    path                = "/"
    request_type        = "HEAD"
    protocol            = "Https"
    interval_in_seconds = 120
  }
}


# Origin: your Storage static website

resource "azurerm_cdn_frontdoor_origin" "fd_origin" {
  name                          = "${var.project}-storage-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.fd_origin_group.id
  enabled                       = true

  # Hostname of the storage static website (no https://)
  host_name          = azurerm_storage_account.crc.primary_web_host
  http_port          = 80
  https_port         = 443
  origin_host_header = azurerm_storage_account.crc.primary_web_host

  priority = 1
  weight   = 1000

  certificate_name_check_enabled = true
}



# Route: connect endpoint → origin group

resource "azurerm_cdn_frontdoor_route" "fd_route" {
  name                          = "${var.project}-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.fd_endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.fd_origin_group.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.fd_origin.id]

  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]
  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true

  # For now, serve from the default Front Door hostname
  link_to_default_domain = true
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.project}-law"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}



# Application Insights (logs/metrics for Functions)

resource "azurerm_application_insights" "ai" {
  name                = "${var.project}-ai"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.law.id
}


# Function App host plan (Consumption: Y1)

resource "azurerm_service_plan" "func_plan" {
  name                = "${var.project}-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.functions_location

  os_type  = "Linux"
  sku_name = "Y1" # Consumption
}


# Storage account for the Function host (required)
# (Separate from your static-website storage)

resource "azurerm_storage_account" "func_sa" {
  name                     = "${replace(var.project, "-", "")}funcsa"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.functions_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  tags = {
    Project = var.project
  }
}


# Storage account for data (Table Storage)

resource "azurerm_storage_account" "data_sa" {
  name                     = "${replace(var.project, "-", "")}datasa"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  tags = {
    Project = var.project
  }
}

resource "azurerm_storage_table" "visitors" {
  name                 = var.table_name
  storage_account_name = azurerm_storage_account.data_sa.name
}


# Linux Function App (Python)

resource "azurerm_linux_function_app" "func" {
  name                       = "${var.project}-${var.func_name}"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = var.functions_location
  service_plan_id            = azurerm_service_plan.func_plan.id
  storage_account_name       = azurerm_storage_account.func_sa.name
  storage_account_access_key = azurerm_storage_account.func_sa.primary_access_key
  functions_extension_version = "~4"

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = var.python_version
    }

    # CORS so your site can call the API
    cors {
      allowed_origins = [
        "https://www.${var.custom_domain_name}",
        "https://${azurerm_cdn_frontdoor_endpoint.fd_endpoint.host_name}", # helpful for testing
      ]
      support_credentials = false
    }
    minimum_tls_version = "1.2"
  }

  app_settings = {
    # Function runtime
    FUNCTIONS_WORKER_RUNTIME = "python"

    # Deploying code as a zip/package via CI later
    WEBSITE_RUN_FROM_PACKAGE = "1"

    # Observability
    APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.ai.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.ai.connection_string

    # Table storage connection for your Python code
    TABLES_CONNECTION_STRING = azurerm_storage_account.data_sa.primary_connection_string
    TABLES_ACCOUNT_NAME      = azurerm_storage_account.data_sa.name
    TABLES_TABLE_NAME        = azurerm_storage_table.visitors.name
  }

  tags = {
    Project = var.project
  }
}
