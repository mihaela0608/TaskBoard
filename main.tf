terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.39.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "407cdb2b-7fab-4893-97c1-4208a5ae607a"
}

resource "random_integer" "ri" {
  min = 10000
  max = 99999
}

resource "azurerm_resource_group" "task_rg" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

resource "azurerm_mssql_server" "sql_server" {
  name                          = var.sql_server_name
  resource_group_name           = azurerm_resource_group.task_rg.name
  location                      = azurerm_resource_group.task_rg.location
  version                       = "12.0"
  administrator_login           = var.sql_admin_username
  administrator_login_password  = var.sql_admin_password
  public_network_access_enabled = true
}

resource "azurerm_mssql_database" "sql_db" {
  name         = var.sql_database_name
  server_id    = azurerm_mssql_server.sql_server.id
  collation    = "SQL_Latin1_General_CP1_CI_AS"
  license_type = "LicenseIncluded"

  sku_name = "Basic"
}


resource "azurerm_mssql_firewall_rule" "allow_azure" {
  name             = var.firewall_rule_name
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_service_plan" "app_plan" {
  name                = var.app_service_plan_name
  location            = azurerm_resource_group.task_rg.location
  resource_group_name = azurerm_resource_group.task_rg.name
  os_type             = "Linux"

  sku_name = "F1"
}

resource "azurerm_linux_web_app" "web_app" {
  name                = var.app_service_name
  location            = azurerm_resource_group.task_rg.location
  resource_group_name = azurerm_resource_group.task_rg.name
  service_plan_id     = azurerm_service_plan.app_plan.id

  site_config {
    application_stack {
      dotnet_version = "6.0"
    }
    always_on = false
  }

  connection_string {
    name  = "DefaultConnection"
    type  = "SQLAzure"
    value = "Data Source=tcp:${azurerm_mssql_server.sql_server.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.sql_db.name};User ID=${azurerm_mssql_server.sql_server.administrator_login};Password=${azurerm_mssql_server.sql_server.administrator_login_password};Trusted_Connection=False;MultipleActiveResultSets=True;"
  }
}

resource "azurerm_app_service_source_control" "source_control" {
  app_id                 = azurerm_linux_web_app.web_app.id
  repo_url               = var.github_repo_url
  branch                 = "main"
  use_manual_integration = true
}
