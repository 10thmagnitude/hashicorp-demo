data "template_cloudinit_config" "server_cloud_config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = "${data.template_file.server_cloud_config.rendered}"
  }
}

data "template_file" "server_cloud_config" {
  template = "${file("${path.module}/templates/server-cloud-config.yml.tpl")}"

  vars = {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    subscription_id    = data.azurerm_client_config.current.subscription_id
    client_id          = data.azurerm_client_config.current.client_id
    client_secret      = var.client_secret
    consul_encrypt_key = var.consul_keygen
    server_count       = var.server_count
    consul_servers     = "\"${replace(join(",", azurerm_network_interface.server_nic[*].private_ip_addresses[0]), ",", "\", \"")}\""
    vault_server_ip    = "${element(azurerm_network_interface.server_nic[*].private_ip_addresses[0], 0)}"
    key_vault_name     = azurerm_key_vault.key_vault.name
    key_vault_key_name = azurerm_key_vault_key.key_vault_key.name
    private_key_name   = azurerm_key_vault_secret.private_ssh_key.name
    public_key_name    = azurerm_key_vault_secret.public_ssh_key.name
  }
}

data "template_cloudinit_config" "client_cloud_config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = "${data.template_file.client_cloud_config.rendered}"
  }
}

data "template_file" "client_cloud_config" {
  template = "${file("${path.module}/templates/client-cloud-config.yml.tpl")}"

  vars = {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    subscription_id    = data.azurerm_client_config.current.subscription_id
    client_id          = data.azurerm_client_config.current.client_id
    client_secret      = var.client_secret
    consul_encrypt_key = var.consul_keygen
    server_count       = var.server_count
    consul_servers     = "\"${replace(join(",", azurerm_network_interface.server_nic[*].private_ip_addresses[0]), ",", "\", \"")}\""
    vault_server_ip    = "${element(azurerm_network_interface.server_nic[*].private_ip_addresses[0], 0)}"
    key_vault_name     = azurerm_key_vault.key_vault.name
    private_key_name   = azurerm_key_vault_secret.private_ssh_key.name
    public_key_name    = azurerm_key_vault_secret.public_ssh_key.name
  }
}

resource "azurerm_virtual_network" "terraform_network" {
  name                = "${random_pet.label.id}_vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  tags = {
    environment = "Sock Shop Demo"
  }
}

resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.terraform_network.name
  address_prefix       = "10.0.1.0/24"
}

resource "azurerm_subnet" "myterraformsubnet" {
  name                 = "${random_pet.label.id}_subnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.terraform_network.name
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_network_security_group" "myterraformnsg" {
  name                = "${random_pet.label.id}_network_security_group"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Sock Shop Demo"
  }
}

resource "azurerm_public_ip" "bastion_public_ip" {
  name                = "${random_pet.label.id}_bastion_public_ip"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = "Sock Shop Demo"
  }
}

resource "azurerm_network_interface" "server_nic" {
  name                      = "${random_pet.label.id}_server_NIC-${count.index}"
  count                     = var.server_count
  location                  = azurerm_resource_group.resource_group.location
  resource_group_name       = azurerm_resource_group.resource_group.name
  network_security_group_id = azurerm_network_security_group.myterraformnsg.id

  ip_configuration {
    name                          = "${random_pet.label.id}_server_nic_configuration-${count.index}"
    subnet_id                     = azurerm_subnet.myterraformsubnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = "Sock Shop Demo"
    consul      = "server"
  }
}

resource "azurerm_bastion_host" "bastion_host" {
  name                = "${random_pet.label.id}-bastion"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_public_ip.id
  }
}

resource "azurerm_network_interface" "client_nic" {
  count = var.client_count

  name                      = "${random_pet.label.id}_client_NIC-${count.index}"
  location                  = azurerm_resource_group.resource_group.location
  resource_group_name       = azurerm_resource_group.resource_group.name
  network_security_group_id = azurerm_network_security_group.myterraformnsg.id

  ip_configuration {
    name                          = "${random_pet.label.id}_client_nic_configuration-${count.index}"
    subnet_id                     = azurerm_subnet.myterraformsubnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = "Sock Shop Demo"
  }
}

resource "azurerm_virtual_machine" "client_vm" {
  count = var.client_count

  name                             = "${random_pet.label.id}_client-${count.index}"
  location                         = azurerm_resource_group.resource_group.location
  resource_group_name              = azurerm_resource_group.resource_group.name
  network_interface_ids            = [azurerm_network_interface.client_nic[count.index].id]
  vm_size                          = var.vm_size
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    id = var.image_id
  }

  storage_os_disk {
    name              = "${random_pet.label.id}_client-os_disk-${count.index}"
    caching           = "ReadWrite"
    managed_disk_type = "Standard_LRS"
    os_type           = "Linux"
    create_option     = "FromImage"
  }

  os_profile {
    computer_name  = "${random_pet.label.id}-client-vm-${count.index}"
    admin_username = "ssdemo"
    admin_password = random_string.password.result
    custom_data    = data.template_cloudinit_config.client_cloud_config.rendered
  }

  os_profile_linux_config {
    disable_password_authentication = false
    ssh_keys {
      path     = "/home/ssdemo/.ssh/authorized_keys"
      key_data = tls_private_key.ssh_key.public_key_openssh
    }
  }

  tags = {
    environment = "Sock Shop Demo"
    id          = "client_${count.index}"
  }

}



resource "azurerm_virtual_machine" "server_vm" {
  count = var.server_count

  name                             = "${random_pet.label.id}_server-${count.index}"
  location                         = azurerm_resource_group.resource_group.location
  resource_group_name              = azurerm_resource_group.resource_group.name
  network_interface_ids            = [azurerm_network_interface.server_nic[count.index].id]
  vm_size                          = var.vm_size
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    id = var.image_id
  }

  storage_os_disk {
    name              = "${random_pet.label.id}_server-os_disk-${count.index}"
    caching           = "ReadWrite"
    managed_disk_type = "Standard_LRS"
    os_type           = "Linux"
    create_option     = "FromImage"
  }

  os_profile {
    computer_name  = "${random_pet.label.id}-server-vm-${count.index}"
    admin_username = "ssdemo"
    admin_password = random_string.password.result
    custom_data    = data.template_cloudinit_config.server_cloud_config.rendered
  }

  os_profile_linux_config {
    disable_password_authentication = false
    ssh_keys {
      path     = "/home/ssdemo/.ssh/authorized_keys"
      key_data = tls_private_key.ssh_key.public_key_openssh
    }
  }

  tags = {
    environment = "Sock Shop Demo"
    id          = "server${count.index}"
    consul      = "server"
  }

}

resource "azurerm_public_ip" "sockshop_public_ip" {
  name                = "SockShopPublicIP"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  allocation_method   = "Dynamic"
}

resource "azurerm_subnet" "frontend" {
  name                 = "frontend"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.terraform_network.name
  address_prefix       = "10.0.3.0/24"
}


# since these variables are re-used - a locals block makes this more maintainable
locals {
  backend_address_pool_name      = "${azurerm_virtual_network.terraform_network.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.terraform_network.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.terraform_network.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.terraform_network.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.terraform_network.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.terraform_network.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.terraform_network.name}-rdrcfg"
}

resource "azurerm_application_gateway" "application_gateway" {
  name                = "sockshop-appgateway"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  sku {
    name     = "Standard_Small"
    tier     = "Standard"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.frontend.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.sockshop_public_ip.id
  }

  backend_address_pool {
    name         = local.backend_address_pool_name
    ip_addresses = azurerm_network_interface.client_nic[*].private_ip_addresses[0]
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
}
