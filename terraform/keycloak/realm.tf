resource "keycloak_realm" "hdc" {
  realm        = var.realm_name
  display_name = "Pilot HDC OVH"
  enabled      = true

  login_theme = "keycloak"

  # Login settings
  login_with_email_allowed = true
  reset_password_allowed   = true
  remember_me              = true
  verify_email             = false
  registration_allowed     = false
  edit_username_allowed    = false

  # UMA
  user_managed_access = true

  security_defenses {
    brute_force_detection {
      permanent_lockout                = false
      failure_reset_time_seconds       = 43200 # 12h
      max_login_failures               = 5
      max_failure_wait_seconds         = 900 # 15min
      minimum_quick_login_wait_seconds = 60
      quick_login_check_milli_seconds  = 1000
      wait_increment_seconds           = 60
    }
  }
}

resource "keycloak_realm_events" "hdc" {
  realm_id = keycloak_realm.hdc.id

  events_enabled    = true
  events_expiration = 2592000 # 30 days

  admin_events_enabled         = true
  admin_events_details_enabled = true

  events_listeners = [
    "jboss-logging",
    "last-login",
  ]
}
