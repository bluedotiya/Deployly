## Name declaration ##

resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = random_pet.rg_name.id
}

# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

## Networking Configuration ##

# Create virtual network
resource "azurerm_virtual_network" "production_network" {
  name                = "Production-Virtual-Network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create webapp subnet
resource "azurerm_subnet" "web_app_subnet" {
  name                 = "Web-App-Subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.production_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "general_https_nsg" {
  name                = "Resource-Group-NSG-Internal"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "HTTPS"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }
}

# association subnet with NGS 
resource "azurerm_subnet_network_security_group_association" "subnet_ngs_association" {
  subnet_id                 = azurerm_subnet.web_app_subnet.id
  network_security_group_id = azurerm_network_security_group.general_https_nsg.id
}


# Create network interface
resource "azurerm_network_interface" "webserver_nic1" {
  name                = "NIC1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "dhcp_web_app_lan"
    subnet_id                     = azurerm_subnet.web_app_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Associate Network Interface to the Backend Pool of the Load Balancer
resource "azurerm_network_interface_backend_address_pool_association" "nic_lb_pool" {
  network_interface_id    = azurerm_network_interface.webserver_nic1.id
  ip_configuration_name   = "ipconfig-1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_backend_pool.id
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "nic_ngs_associator" {
  network_interface_id      = azurerm_network_interface.webserver_nic1.id
  network_security_group_id = azurerm_network_security_group.general_https_nsg.id
}

# Creating PSC from Webserver to storage account blob storage
resource "azurerm_private_endpoint" "vm_to_storage_account" {
  name                 = "webserver_blob_storage_account_PSC"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  subnet_id            = azurerm_subnet.web_app_subnet.id

  private_service_connection {
    name                           = "webapp_psc"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.main_storage_account.id
    subresource_names              = ["blob"]
  }
}

# Create Public Application Gateway
# Local block for variables reusage
locals {
  backend_address_pool_name      = "${azurerm_virtual_network.production_network.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.production_network.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.production_network.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.production_network.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.production_network.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.production_network.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.production_network.name}-rdrcfg"
}

# Create Public IP
resource "azurerm_public_ip" "app_gateway_public_ip" {
  name                = var.public_ip_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create application gateway
resource "azurerm_application_gateway" "network" {
  name                = "webserver-app-gateway"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku {
    name     = "WAF_Medium"
    tier     = "WAF_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway-webapp-ip-configuration"
    subnet_id = azurerm_subnet.web_app_subnet.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 443
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.app_gateway_public_ip.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/my-beautiful-frontend/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    priority                   = 9
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }

}

## Storage Configuration ##


# Create storage account for boot diagnostics
resource "azurerm_storage_account" "main_storage_account" {
  name                            = "diag${random_id.random_id.hex}"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  account_tier                    = "Standard"
  account_replication_type        = "GRS" # Changed replication to Geo-redundant storage to ensure high availablity
  local_user_enabled              = false # Disabled local users in favor of Manganged identity if usecase arises
  public_network_access_enabled   = false # CKV_AZURE_59 - Disable public access to storage account
  allow_nested_items_to_be_public = false # CKV_AZURE_190 - Block blob public access
  shared_access_key_enabled       = false # CKV2_AZURE_40 - Check
  min_tls_version                 = "TLS1_2" # Explicitly mark TLS Version to 1.2

  identity {
    type = "SystemAssigned"
  }

  sas_policy { # SAS Tokens experation date, after 90 days it will automatically be revoked
    expiration_period = "90.00:00:00"
    expiration_action = "Log"
  }

  blob_properties { # Keep deleted blobs for 7 days, protects againest accidental deletion
    delete_retention_policy {
      days = 7
    }
  }
}

# Creating storage account queue retension and logging
resource "azurerm_storage_account_queue_properties" "logging_properties" {
  storage_account_id = azurerm_storage_account.main_storage_account.id

  logging {
    version               = "1.0"
    delete                = true
    read                  = true
    write                 = true
    retention_policy_days = 7
  }

  hour_metrics {
    version               = "1.0"
    retention_policy_days = 7
  }

  minute_metrics {
    version               = "1.0"
    retention_policy_days = 7
  }
}



## Virutal machine configuration ##

# Create virtual machine
resource "azurerm_linux_virtual_machine" "linux_vm" {
  name                       = "webserver"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  network_interface_ids      = [azurerm_network_interface.webserver_nic1.id]
  size                       = "Standard_D2_v4"
  allow_extension_operations = false # CKV_AZURE_50 - Disabled extensions that can potetically introduce configuration changes post deployment

  os_disk {
    name                 = "Linux_OS_Disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name  = "webserver"
  admin_username = var.username

  admin_ssh_key {
    username   = var.username
    public_key = file("~/.ssh/id_rsa.pub")
  }


  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.main_storage_account.primary_blob_endpoint
  }
}