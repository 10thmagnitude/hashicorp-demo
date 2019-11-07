variable "client_secret" {
  description = "Should be provided by the TF_VAR_client_secret environment variable"
}

variable "consul_keygen" {

}

variable "client_count" {
  default = 1
}

variable "server_count" {
  default = 1
}

variable "location" {
  default = "eastus"
}

variable "vm_size" {
  default = "Standard_D2s_v3"
}

variable "resource_group_name" {
  default = "myResourceGroup"
}

variable "image_id" {
}


