variable "domain" {
  description = "Base domain (e.g. dev.hdc.ebrains.eu)"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env must be dev or prod"
  }
}

variable "realm_name" {
  type    = string
  default = "hdc"
}

variable "keycloak_admin_user" {
  type      = string
  sensitive = true
}

variable "keycloak_admin_password" {
  type      = string
  sensitive = true
}

variable "keycloak_url" {
  description = "Keycloak base URL (e.g. https://iam.dev.hdc.ebrains.eu)"
  type        = string
}

variable "test_admin_username" {
  type    = string
  default = "testadmin"
}

variable "test_admin_password" {
  type      = string
  sensitive = true
}

variable "create_test_user" {
  description = "Create test admin user (dev only)"
  type        = bool
  default     = false
}

variable "enable_direct_grants" {
  description = "Enable ROPC/direct access grants on public client (dev only, for automation)"
  type        = bool
  default     = false
}

check "no_direct_grants_in_prod" {
  assert {
    condition     = !(var.enable_direct_grants && var.env == "prod")
    error_message = "enable_direct_grants cannot be true in prod"
  }
}

check "no_test_user_in_prod" {
  assert {
    condition     = !(var.create_test_user && var.env == "prod")
    error_message = "create_test_user cannot be true in prod"
  }
}
