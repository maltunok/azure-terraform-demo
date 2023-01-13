terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "mts-rg" {
  name     = "demo-rg"
  location = "West Europe"
  tags = {
    env = "dev"
  }
}

resource "azurerm_virtual_network" "mts-vn" {
  name                = "demo-vn"
  resource_group_name = azurerm_resource_group.mts-rg.name
  location            = azurerm_resource_group.mts-rg.location
  address_space       = ["10.123.0.0/16"]

  tags = {
    "env" = "dev"
  }
}

resource "azurerm_subnet" "mts-subnet" {
  name                 = "demo-subnet"
  resource_group_name  = azurerm_resource_group.mts-rg.name
  virtual_network_name = azurerm_virtual_network.mts-vn.name
  address_prefixes     = ["10.123.1.0/24"]
}

resource "azurerm_network_security_group" "mts-nsg" {
  name                = "demo-nsg"
  location            = azurerm_resource_group.mts-rg.location
  resource_group_name = azurerm_resource_group.mts-rg.name

  tags = {
    "env" = "dev"
  }
}

resource "azurerm_network_security_rule" "mts-dev-nsr" {
  name                        = "mts-dev-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.mts-rg.name
  network_security_group_name = azurerm_network_security_group.mts-nsg.name
}

resource "azurerm_subnet_network_security_group_association" "mts-association" {
  subnet_id                 = azurerm_subnet.mts-subnet.id
  network_security_group_id = azurerm_network_security_group.mts-nsg.id
}

resource "azurerm_public_ip" "mts-ip" {
  name                = "mts-public-ip"
  resource_group_name = azurerm_resource_group.mts-rg.name
  location            = azurerm_resource_group.mts-rg.location
  allocation_method   = "Dynamic"

  tags = {
    env = "dev"
  }
}

resource "azurerm_network_interface" "mts-nic" {
  name                = "mts-nic"
  location            = azurerm_resource_group.mts-rg.location
  resource_group_name = azurerm_resource_group.mts-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mts-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mts-ip.id
  }

  tags = {
    "env" = "dev"
  }
}

resource "azurerm_linux_virtual_machine" "mts-vm" {
  name                = "mts-vm"
  resource_group_name = azurerm_resource_group.mts-rg.name
  location            = azurerm_resource_group.mts-rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.mts-nic.id
  ]

  custom_data = filebase64("customdata.tpl")
  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/mtsazurekey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

data "azurerm_public_ip" "mts-ip-data" {
  name = azurerm_public_ip.mts-ip.name
  resource_group_name = azurerm_resource_group.mts-rg.name
}
output "public_ip_address" {
  value = "${azurerm_linux_virtual_machine.mts-vm.name}: ${data.azurerm_public_ip.mts-ip-data.ip_address}"
}