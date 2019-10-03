output "jump_box_private_ip" {
  value = [azurerm_network_interface.jump_box_nic.private_ip_address]
}

output "client_private_ips" {
  value = [azurerm_network_interface.client_nic.*.private_ip_addresses]
}

output "jump_box_public_ip" {
  value = [azurerm_public_ip.myterraformpublicip.ip_address]
}

output "password" {
  value = random_string.password.result
}
