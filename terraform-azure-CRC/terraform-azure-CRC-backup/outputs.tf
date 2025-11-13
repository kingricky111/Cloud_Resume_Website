output "resource_group_name" {
  value       = azurerm_resource_group.rg.name
  description = "Resource Group name"
}

output "storage_account_name" {
  value       = azurerm_storage_account.crc.name
  description = "Storage Account name"
}

output "static_site_url" {
  value       = azurerm_storage_account.crc.primary_web_endpoint
  description = "Static website endpoint URL"
}

output "frontdoor_endpoint_hostname" {
  value       = azurerm_cdn_frontdoor_endpoint.fd_endpoint.host_name
  description = "Azure Front Door endpoint hostname"
}

output "function_host" {
  description = "Function default hostname (append /api/<function_name>)"
  value       = azurerm_linux_function_app.func.default_hostname
}

output "table_account" {
  value       = azurerm_storage_account.data_sa.name
  description = "Storage account used for the visitors table"
}

output "table_name" {
  value       = azurerm_storage_table.visitors.name
  description = "Visitors table name"
}
