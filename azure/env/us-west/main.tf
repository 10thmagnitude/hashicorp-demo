#main.tf inorder to deploy images using packer into Azure
variable location {
    description = "The Azure Location to deploy the resources."
    default ="westus"
}

variable "server_count" {
    description = "how many servers to deploy with the packer image"
    default = 3
}

provider "azurerm" {
    version = "=1.34.0"
}

module "hashistack" {
  source = "../../modules/hashistack"
  
  vm_count = "${var.server_count}"
  location = "${var.location}"
  vm_size = "Standard_DS1_v2"
  image_id = "/subscriptions/aff2c340-2ecc-404c-8fc1-d86773973e78/resourceGroups/plaz-witcher-dev-rg/providers/Microsoft.Compute/images/MyUbuntuImage-03"
  resource_group_name = "avengers_demo_group"
  name_prefix = "Avengers"

}