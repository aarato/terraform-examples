# Overview
Sets a sinle ubuntu virtual machines with customer VNet/Subnets. 

# Setup
1. Login via Azure CLI
2. Make sure you setup your environment variables for Azure Subscription ID, Resource Groupe and SSH key names.
```
# use set= (for windows cmd) or $env: (for powershell)
az account list --query "[].{Name:name, ID:id}" -o table
export TF_VAR_ARM_SUBSCRIPTION_ID="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
az group list --query "[].{Name:name}" -o table
export TF_VAR_ARM_RESOURCE_GROUP="My_Azure_Resource_Group_Name"
az sshkey list --query "[].{Name:name}" -o table
export TF_VAR_ARM_SSH_KEY="My_SSH_Key_Name"
```
3. Initialize and run terraform
```
terraform init
terraform apply
```

