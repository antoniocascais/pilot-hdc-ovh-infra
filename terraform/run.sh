#!/bin/bash
set -e

TMPFILES=()
cleanup() { rm -f "${TMPFILES[@]}"; }
trap cleanup EXIT

decrypt_var_file() {
    local src="$1" tmp
    tmp=$(mktemp)
    sops -d --input-type dotenv --output-type dotenv "$src" > "$tmp" || { echo "Failed to decrypt $src"; exit 1; }
    TMPFILES+=("$tmp")
    echo "$tmp"
}

env=${1:-dev}
action=${2:-plan}

if [[ ! "$env" =~ ^(dev|prod)$ ]]; then
    echo "Usage: $0 [dev|prod] [plan|apply|init]"
    exit 1
fi

# Check required files exist (fail early for fresh clones)
[[ -f "config/$env/backend.tfbackend" ]] || { echo "Missing config/$env/backend.tfbackend"; exit 1; }
if [[ "$action" != "init" ]]; then
    [[ -f config/base.tfvars ]] || { echo "Missing config/base.tfvars"; exit 1; }
    [[ -f "config/$env/terraform.tfvars" ]] || { echo "Missing config/$env/terraform.tfvars"; exit 1; }
    [[ -f config/credentials.tfvars ]] || { echo "Missing config/credentials.tfvars"; exit 1; }
fi
# Require S3 credentials
: "${AWS_ACCESS_KEY_ID:?Set AWS_ACCESS_KEY_ID from bootstrap output}"
: "${AWS_SECRET_ACCESS_KEY:?Set AWS_SECRET_ACCESS_KEY from bootstrap output}"

case "$action" in
    init)
        terraform init -backend-config="config/$env/backend.tfbackend" -reconfigure
        ;;
    plan)
        terraform init -backend-config="config/$env/backend.tfbackend" -reconfigure
        base=$(decrypt_var_file config/base.tfvars)
        env_vars=$(decrypt_var_file "config/$env/terraform.tfvars")
        creds=$(decrypt_var_file config/credentials.tfvars)
        terraform plan \
            -var-file="$base" \
            -var-file="$env_vars" \
            -var-file="$creds" \
            -out="deploy-$env.tfplan"
        ;;
    apply)
        [[ -f "deploy-$env.tfplan" ]] || { echo "No deploy-$env.tfplan. Run '$0 $env plan' first."; exit 1; }
        terraform apply "deploy-$env.tfplan"
        ;;
    *)
        echo "Unknown action: $action"
        echo "Usage: $0 [dev|prod] [plan|apply|init]"
        exit 1
        ;;
esac
