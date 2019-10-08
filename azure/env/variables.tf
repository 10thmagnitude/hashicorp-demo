variable "client_secret" {

}

variable "resource_group_name" {
  default = "sock_shop_demo"
}

variable "location" {
  description = "The Azure Location to deploy the resources."
}

variable "server_count" {
  description = "how many servers to deploy with the packer image"
  default     = 3
}

variable "vm_size" {
  default = "Standard_D2s_v3"
}

variable "image_id" {
}

