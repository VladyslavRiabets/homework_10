provider "azurerm" {
  features {}
  subscription_id = "4461c28c-9e8b-494a-81f4-a4588f104448"
}

# Resource Group
resource "azurerm_resource_group" "example_rg" {
  name     = "example-resource-group"
  location = "West Europe"
}

# Availability Set
resource "azurerm_availability_set" "example_avset" {
  name                         = "example-availability-set"
  location                     = azurerm_resource_group.example_rg.location
  resource_group_name          = azurerm_resource_group.example_rg.name
  managed                      = true
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5
}

# Virtual Network
resource "azurerm_virtual_network" "example_vnet" {
  name                    = "example-vnet"
  location                = azurerm_resource_group.example_rg.location
  resource_group_name     = azurerm_resource_group.example_rg.name
  address_space           = ["10.0.0.0/16"]
}

# Subnet
resource "azurerm_subnet" "example_subnet" {
  name                   = "example-subnet"
  resource_group_name    = azurerm_resource_group.example_rg.name
  virtual_network_name   = azurerm_virtual_network.example_vnet.name
  address_prefixes       = ["10.0.1.0/24"]
}

# Public IP for LB
resource "azurerm_public_ip" "example_lb_public_ip" {
  name                    = "example-lb-public-ip"
  location                = azurerm_resource_group.example_rg.location
  resource_group_name     = azurerm_resource_group.example_rg.name
  allocation_method       = "Static"
  sku                     = "Standard"
}

# Load Balancer
resource "azurerm_lb" "example_lb" {
  name                    = "example-loadbalancer"
  location                = azurerm_resource_group.example_rg.location
  resource_group_name     = azurerm_resource_group.example_rg.name
  sku                     = "Standard"
  
  frontend_ip_configuration {
    name                    = "PublicIPAddress"
    public_ip_address_id    = azurerm_public_ip.example_lb_public_ip.id
  }
}

# Backend Address Pool for LB
resource "azurerm_lb_backend_address_pool" "example_backend_pool" {
  loadbalancer_id          = azurerm_lb.example_lb.id
  name                     = "backend-pool"
}

# Health Probe for LB
resource "azurerm_lb_probe" "example_probe" {
  loadbalancer_id          = azurerm_lb.example_lb.id
  name                     = "http-probe"
  protocol                 = "Tcp"
  port                     = 80
  interval_in_seconds      = 5
  number_of_probes         = 2
}

# LB Rule
resource "azurerm_lb_rule" "example_lb_rule" {
  loadbalancer_id                    = azurerm_lb.example_lb.id
  name                                = "http-rule"
  protocol                            = "Tcp"
  frontend_port                       = 80
  backend_port                        = 80
  frontend_ip_configuration_name     = "PublicIPAddress"
  backend_address_pool_ids           = [azurerm_lb_backend_address_pool.example_backend_pool.id]
  probe_id                            = azurerm_lb_probe.example_probe.id
}

# Network Interface
resource "azurerm_network_interface" "example_nic" {
  count                   = 2
  name                    = "example-nic-${count.index}"
  location                = azurerm_resource_group.example_rg.location
  resource_group_name     = azurerm_resource_group.example_rg.name
  
  ip_configuration {
    name                           = "internal"
    subnet_id                      = azurerm_subnet.example_subnet.id
    private_ip_address_allocation  = "Dynamic"
  }
}

# Associate each NIC with the Load Balancer Backend Pool
resource "azurerm_network_interface_backend_address_pool_association" "example_lb_nic_association" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.example_nic[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.example_backend_pool.id
}

# Virtual Machines
resource "azurerm_linux_virtual_machine" "example_vm" {
  count                   = 2
  name                    = "example-vm-${count.index}"
  location                = azurerm_resource_group.example_rg.location
  resource_group_name     = azurerm_resource_group.example_rg.name
  size                     = "Standard_B1s"
  disable_password_authentication = false
  admin_username          = "adminuser"
  admin_password          = "Terrahomework135712!"
  availability_set_id     = azurerm_availability_set.example_avset.id
  network_interface_ids   = [azurerm_network_interface.example_nic[count.index].id]

  os_disk {
    caching                = "ReadWrite"
    storage_account_type   = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# Output the Load Balancer Public IP
output "load_balancer_public_ip" {
  value = azurerm_public_ip.example_lb_public_ip.ip_address
}
