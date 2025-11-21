output "app_name" {
  value = azurerm_linux_web_app.sample_app.name
}

output "app_url" {
  value = "https://${azurerm_linux_web_app.sample_app.default_hostname}"
}

output "app_insights_key" {
  value     = azurerm_application_insights.insights.instrumentation_key
  sensitive = true
}

output "db_fqdn" {
  value = azurerm_mysql_flexible_server.mysql_db_server.fqdn
}

output "db_admin_user" {
  value = azurerm_mysql_flexible_server.mysql_db_server.administrator_login
}

output "storage_account_name" {
  value = azurerm_storage_account.storage_account.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.keyvault.vault_uri
}

output "mysql_admin_password" {
  value     = random_password.db_password.result
  sensitive = true
}
