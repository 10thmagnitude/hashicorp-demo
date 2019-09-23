variable "vm_count" {
    default = 1
}

variable "location" {
    default = "eastus"
}

variable "vm_size" {
    default = "Standard_DS1_v2"
}

variable "resource_group_name" {
    default = "myResourceGroup"
}

variable "image_id" {
    default = "/subscriptions/aff2c340-2ecc-404c-8fc1-d86773973e78/resourceGroups/plaz-witcher-dev-rg/providers/Microsoft.Compute/images/MyUbuntuImage"
}

variable "name_prefix" {
    default = "demo"
}


resource "azurerm_resource_group" "resource_group" {
    name     = "${var.resource_group_name}"
    location = "${var.location}"

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_virtual_network" "terraform_network" {
    name                = "${var.name_prefix}vnet"
    address_space       = ["10.0.0.0/16"]
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.resource_group.name}"

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_subnet" "myterraformsubnet" {
    name                 = "${var.name_prefix}subnet"
    resource_group_name  = "${azurerm_resource_group.resource_group.name}"
    virtual_network_name = "${azurerm_virtual_network.terraform_network.name}"
    address_prefix       = "10.0.2.0/24"
}

resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "${var.name_prefix}_network_security_group"
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.resource_group.name}"
    
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
    name                         = "${var.name_prefix}_public_ip"
    location                     = "${var.location}"
    resource_group_name          = "${azurerm_resource_group.resource_group.name}"
    allocation_method            = "Dynamic"

    tags = {
        environment = "Terraform Demo"
    }

}

resource "azurerm_network_interface" "client_nic" {
    name                = "${var.name_prefix}_client_NIC-${count.index}"
    count               = "${var.vm_count}"
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.resource_group.name}"
    network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

    ip_configuration {
        name                          = "${var.name_prefix}_client_nic_configuration-${count.index}"
        subnet_id                     = "${azurerm_subnet.myterraformsubnet.id}"
        private_ip_address_allocation = "Dynamic"
    }

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_network_interface" "jump_box_nic" {
    name                = "${var.name_prefix}_jump_box_nic"
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.resource_group.name}"
    network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

    ip_configuration {
        name                          = "jump_box_nic_configuration"
        subnet_id                     = "${azurerm_subnet.myterraformsubnet.id}"
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = "${azurerm_public_ip.myterraformpublicip.id}" 
    }

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_virtual_machine" "jump_box" {
    name                  = "${var.name_prefix}_jump_box"
    location              = "${var.location}"
    resource_group_name   = "${azurerm_resource_group.resource_group.name}"
    network_interface_ids = ["${azurerm_network_interface.jump_box_nic.id}"]
    vm_size               = "${var.vm_size}"

    storage_image_reference {
        id = "${var.image_id}"
    }
    
    storage_os_disk {
        name              = "${var.name_prefix}_jump-box-os_disk"
        caching           = "ReadWrite"
        managed_disk_type = "Standard_LRS"
        os_type       = "Linux"
        create_option = "FromImage"
    }


    os_profile {
        computer_name  = "${var.name_prefix}-jump-box-vm"
        admin_username = "tonystark"
        admin_password = "Password1234!"
    }

    os_profile_linux_config {
        disable_password_authentication = false
        
    }

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_virtual_machine" "client_vm" {
    name                  = "${var.name_prefix}_client-${count.index}"
    count                 = "${var.vm_count}"
    location              = "${var.location}"
    resource_group_name   = "${azurerm_resource_group.resource_group.name}"
    network_interface_ids = ["${azurerm_network_interface.client_nic.*.id[count.index]}"]
    vm_size               = "${var.vm_size}"


    storage_image_reference {
        id = "${var.image_id}"
    }
    


    storage_os_disk {
        name              = "${var.name_prefix}_os_disk-${count.index}"
        caching           = "ReadWrite"
        managed_disk_type = "Standard_LRS"
        os_type       = "Linux"
        create_option = "FromImage"
    }


    os_profile {
        computer_name  = "${var.name_prefix}-client-vm-${count.index}"
        admin_username = "brucebanner"
        admin_password = "Password1234!"
    }

    os_profile_linux_config {
        disable_password_authentication = false        
    }

    tags = {
        environment = "Terraform Demo"
        id = "client_${count.index}"
    }

    depends_on = ["azurerm_virtual_machine.jump_box"]


}

output "jump_box_private_ip" {
    value = ["${azurerm_network_interface.jump_box_nic.private_ip_address}"]
}

output "client_private_ips" {
    value = ["${azurerm_network_interface.client_nic.*.private_ip_addresses}"]
}

output "jump_box_public_ip" {
    value = ["${azurerm_public_ip.myterraformpublicip.ip_address}"]
}