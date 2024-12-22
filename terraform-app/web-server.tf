
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

# Create CMK for main storage account
resource "azurerm_storage_account_customer_managed_key" "main_cmk" {
  storage_account_id = azurerm_storage_account.main_storage_account.id
  key_vault_id       = azurerm_key_vault.production_key_vault.id
  key_name           = azurerm_key_vault_key.vault_key.name
}


# Create webapp subnet
resource "azurerm_subnet" "web_app_subnet" {
  name                 = "Web-App-Subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.1.0/24"]
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
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "nic_ngs_associator" {
  network_interface_id      = azurerm_network_interface.webserver_nic1.id
  network_security_group_id = azurerm_network_security_group.general_https_nsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

# Creating PSC from Webserver to storage account blob storage
resource "azurerm_private_endpoint" "vm_to_storage_account" {
  name                 = "webserver_to_blob_storage_account"
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
    public_key = azapi_resource_action.ssh_public_key_gen.output.publicKey
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }
}