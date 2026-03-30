# env var is passed via tfvars for consistency across modules
# but not yet referenced in kong resources
# TODO remove once kong is deployed to prod
rule "terraform_unused_declarations" {
  enabled = false
}
