# react-app — public SPA client
resource "keycloak_openid_client" "react_app" {
  realm_id  = keycloak_realm.hdc.id
  client_id = "react-app"
  name      = "react-app"
  enabled   = true

  access_type                  = "PUBLIC"
  standard_flow_enabled        = true
  direct_access_grants_enabled = var.enable_direct_grants
  implicit_flow_enabled        = false

  valid_redirect_uris             = ["https://${var.domain}/*"]
  valid_post_logout_redirect_uris = ["+"]
  web_origins                     = ["https://${var.domain}"]
  base_url                        = "https://${var.domain}"
}

resource "keycloak_openid_client_default_scopes" "react_app" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.react_app.id

  default_scopes = [
    "profile",
    "email",
    "roles",
    "web-origins",
    keycloak_openid_client_scope.groups.name,
    keycloak_openid_client_scope.openid.name,
  ]
}

# Protocol mappers on react-app client

resource "keycloak_openid_user_attribute_protocol_mapper" "minio_policy" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.react_app.id
  name      = "minio_policy_mapper"

  user_attribute      = "policy"
  claim_name          = "policy"
  add_to_id_token     = true
  add_to_access_token = true
  add_to_userinfo     = true
  claim_value_type    = "String"
  multivalued         = false
}

resource "keycloak_openid_audience_protocol_mapper" "minio_aud" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.react_app.id
  name      = "aud_mapper"

  included_custom_audience = "minio"
  add_to_id_token          = false
  add_to_access_token      = true
}

resource "keycloak_openid_user_session_note_protocol_mapper" "client_id" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.react_app.id
  name      = "Client ID"

  session_note     = "clientId"
  claim_name       = "clientId"
  claim_value_type = "String"
}

resource "keycloak_openid_user_session_note_protocol_mapper" "client_ip" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.react_app.id
  name      = "Client IP Address"

  session_note     = "clientAddress"
  claim_name       = "clientAddress"
  claim_value_type = "String"
}

resource "keycloak_openid_user_session_note_protocol_mapper" "client_host" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.react_app.id
  name      = "Client Host"

  session_note     = "clientHost"
  claim_name       = "clientHost"
  claim_value_type = "String"
}

# --- CLI & File Transfer client (public, device auth flow) ---
resource "keycloak_openid_client" "cli" {
  realm_id  = keycloak_realm.hdc.id
  client_id = "cli"
  name      = "CLI & File Transfer"
  enabled   = true

  access_type                               = "PUBLIC"
  standard_flow_enabled                     = false
  direct_access_grants_enabled              = true
  implicit_flow_enabled                     = false
  oauth2_device_authorization_grant_enabled = true
  frontchannel_logout_enabled               = true
  full_scope_allowed                        = true
}

resource "keycloak_openid_client_default_scopes" "cli" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.cli.id

  default_scopes = [
    "profile",
    "email",
    "roles",
    "web-origins",
    "acr",
    keycloak_openid_client_scope.clb_wiki_read.name,
    keycloak_openid_client_scope.clb_wiki_write.name,
    keycloak_openid_client_scope.team.name,
  ]
}

resource "keycloak_openid_client_optional_scopes" "cli" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.cli.id

  optional_scopes = [
    "address",
    "phone",
    "offline_access",
    "microprofile-jwt",
  ]
}

# --- Kong API Gateway client (confidential) ---
# Used by auth service for Keycloak user management
# and by Kong for OIDC token introspection
resource "keycloak_openid_client" "kong" {
  realm_id  = keycloak_realm.hdc.id
  client_id = "kong"
  name      = "Kong API Gateway"
  enabled   = true

  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = true
  service_accounts_enabled     = true

  root_url            = "https://api.${var.domain}"
  valid_redirect_uris = ["https://api.${var.domain}/*"]
  web_origins         = ["https://api.${var.domain}"]
}

# Kong protocol mappers

resource "keycloak_openid_audience_protocol_mapper" "kong_aud_mapper" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.kong.id
  name      = "aud_mapper"

  included_custom_audience = "minio"
  add_to_id_token          = false
}

resource "keycloak_openid_user_attribute_protocol_mapper" "kong_minio_policy" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.kong.id
  name      = "minio_policy_mapper"

  user_attribute   = "policy"
  claim_name       = "policy"
  claim_value_type = "String"
}

resource "keycloak_openid_user_property_protocol_mapper" "kong_username_sub" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.kong.id
  name      = "user-property-mapper"

  user_property    = "username"
  claim_name       = "sub"
  claim_value_type = "String"
}

# Kong service account roles

resource "keycloak_openid_client_service_account_realm_role" "kong_offline_access" {
  realm_id                = keycloak_realm.hdc.id
  service_account_user_id = keycloak_openid_client.kong.service_account_user_id
  role                    = data.keycloak_role.offline_access.name
}

resource "keycloak_openid_client_service_account_realm_role" "kong_uma_authorization" {
  realm_id                = keycloak_realm.hdc.id
  service_account_user_id = keycloak_openid_client.kong.service_account_user_id
  role                    = data.keycloak_role.uma_authorization.name
}

resource "keycloak_openid_client_service_account_role" "kong_manage_realm" {
  realm_id                = keycloak_realm.hdc.id
  service_account_user_id = keycloak_openid_client.kong.service_account_user_id
  client_id               = data.keycloak_openid_client.realm_management.id
  role                    = "manage-realm"
}

resource "keycloak_openid_client_service_account_role" "kong_manage_users" {
  realm_id                = keycloak_realm.hdc.id
  service_account_user_id = keycloak_openid_client.kong.service_account_user_id
  client_id               = data.keycloak_openid_client.realm_management.id
  role                    = "manage-users"
}

# --- XWiki client (confidential, OIDC auth) ---
resource "keycloak_openid_client" "xwiki" {
  realm_id  = keycloak_realm.hdc.id
  client_id = "xwiki"
  name      = "XWiki"
  enabled   = true

  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  implicit_flow_enabled        = true
  direct_access_grants_enabled = true
  service_accounts_enabled     = true

  authorization {
    policy_enforcement_mode = "PERMISSIVE"
  }

  root_url                        = "https://xwiki.${var.domain}"
  base_url                        = "https://xwiki.${var.domain}"
  admin_url                       = "https://xwiki.${var.domain}"
  valid_redirect_uris             = ["https://xwiki.${var.domain}/*"]
  valid_post_logout_redirect_uris = ["+"]
  web_origins                     = ["https://xwiki.${var.domain}"]
}

resource "keycloak_openid_client_default_scopes" "xwiki" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.xwiki.id

  default_scopes = [
    "profile",
    "email",
    "roles",
    "web-origins",
    keycloak_openid_client_scope.groups.name,
    keycloak_openid_client_scope.openid.name,
    keycloak_openid_client_scope.username.name,
  ]
}

# XWiki dedicated scope mappers (User Session Note)

resource "keycloak_openid_user_session_note_protocol_mapper" "xwiki_client_id" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.xwiki.id
  name      = "Client ID"

  session_note     = "clientId"
  claim_name       = "clientId"
  claim_value_type = "String"
}

resource "keycloak_openid_user_session_note_protocol_mapper" "xwiki_client_ip" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.xwiki.id
  name      = "Client IP Address"

  session_note     = "clientAddress"
  claim_name       = "clientAddress"
  claim_value_type = "String"
}

resource "keycloak_openid_user_session_note_protocol_mapper" "xwiki_client_host" {
  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.xwiki.id
  name      = "Client Host"

  session_note     = "clientHost"
  claim_name       = "clientHost"
  claim_value_type = "String"
}

# --- Guacamole per-project clients (confidential, OIDC) ---

resource "keycloak_openid_client" "guacamole" {
  for_each = toset(var.workspace_projects)

  realm_id  = keycloak_realm.hdc.id
  client_id = "guacamole-${each.value}"
  name      = "Guacamole-${each.value}"
  enabled   = true

  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false
  service_accounts_enabled     = true
  implicit_flow_enabled        = false

  authorization {
    policy_enforcement_mode = "ENFORCING"
  }

  valid_redirect_uris = [
    "https://${var.domain}/workbench/${each.value}/guacamole/",
  ]
}

resource "keycloak_openid_client_default_scopes" "guacamole" {
  for_each = toset(var.workspace_projects)

  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.guacamole[each.value].id

  default_scopes = [
    "profile",
    "email",
    keycloak_openid_client_scope.groups.name,
    keycloak_openid_client_scope.openid.name,
    keycloak_openid_client_scope.username.name,
  ]
}

# Guacamole per-client protocol mappers

resource "keycloak_openid_user_property_protocol_mapper" "guacamole_username" {
  for_each = toset(var.workspace_projects)

  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.guacamole[each.value].id
  name      = "username mapper"

  user_property = "username"
  claim_name    = "username"
}

resource "keycloak_openid_user_property_protocol_mapper" "guacamole_email" {
  for_each = toset(var.workspace_projects)

  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.guacamole[each.value].id
  name      = "email mapper"

  user_property = "email"
  claim_name    = "email"
}

# service_accounts_enabled auto-creates these 3 — manage in TF to avoid drift

resource "keycloak_openid_user_session_note_protocol_mapper" "guacamole_client_id" {
  for_each = toset(var.workspace_projects)

  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.guacamole[each.value].id
  name      = "Client ID"

  session_note     = "clientId"
  claim_name       = "clientId"
  claim_value_type = "String"
}

resource "keycloak_openid_user_session_note_protocol_mapper" "guacamole_client_ip" {
  for_each = toset(var.workspace_projects)

  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.guacamole[each.value].id
  name      = "Client IP Address"

  session_note     = "clientAddress"
  claim_name       = "clientAddress"
  claim_value_type = "String"
}

resource "keycloak_openid_user_session_note_protocol_mapper" "guacamole_client_host" {
  for_each = toset(var.workspace_projects)

  realm_id  = keycloak_realm.hdc.id
  client_id = keycloak_openid_client.guacamole[each.value].id
  name      = "Client Host"

  session_note     = "clientHost"
  claim_name       = "clientHost"
  claim_value_type = "String"
}
