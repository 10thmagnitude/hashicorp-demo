resource "azurerm_resource_group" "resource_group" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    environment = "Terraform Demo"
  }
}

resource "random_string" "password" {
  length      = 12
  min_numeric = 1
  min_upper   = 1
  min_lower   = 1
  special     = false
}

resource "random_pet" "label" {
}

data "azurerm_client_config" "current" {}
