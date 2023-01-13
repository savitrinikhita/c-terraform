resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "eastus"
}

resource "azurerm_virtual_network" "example" {
  name                = "example-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet" "example" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "host_public_ip" {
  name                = "vm-publicip"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  allocation_method   = "Static"
  sku = "Standard"
  #domain_name_label = "app1-vm-${random_string.myrandom.id}"
}

resource "azurerm_network_interface" "example" {
  name                = "example-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.host_public_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "example" {
  name                = "example-machine"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_D2s_v3"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("/var/lib/jenkins/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "20.04.202209200"
  }
}


resource "azurerm_subnet" "websubnet" {
  name                 = "example-${var.web_subnet_name}"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = var.web_subnet_address
}

##we will create an nsg --nsg need to be attached with your subnet
resource "azurerm_network_security_group" "web_subnet_nsg" {
  name                = "${var.web_subnet_name}-nsg"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

#the top level nsg we will assoicate with subnet
resource "azurerm_subnet_network_security_group_association" "web_subnet_nsg_associate" {
    depends_on = [
      azurerm_network_security_rule.web_nsg_rule_inbound
    ]
  subnet_id                 = azurerm_subnet.example.id
  network_security_group_id = azurerm_network_security_group.web_subnet_nsg.id
}
locals {
  web_inbound_port = {
  "110":"80",
  "120":"443",
  "130":"22"
  }
}
resource "azurerm_network_security_rule" "web_nsg_rule_inbound" {
  for_each = local.web_inbound_port
  name                        = "Rule-Port-${each.value}"
  priority                    = each.key
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = each.value
  source_address_prefix       = "4.246.213.176"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.example.name
  network_security_group_name = azurerm_network_security_group.web_subnet_nsg.name
}
