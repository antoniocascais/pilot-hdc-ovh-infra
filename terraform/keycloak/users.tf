resource "keycloak_user" "admin" {
  count = var.create_test_user ? 1 : 0

  realm_id       = keycloak_realm.hdc.id
  username       = var.test_admin_username
  enabled        = true
  email_verified = true
  email          = "${var.test_admin_username}@${var.domain}"
  first_name     = "Test"
  last_name      = "Admin"

  initial_password {
    value     = var.test_admin_password
    temporary = false
  }
}

resource "keycloak_user_roles" "admin_roles" {
  count = var.create_test_user ? 1 : 0

  realm_id = keycloak_realm.hdc.id
  user_id  = keycloak_user.admin[0].id

  role_ids = [
    keycloak_role.platform_admin.id,
    keycloak_role.admin_role.id,
    data.keycloak_role.offline_access.id,
  ]
}
