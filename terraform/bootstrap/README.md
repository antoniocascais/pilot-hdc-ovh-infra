# Terraform State Backend Bootstrap

> **WARNING**: Never commit `terraform.tfstate` or `*.tfvars` files. They contain sensitive data.

This directory provisions the S3 bucket and credentials used to store Terraform state
for the main infrastructure (dev/prod environments).

## Why a separate bootstrap?

Chicken-and-egg problem: the S3 bucket must exist BEFORE we can use it as a backend.
This bootstrap config uses **local state** (stays here forever) to create:

- S3 bucket with versioning (for state recovery)
- Dedicated OVH user with least-privilege access
- S3 credentials scoped only to the tfstate bucket

The main infrastructure in `environments/dev/` and `environments/prod/` then uses
this bucket as their S3 backend.

## Usage

```bash
# Copy tfvars from parent dir; falls back to message if file doesn't exist
cp ../terraform.tfvars . 2>/dev/null || echo "Create terraform.tfvars with OVH credentials"

terraform init
terraform apply
terraform output -raw s3_access_key_id
terraform output -raw s3_secret_access_key
```

Store credentials securely (e.g., password manager, env vars for CI).

## Credentials (gopass)

```bash
# Store after bootstrap
gopass insert ebrains-dev/hdc/ovh/s3-tfstate/access-key-id <<< "$(terraform output -raw s3_access_key_id)"
gopass insert ebrains-dev/hdc/ovh/s3-tfstate/secret-access-key <<< "$(terraform output -raw s3_secret_access_key)"

# Use in other terraform roots
export AWS_ACCESS_KEY_ID=$(gopass show -o ebrains-dev/hdc/ovh/s3-tfstate/access-key-id)
export AWS_SECRET_ACCESS_KEY=$(gopass show -o ebrains-dev/hdc/ovh/s3-tfstate/secret-access-key)
```

## Optional: Backup Bootstrap State

The bootstrap state is stored locally. If lost, the S3 bucket and user become orphaned
(still exist but unmanaged by Terraform). Consider backing up after apply:

```bash
# Set AWS creds from terraform output first
export AWS_ACCESS_KEY_ID="$(terraform output -raw s3_access_key_id)"
export AWS_SECRET_ACCESS_KEY="$(terraform output -raw s3_secret_access_key)"

# Then backup the state file
aws s3 cp terraform.tfstate s3://pilot-hdc-tfstate/bootstrap/terraform.tfstate \
  --endpoint-url https://s3.de.io.cloud.ovh.net

# Restore if needed
aws s3 cp s3://pilot-hdc-tfstate/bootstrap/terraform.tfstate . \
  --endpoint-url https://s3.de.io.cloud.ovh.net
```
