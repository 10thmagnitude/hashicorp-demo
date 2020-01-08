variable "tenant_id" {
  default = "empty"
}

variable "client_secret" {
  description = "Should be provided by the TF_VAR_client_secret environment variable"
}

variable "consul_keygen" {

}

variable "client_count" {
}

variable "server_count" {
}

variable "location" {
}

variable "vm_size" {
  default = "Standard_D2s_v3"
}

variable "resource_group_name" {
  default = "sock_shop_app_rg"
}

variable "image_id" {
}


