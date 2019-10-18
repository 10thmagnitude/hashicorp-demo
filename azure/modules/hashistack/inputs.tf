variable "tenant_id" {
  default = "empty"
}

variable "server_count" {
  default = 3
}

variable "client_count" {
  default = 4
}

variable "location" {
  default = "westus"
}

variable "vm_size" {
  default = "Standard_D2s_v3"
}

variable "resource_group_name" {
  default = "sock_shop_app_rg"
}

variable "image_id" {
}

variable "name_prefix" {
  default = "demo"
}

