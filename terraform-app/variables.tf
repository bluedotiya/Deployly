variable "resource_group_location" {
  type        = string
  default     = "israelcentral"
  description = "Location of the resource group."
}

variable "resource_group_name_prefix" {
  type        = string
  default     = "rg"
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

variable "username" {
  type        = string
  description = "The username for the local account that will be created on the new VM."
  default     = "azureadmin"
}

variable public_ip_name {
  type        = string
  default     = "public-ip-01"
  description = "Name of the Public IP."
}