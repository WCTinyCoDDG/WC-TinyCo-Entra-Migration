# variables.tf
# This file defines all the input variables Terraform needs to connect to Azure.
# Think of it as the "settings panel" — no resources are created here.
# The actual values are stored in terraform.tfvars (which never goes to GitHub).

variable "tenant_id" {
  description = "The unique ID of your Azure/Entra tenant (TinyCoDDG)"
  type        = string
}

variable "subscription_id" {
  description = "The Azure subscription ID where resources will be created"
  type        = string
}

variable "admin_password" {
  description = "Default password assigned to all TinyCo user accounts"
  type        = string
  sensitive   = true
}