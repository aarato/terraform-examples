provider "azurerm" {
  features {}
  subscription_id                   = var.ARM_SUBSCRIPTION_ID
  resource_provider_registrations  = "none"
}

# Existing variables...
# set TF_VAR_ARM_SUBSCRIPTION_ID="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
# $env:TF_VAR_ARM_SUBSCRIPTION_ID = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
# export TF_VAR_ARM_SUBSCRIPTION_ID="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
variable "ARM_SUBSCRIPTION_ID" {
  type = string
}

variable "vm_names" {
  type    = list(string)
  default = ["ubuntu1", "ubuntu2"]
}

variable "vnet_names" {
  type    = list(string)
  default = ["vnet-ubuntu1", "vnet-ubuntu2"]
}

variable "subnet_names" {
  type    = list(string)
  default = ["subnet-ubuntu1", "subnet-ubuntu2"]
}

# NEW: Parameterize VNET address spaces
variable "vnet_address_spaces" {
  type = list(string)
  default = [
    "172.29.0.0/23",
    "172.29.2.0/23",
  ]
}

# NEW: Parameterize Subnet address prefixes
variable "subnet_prefixes" {
  type = list(string)
  default = [
    "172.29.1.0/24",
    "172.29.2.0/24",
  ]
}




# Reference an existing resource group
data "azurerm_resource_group" "rg" {
  name = "RG_2128_Aarato_2" # Replace with your existing resource group name
}

# Reference an existing SSH key in the resource group
data "azurerm_ssh_public_key" "ssh_key" {
  name                = "mysshkey" # Replace with your existing SSH key name
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Create VNETs for each VM
resource "azurerm_virtual_network" "vnet" {
  count               = length(var.vm_names)
  name                = var.vnet_names[count.index]
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  # Use parameterized address space from var.vnet_address_spaces
  address_space = [var.vnet_address_spaces[count.index]]
}

# Create subnet in each VNET
resource "azurerm_subnet" "subnet" {
  count                = length(var.vm_names)
  name                 = var.subnet_names[count.index]
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet[count.index].name

  # Use parameterized subnet prefix from var.subnet_prefixes
  address_prefixes = [var.subnet_prefixes[count.index]]
}

resource "azurerm_public_ip" "public_ip" {
  count               = length(var.vm_names)
  name                = "public-ip-${var.vm_names[count.index]}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic_with_public_ip" {
  count               = length(var.vm_names)
  name                = "nic-${var.vm_names[count.index]}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet[count.index].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip[count.index].id
  }
}

# Create NSG for each VM
resource "azurerm_network_security_group" "nsg" {
  count               = length(var.vm_names)
  name                = "nsg-${var.vm_names[count.index]}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "HTTP"
    priority                   = 998
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "HTTPS"
    priority                   = 999
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "IPSEC-IKE-NATT"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_ranges    = ["500", "4500"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "IPSEC-ESP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Esp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  count               = length(var.vm_names)
  name                = var.vm_names[count.index]
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = "Standard_B1ls"
  admin_username      = "ubuntu"

  network_interface_ids = [
    azurerm_network_interface.nic_with_public_ip[count.index].id,
  ]

  admin_ssh_key {
    username   = "ubuntu"
    public_key = data.azurerm_ssh_public_key.ssh_key.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_association" {
  count                     = length(var.vm_names)
  network_interface_id      = azurerm_network_interface.nic_with_public_ip[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg[count.index].id
}

output "vm_public_ips" {
  description = "The public IP addresses of the Ubuntu VMs"
  value = {
    for idx, ip in azurerm_public_ip.public_ip : var.vm_names[idx] => ip.ip_address
  }
}

output "vnet_addresses" {
  description = "The address spaces of the VNETs"
  value = {
    for idx, vnet in azurerm_virtual_network.vnet : var.vnet_names[idx] => vnet.address_space
  }
}
