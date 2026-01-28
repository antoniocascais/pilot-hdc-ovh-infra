# Keycloak Realm Terraform

Manages Keycloak realm configuration for Pilot HDC OVH.

## Resources

- **Realm**: `hdc` with brute force detection, UMA, email login
- **Realm Events**: 30-day retention, admin events enabled
- **Roles**: `platform-admin`, `admin-role` (composites with `offline_access`)
- **Client Scopes**: `groups`, `username`, `openid`
- **Client**: `react-app` (PUBLIC SPA client)
- **Test User**: `testadmin` (dev only)

## Usage

```bash
# Set S3 creds (from gopass)
export AWS_ACCESS_KEY_ID=$(gopass show -o ebrains-dev/hdc/ovh/s3-tfstate/access-key-id)
export AWS_SECRET_ACCESS_KEY=$(gopass show -o ebrains-dev/hdc/ovh/s3-tfstate/secret-access-key)

# Init, plan, apply
./run.sh dev init
./run.sh dev plan
./run.sh dev apply
```

Or via Makefile from repo root:
```bash
make init-keycloak ENV=dev
make plan-keycloak ENV=dev
make apply-keycloak ENV=dev
```

## Configuration

Copy example files and fill in values:
```bash
cp config/base.tfvars.example config/base.tfvars
cp config/dev/terraform.tfvars.example config/dev/terraform.tfvars
```

### Required Variables

| Variable | File | Description |
|----------|------|-------------|
| `realm_name` | `base.tfvars` | Realm name (default: `hdc`) |
| `env` | `dev/terraform.tfvars` | Environment: `dev` or `prod` |
| `domain` | `dev/terraform.tfvars` | Base domain (e.g., `dev.hdc.ebrains.eu`) |
| `keycloak_url` | `dev/terraform.tfvars` | Keycloak URL (e.g., `https://iam.dev.hdc.ebrains.eu`) |
| `keycloak_admin_user` | `dev/terraform.tfvars` | Keycloak admin username (sensitive) |
| `keycloak_admin_password` | `dev/terraform.tfvars` | Keycloak admin password (sensitive) |
| `test_admin_password` | `dev/terraform.tfvars` | Test user password (sensitive, dev only) |

### Credentials (gopass)

```
ebrains-dev/hdc/ovh/
├── keycloak-admin/
│   ├── password
│   └── username
├── keycloak-test-admin-password
├── s3-tfstate/
│   ├── access-key-id
│   └── secret-access-key
└── vault-unseal-keys
```

### Dev-Only Flags

| Variable | Default | Purpose |
|----------|---------|---------|
| `create_test_user` | `false` | Creates `testadmin` user for dev/CI smoke tests |
| `enable_direct_grants` | `false` | Enables ROPC (password grant) for automation (Cypress, API tests) |

These are blocked in prod via `check` block. Set `true` only in `config/dev/terraform.tfvars`.

## Security Notes

### Proxy Trust (IP/Host Mappers)

The `react-app` client includes session note mappers that inject `clientId`, `clientAddress`, and `clientHost` into tokens. This is used for MinIO audit trails.

**Requirements:**
- Keycloak must be behind a trusted reverse proxy (nginx ingress)
- Proxy must set `X-Forwarded-For`, `X-Forwarded-Host` headers
- Keycloak helm values must include `proxy: edge`
- Only trust these claims from your own infrastructure

### Custom `openid` Scope

A custom `openid` client scope is created to match CSCS pattern. The built-in Keycloak `openid` scope doesn't include certain token claims by default.

### Test User in State

When `create_test_user = true`, the `initial_password` value is stored in Terraform state (S3 backend). Mitigations:
- `temporary = true` — user must change password on first login
- Blocked in prod via `check` block
- S3 backend with server-side encryption
- Bucket ACLs restricted to authorized principals

## Provider

Uses `mrparkers/keycloak` provider v4.1.0 (pinned). Note: this provider is EOL; `keycloak/keycloak` 5.x is the successor. Migration planned for later.
