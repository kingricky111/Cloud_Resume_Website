variable "project" {
  description = "Prefix for resource naming"
  type        = string
  default     = "cloudresume"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

# Custom domain i plan to buy, e.g. "rickycloudresume.com"
variable "custom_domain_name" {
  description = "Root custom domain for the resume site (no www). Example: mycloudresume.com"
  type        = string
  default     = "rickycloudresume.com" # 🔁 change this when you know your domain
}

# Front Door SKU
variable "frontdoor_sku_name" {
  description = "SKU for Azure Front Door Standard/Premium"
  type        = string
  default     = "Standard_AzureFrontDoor"
}

# Function app + data names
variable "func_name" {
  description = "Base name for the Function App"
  type        = string
  default     = "crc-api"
}

variable "table_name" {
  description = "Azure Table Storage table name for the visitor counter"
  type        = string
  default     = "visitors"
}

# Function runtime
variable "python_version" {
  description = "Python version for the Linux Function App"
  type        = string
  default     = "3.10"
}

variable "functions_location" {
  description = "Region for the Function App plan"
  type        = string
  default     = "centralus"
}

variable "alert_email" {
  description = "email to recieve alerts"
  type        = string 
}