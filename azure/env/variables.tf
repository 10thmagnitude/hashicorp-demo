variable "client_secret" {

}
variable "consul_keygen" {
  description = "Generate with consul keygen command and place in terraform.tfvars"
}

variable "resource_group_name" {
  default = "sock_shop_demo"
}

variable "location" {
  description = "The Azure Location to deploy the resources."
}

variable "client_count" {
  description = "how many clients to deploy with the packer image"
  default     = 1
}
variable "server_count" {
  description = "how many servers to deploy with the packer image"
  default     = 1
}

variable "vm_size" {
  default = "Standard_D2s_v3"
}

variable "image_id" {
  default = "/subscriptions/aff2c340-2ecc-404c-8fc1-d86773973e78/resourceGroups/plaz-witcher-dev-rg/providers/Microsoft.Compute/images/UbuntuImage-2019-10-04T21-14-03Z"
}

variable "tenant_id" {}

