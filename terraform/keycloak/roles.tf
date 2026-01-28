# Built-in roles
data "keycloak_role" "offline_access" {
  realm_id = keycloak_realm.hdc.id
  name     = "offline_access"
}

# Custom roles
resource "keycloak_role" "platform_admin" {
  realm_id    = keycloak_realm.hdc.id
  name        = "platform-admin"
  description = "Platform administrator"
  composite_roles = [
    data.keycloak_role.offline_access.id,
  ]
}

resource "keycloak_role" "admin_role" {
  realm_id    = keycloak_realm.hdc.id
  name        = "admin-role"
  description = "Admin role"
  composite_roles = [
    data.keycloak_role.offline_access.id,
  ]
}
