
# Creating Subnet for Vault managment 
resource "azurerm_subnet" "key_vault_subnet" {
  name                 = "key_vault_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.rg.name
  address_prefixes     = ["10.0.2.0/24"]
}

# association subnet with NGS 
resource "azurerm_subnet_network_security_group_association" "key_vault_subnet_ngs_association" {
  subnet_id                 = azurerm_subnet.key_vault_subnet.id
  network_security_group_id = azurerm_network_security_group.general_https_nsg.id
}

resource "azurerm_private_endpoint" "key_vault_private_endpoint" {
  name                = "key-vault-private-endpoint"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.key_vault_subnet.id

  private_service_connection {
    name                           = "key-vault-managment"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_key_vault.production_key_vault.id
    subresource_names              = ["vault"]
  }
}

resource "azurerm_key_vault" "production_key_vault" {
  name                          = "key-vault"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  public_network_access_enabled = false # Disable public access for the key-vault
  network_acls {
    default_action              = "Deny"
    bypass                      = "AzureServices"
  }
}

resource "azurerm_key_vault_access_policy" "client" {
  key_vault_id = azurerm_key_vault.production_key_vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions    = ["Get", "Create", "Delete", "List", "Restore", "Recover", "UnwrapKey", "WrapKey", "Purge", "Encrypt", "Decrypt", "Sign", "Verify"]
  secret_permissions = ["Get"]
}

resource "azurerm_key_vault_key" "vault_key" {
  name         = "tfex-key"
  key_vault_id = azurerm_key_vault.production_key_vault.id
  key_type     = "RSA-HSM" # A bit overkill but this makes sure we are FIPS 140-3, useful when dealing with US Goverment or Cyeraware customers
  key_size     = 2048
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]
  expiration_date = "P90D"

  rotation_policy {
    automatic {
      time_before_expiry = "P30D" # Rotate key 30 days before expirey 
    }

    expire_after         = "P90D" # Expire after 90 days
    notify_before_expiry = "P29D" # Notify 29 days before expire
  }


  depends_on = [
    azurerm_key_vault_access_policy.client
  ]
}
