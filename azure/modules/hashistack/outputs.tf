output "jump_box_private_ip" {
  value = [azurerm_network_interface.jump_box_nic.private_ip_address]
}

output "client_private_ips" {
  value = [azurerm_network_interface.client_nic.*.private_ip_addresses]
}

output "server_private_ips" {
  value = [azurerm_network_interface.server_nic.*.private_ip_addresses]
}

output "jump_box_public_ip" {
  value = [data.azurerm_public_ip.jumpbox_public_ip.ip_address]
}

output "password" {
  value = random_string.password.result
}


