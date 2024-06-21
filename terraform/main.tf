resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  static_website {
    index_document = "index.html"
    error_404_document = "404.html"
  }
}

resource "azurerm_storage_container" "web" {
  name                  = "$web"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "container"
}

resource "azurerm_app_service_plan" "main" {
  name                = "functionAppPlan"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "main" {
  name                       = var.function_app_name
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  app_service_plan_id        = azurerm_app_service_plan.main.id
  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key
  https_only                 = true

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "dotnet"
    AzureWebJobsStorage      = azurerm_storage_account.main.primary_blob_endpoint
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_api_management" "main" {
  name                = var.api_management_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  publisher_name      = "Contoso"
  publisher_email     = "admin@example.com"
  sku_name            = "Consumption_0"
}

resource "azurerm_sql_server" "main" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "P@ssw0rd!"

  threat_detection_policy {
    email_account_admins            = true
    storage_account_access_key      = azurerm_storage_account.main.primary_access_key
    storage_endpoint                = azurerm_storage_account.main.primary_blob_endpoint
    retention_days                  = 30
  }
}

resource "azurerm_mssql_database" "serverless_db" {
    name                        = "serverles-db"
    server_id                   = azurerm_sql_server.main.id
    collation                   = "SQL_Latin1_General_CP1_CI_AS"

    auto_pause_delay_in_minutes = 60
    max_size_gb                 = 32
    min_capacity                = 0.5
    read_replica_count          = 0
    read_scale                  = false
    sku_name                    = "GP_S_Gen5_1"
    zone_redundant              = false

    threat_detection_policy {
        disabled_alerts      = []
        email_account_admins = "Disabled"
        email_addresses      = []
        retention_days       = 0
        state                = "Disabled"
    }
}

resource "azurerm_dns_zone" "dns" {
  name                = "sub-domain.domain.com"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_cdn_frontdoor_profile" "cdn" {
  name                = "profile-frontend"
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Standard_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_custom_domain" "cdn_customdomain" {
  name                     = "customDomain"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.cdn.id
  dns_zone_id              = azurerm_dns_zone.dns.id
  host_name                = "contoso.fabrikam.com"

  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = "TLS12"
  }
}
output "storage_account_primary_web_endpoint" {
  value = azurerm_storage_account.main.primary_web_endpoint
}

output "function_app_default_hostname" {
  value = azurerm_function_app.main.default_hostname
}

output "api_management_gateway_url" {
  value = azurerm_api_management.main.gateway_url
}
