# output "jump_box_private_ip" {
#   value = [azurerm_network_interface.jump_box_nic.private_ip_address]
# }

output "client_private_ips" {
  value = [azurerm_network_interface.client_nic.*.private_ip_addresses]
}

output "server_private_ips" {
  value = "\"${replace(join(",", azurerm_network_interface.server_nic[*].private_ip_addresses[0]), ",", "\", \"")}\""
}

output "vault_ip" {
  value = "${element(azurerm_network_interface.server_nic[*].private_ip_addresses[0], 0)}"
}

output "bastion_dns_name" {
  value = azurerm_bastion_host.bastion_host.dns_name
}

output "password" {
  value = random_string.password.result
}

