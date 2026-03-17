output "realm_id" {
  value = keycloak_realm.hdc.id
}

output "react_app_client_id" {
  value = keycloak_openid_client.react_app.client_id
}

output "kong_client_id" {
  value = keycloak_openid_client.kong.client_id
}

output "kong_client_secret" {
  value     = keycloak_openid_client.kong.client_secret
  sensitive = true
}

output "realm_rsa_public_key" {
  description = "RSA public key (base64 PEM) for JWT verification by HDC services"
  value       = data.keycloak_realm_keys.hdc.keys[0].public_key
}

output "xwiki_client_secret" {
  value     = keycloak_openid_client.xwiki.client_secret
  sensitive = true
}

output "guacamole_client_secrets" {
  description = "Per-project Guacamole client secrets (for Vault)"
  value       = { for p in var.workspace_projects : p => keycloak_openid_client.guacamole[p].client_secret }
  sensitive   = true
}
