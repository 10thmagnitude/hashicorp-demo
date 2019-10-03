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

resource "azurerm_virtual_network" "terraform_network" {
  name                = "${var.name_prefix}vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  tags = {
    environment = "Terraform Demo"
  }
}

resource "azurerm_subnet" "myterraformsubnet" {
  name                 = "${var.name_prefix}subnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.terraform_network.name
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_network_security_group" "myterraformnsg" {
  name                = "${var.name_prefix}_network_security_group"
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
    environment = "Terraform Demo"
  }
}

resource "azurerm_public_ip" "myterraformpublicip" {
  name                = "${var.name_prefix}_public_ip"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  allocation_method   = "Dynamic"

  tags = {
    environment = "Terraform Demo"
  }
}

resource "azurerm_network_interface" "client_nic" {
  name                      = "${var.name_prefix}_client_NIC-${count.index}"
  count                     = var.vm_count
  location                  = azurerm_resource_group.resource_group.location
  resource_group_name       = azurerm_resource_group.resource_group.name
  network_security_group_id = azurerm_network_security_group.myterraformnsg.id

  ip_configuration {
    name                          = "${var.name_prefix}_client_nic_configuration-${count.index}"
    subnet_id                     = azurerm_subnet.myterraformsubnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = "Terraform Demo"
  }
}

resource "azurerm_network_interface" "jump_box_nic" {
  name                      = "${var.name_prefix}_jump_box_nic"
  location                  = azurerm_resource_group.resource_group.location
  resource_group_name       = azurerm_resource_group.resource_group.name
  network_security_group_id = azurerm_network_security_group.myterraformnsg.id

  ip_configuration {
    name                          = "jump_box_nic_configuration"
    subnet_id                     = azurerm_subnet.myterraformsubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
  }

  tags = {
    environment = "Terraform Demo"
  }
}

resource "azurerm_virtual_machine" "jump_box" {
  name                             = "${var.name_prefix}_jump_box"
  location                         = azurerm_resource_group.resource_group.location
  resource_group_name              = azurerm_resource_group.resource_group.name
  network_interface_ids            = [azurerm_network_interface.jump_box_nic.id]
  vm_size                          = var.vm_size
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    id = var.image_id
  }

  storage_os_disk {
    name              = "${var.name_prefix}_jump-box-os_disk"
    caching           = "ReadWrite"
    managed_disk_type = "Standard_LRS"
    os_type           = "Linux"
    create_option     = "FromImage"
  }

  os_profile {
    computer_name  = "${var.name_prefix}-jump-box-vm"
    admin_username = "tonystark"
    admin_password = random_string.password.result
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = "Terraform Demo"
  }
}

resource "azurerm_virtual_machine" "client_vm" {
  name                             = "${var.name_prefix}_client-${count.index}"
  count                            = var.vm_count
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
    name              = "${var.name_prefix}_os_disk-${count.index}"
    caching           = "ReadWrite"
    managed_disk_type = "Standard_LRS"
    os_type           = "Linux"
    create_option     = "FromImage"
  }

  os_profile {
    computer_name  = "${var.name_prefix}-client-vm-${count.index}"
    admin_username = "brucebanner"
    admin_password = random_string.password.result
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = "Terraform Demo"
    id          = "client_${count.index}"
  }

}


