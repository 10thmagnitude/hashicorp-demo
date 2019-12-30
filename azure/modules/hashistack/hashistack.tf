data "template_cloudinit_config" "cloud_config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = "${data.template_file.cloud_config.rendered}"
  }
}

data "template_file" "cloud_config" {
  template = "${file("${path.module}/templates/server-cloud-config.yml.tpl")}"

  vars = {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    subscription_id    = data.azurerm_client_config.current.subscription_id
    client_id          = data.azurerm_client_config.current.client_id
    client_secret      = var.client_secret
    consul_encrypt_key = var.consul_keygen
    server_count       = var.server_count
    key_vault_name     = azurerm_key_vault.key_vault.name
    key_vault_key_name = azurerm_key_vault_key.key_vault_key.name
  }
}

  tags = {
    environment = "Sock Shop Demo"
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
  name                = "${random_pet.label.id}_vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  tags = {
    environment = "Sock Shop Demo"
  }
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

resource "azurerm_public_ip" "myterraformpublicip" {
  name                = "${random_pet.label.id}_public_ip"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  allocation_method   = "Dynamic"

  tags = {
    environment = "Sock Shop Demo"
  }
}

resource "azurerm_network_interface" "server_nic" {
  name                      = "${var.name_prefix}_server_NIC-${count.index}"
  count                     = var.server_count
  location                  = azurerm_resource_group.resource_group.location
  resource_group_name       = azurerm_resource_group.resource_group.name
  network_security_group_id = azurerm_network_security_group.myterraformnsg.id

  ip_configuration {
    name                          = "${var.name_prefix}_server_nic_configuration-${count.index}"
    subnet_id                     = azurerm_subnet.myterraformsubnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = "Sock Shop Demo"
    consul = "server"
  }
}

data "azurerm_public_ip" "jumpbox_public_ip" {
  name                = "${azurerm_public_ip.myterraformpublicip.name}"
  resource_group_name = "${azurerm_virtual_machine.jump_box.resource_group_name}"
}

resource "azurerm_network_interface" "jump_box_nic" {
  name                      = "${random_pet.label.id}_jump_box_nic"
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

resource "azurerm_network_interface" "server_nic" {
  count = var.server_count

  name                      = "${random_pet.label.id}_server_NIC-${count.index}"
  location                  = azurerm_resource_group.resource_group.location
  resource_group_name       = azurerm_resource_group.resource_group.name
  network_security_group_id = azurerm_network_security_group.myterraformnsg.id

  ip_configuration {
    name                          = "${random_pet.label.id}_server_nic_configuration-${count.index}"
    subnet_id                     = azurerm_subnet.myterraformsubnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = "Terraform Demo"
    consul      = "server"
  }
}

# data "template_file" "user_data_client" {
#   template = "${file("${path.root}/user-data-client.sh")}"

#   vars {
#     region            = "${var.region}"
#     cluster_tag_value = "${var.cluster_tag_value}"
#     server_ip = "${aws_instance.primary.0.private_ip}"
#   }
# }


resource "azurerm_virtual_machine" "jump_box" {
  name                             = "${random_pet.label.id}_jump_box"
  location                         = azurerm_resource_group.resource_group.location
  resource_group_name              = azurerm_resource_group.resource_group.name
  network_interface_ids            = [azurerm_network_interface.jump_box_nic.id]
  vm_size                          = var.vm_size
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${random_pet.label.id}_jump-box-os_disk"
    caching           = "ReadWrite"
    managed_disk_type = "Standard_LRS"
    os_type           = "Linux"
    create_option     = "FromImage"
  }

  os_profile {
    computer_name  = "${random_pet.label.id}-jump-box-vm"
    admin_username = "ssdemo"
    admin_password = random_string.password.result
  }

  os_profile_linux_config {
    disable_password_authentication = false
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
    custom_data    = "${data.template_cloudinit_config.cloud_config.rendered}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
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
    custom_data    = "${data.template_cloudinit_config.cloud_config.rendered}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = "Terraform Demo"
    id          = "server${count.index}"
    consul      = "server"
  }

}


