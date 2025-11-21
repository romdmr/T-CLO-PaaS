data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

#Suffixe unique pour eviter les collisions
resource "random_id" "suffix" {
  byte_length = 2
}

# Variables locales
locals {
  base_name = "${var.app_name}-${var.environment}"
  tags = {
    project     = "terracloud"
    environment = var.environment
    owner       = "romain"
  }
}

#Service Plan
resource "azurerm_service_plan" "azure_service_plan" {
  name                = "asp-${random_id.suffix.hex}"
  resource_group_name = data.azurerm_resource_group.rg.name
  sku_name            = "B1"
  location            = data.azurerm_resource_group.rg.location
  os_type             = "Linux"
  tags                = local.tags
}

#MySQL
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "azurerm_mysql_flexible_server" "mysql_db_server" {
  name                   = "mysql-${random_id.suffix.hex}"
  resource_group_name    = data.azurerm_resource_group.rg.name
  location               = data.azurerm_resource_group.rg.location
  administrator_login    = "mysqladmin"
  administrator_password = random_password.db_password.result #C'est temporaire parce que j'avais un souci avec le mdp généré
  backup_retention_days  = 7
  sku_name               = "B_Standard_B1ms"
  tags                   = local.tags
}

resource "azurerm_mysql_flexible_database" "app_db" {
  name                = "sampleappdb"
  resource_group_name = data.azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.mysql_db_server.name
  charset             = "utf8"
  collation           = "utf8_general_ci"
}

#Monitoring
resource "azurerm_application_insights" "insights" {
  name                = "insights-${random_id.suffix.hex}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  application_type    = "web"
  tags                = local.tags
}

#Key Vault
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "keyvault" {
  name                     = "kv-${random_id.suffix.hex}"
  resource_group_name      = data.azurerm_resource_group.rg.name
  location                 = data.azurerm_resource_group.rg.location
  sku_name                 = "standard"
  tenant_id                = var.tenant_id
  purge_protection_enabled = true
  tags                     = local.tags
}

resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id       = azurerm_key_vault.keyvault.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = data.azurerm_client_config.current.object_id
  secret_permissions = ["Get", "List", "Set"]
}

resource "azurerm_key_vault_secret" "vault_db_password" {
  name         = "vault_db-password"
  value        = random_password.db_password.result
  key_vault_id = azurerm_key_vault.keyvault.id
}

resource "azurerm_key_vault_secret" "app_key" {
  name         = "app-key"
  value        = var.app_key
  key_vault_id = azurerm_key_vault.keyvault.id
}

#Storage
resource "azurerm_storage_account" "storage_account" {
  name                     = "st${random_id.suffix.hex}"
  resource_group_name      = data.azurerm_resource_group.rg.name
  location                 = data.azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.tags
}

resource "azurerm_storage_container" "logs" {
  name                  = "logs"
  storage_account_id    = azurerm_storage_account.storage_account.id
  container_access_type = "private"
}

#ACR
resource "azurerm_container_registry" "acr" {
  name                = "acr${random_id.suffix.hex}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "Standard"
  admin_enabled       = false

  tags = local.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id = azurerm_linux_web_app.sample_app.identity[0].principal_id

    depends_on = [
    azurerm_linux_web_app.sample_app
  ]

}

#Webapp
resource "azurerm_linux_web_app" "sample_app" {
  name                = "${local.base_name}-webapp-${random_id.suffix.hex}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.azure_service_plan.id
  https_only          = true
  tags                = local.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true

    container_registry_use_managed_identity = true

    application_stack {
      docker_image_name = "${var.app_name}:${var.image_tag}"

      docker_registry_url = "https://${azurerm_container_registry.acr.login_server}"
    }
  }

  app_settings = {
    WEBSITES_PORT                       = "80"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "true"

    # Laravel
    APP_NAME  = var.app_name
    APP_ENV   = "production"
    APP_DEBUG = "false"
    APP_URL   = "https://${local.base_name}-webapp-${random_id.suffix.hex}.azurewebsites.net"

    DB_CONNECTION = "mysql"
    DB_HOST       = azurerm_mysql_flexible_server.mysql_db_server.fqdn
    DB_PORT       = "3306"
    DB_DATABASE   = azurerm_mysql_flexible_database.app_db.name
    DB_USERNAME   = azurerm_mysql_flexible_server.mysql_db_server.administrator_login
    DB_PASSWORD   = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.vault_db_password.id})"

    APP_KEY = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.app_key.id})"
    MYSQL_ATTR_SSL_CA = "/etc/ssl/certs/ca-certificates.crt"

    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.insights.connection_string
  }
}


resource "azurerm_key_vault_access_policy" "web_app" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = var.tenant_id
  object_id    = azurerm_linux_web_app.sample_app.identity[0].principal_id

  secret_permissions = ["Get"]

    depends_on = [
    azurerm_linux_web_app.sample_app
  ]
}

