terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "2.44.0"
    }
  }
}


provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "ubuntu" {
  name     = "ubuntu-resources"
  location = var.region
}

resource "azurerm_virtual_network" "ubuntu" {
  name                = "ubuntu-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.ubuntu.location
  resource_group_name = azurerm_resource_group.ubuntu.name
}

resource "azurerm_subnet" "ubuntu" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.ubuntu.name
  virtual_network_name = azurerm_virtual_network.ubuntu.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "ubuntu" {
  count = 2
  name                = "ubuntu-nic-${count.index}"
  location            = azurerm_resource_group.ubuntu.location
  resource_group_name = azurerm_resource_group.ubuntu.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.ubuntu.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ubuntu.*.id[count.index]
  }
}

resource "azurerm_linux_virtual_machine" "ubuntu" {
  count = 2
  name                = "ubuntu-machine-${count.index}"
  resource_group_name = azurerm_resource_group.ubuntu.name
  location            = azurerm_resource_group.ubuntu.location
  size                = "Standard_ds1_v2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.ubuntu.*.id[count.index],
  ]
  
  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.vm_os_publisher
    offer     = var.vm_os_offer
    sku       = var.vm_os_sku
    version   = var.vm_os_version
  }

}

resource "azurerm_public_ip" "ubuntu" {
  count               = 2
  name                = "ubuntu0001publicip-${count.index}"
  resource_group_name = azurerm_resource_group.ubuntu.name
  location            = azurerm_resource_group.ubuntu.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_security_group" "ubuntu" {
  count               = 2
  name                = "ubuntu-security-group-${count.index}"
  location            = azurerm_resource_group.ubuntu.location
  resource_group_name = azurerm_resource_group.ubuntu.name

  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}
resource "azurerm_network_interface_security_group_association" "ubuntu" {
    count                     = 2
    network_interface_id      = azurerm_network_interface.ubuntu.*.id[count.index]
    network_security_group_id = azurerm_network_security_group.ubuntu.*.id[count.index]
}
