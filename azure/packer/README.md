# Build an Azure machine image with Packer

[Packer](https://www.packer.io/intro/index.html) is HashiCorp's open source tool 
for creating identical machine images for multiple platforms from a single 
source configuration. The Terraform templates included in this repo reference a 
publicly avaialble Amazon machine image (AMI) by default. The Packer build 
configuration used to create the public AMI is included [here](./packer.json). 
If you wish to customize it and build your own private AMI, follow the 
instructions below.

## Pre-requisites

See the pre-requisites listed [here](../../README.md). If you did not use the 
included `Vagrantfile` to bootstrap a staging environment, you will need to 
[install Packer](https://www.packer.io/intro/getting-started/install.html).

Set environment variables for your Azure credentials if you haven't already:

```bash
$ export ARM_CLIENT_ID=[]
$ export ARM_CLIENT_SECRET=[]
$ export ARM_SUBSCRIPTION_ID=[]
$ export ARM_TENANT_ID=[]
$ export ARM_LOCATION=[]
$ export IMAGE_RESOURCE_GROUP=[]
```

After you make your modifications to `packer.json`, execute the following 
command to build the image:

```bash
$ packer build packer.json
```

The `ManagedImageId` should output to the console. Or if the packer.json has the post processor configured to output manifest.json file, you can get the image ID from the manifest.

Don't forget to copy the `ManagedImageId` to your [terraform.tfvars file](../env/us-east/terraform.tfvars).
