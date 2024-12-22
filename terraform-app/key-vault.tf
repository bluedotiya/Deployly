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
