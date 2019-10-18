#main.tf inorder to deploy images using packer into Azure

provider "azurerm" {
  version = "=1.34.0"
}

module "hashistack" {
  source = "../modules/hashistack"

  server_count        = var.server_count
  client_count        = var.client_count
  location            = var.location
  vm_size             = var.vm_size
  image_id            = var.image_id
  resource_group_name = var.resource_group_name
  name_prefix         = "Avengers"
  tenant_id           = var.tenant_id   
  client_secret       = var.client_secret
}

