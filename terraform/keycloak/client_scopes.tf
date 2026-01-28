resource "keycloak_openid_client_scope" "groups" {
  realm_id               = keycloak_realm.hdc.id
  name                   = "groups"
  consent_screen_text    = ""
  include_in_token_scope = true
}

resource "keycloak_openid_group_membership_protocol_mapper" "group" {
  realm_id        = keycloak_realm.hdc.id
  client_scope_id = keycloak_openid_client_scope.groups.id
  name            = "group"
  claim_name      = "group"
}

resource "keycloak_openid_client_scope" "username" {
  realm_id               = keycloak_realm.hdc.id
  name                   = "username"
  consent_screen_text    = ""
  include_in_token_scope = true
}

resource "keycloak_openid_user_property_protocol_mapper" "username" {
  realm_id        = keycloak_realm.hdc.id
  client_scope_id = keycloak_openid_client_scope.username.id
  name            = "username"
  user_property   = "username"
  claim_name      = "preferred_username"
}

resource "keycloak_openid_client_scope" "openid" {
  # Custom scope matching CSCS pattern — built-in openid doesn't include token claim
  realm_id               = keycloak_realm.hdc.id
  name                   = "openid"
  consent_screen_text    = ""
  include_in_token_scope = true
}
