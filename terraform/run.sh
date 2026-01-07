#!/bin/bash
set -e

env=${1:-dev}
action=${2:-plan}

if [[ ! "$env" =~ ^(dev|prod)$ ]]; then
    echo "Usage: $0 [dev|prod] [plan|apply|init]"
    exit 1
fi

# Check tfvars exist (fail early for fresh clones)
[[ -f config/base.tfvars ]] || { echo "Missing config/base.tfvars - copy from config/base.tfvars.example"; exit 1; }
[[ -f "config/$env/terraform.tfvars" ]] || { echo "Missing config/$env/terraform.tfvars - copy from config/$env/terraform.tfvars.example"; exit 1; }
[[ -f "config/$env/backend.tfbackend" ]] || { echo "Missing config/$env/backend.tfbackend - ensure it exists before running terraform"; exit 1; }
# Require S3 credentials
: "${AWS_ACCESS_KEY_ID:?Set AWS_ACCESS_KEY_ID from bootstrap output}"
: "${AWS_SECRET_ACCESS_KEY:?Set AWS_SECRET_ACCESS_KEY from bootstrap output}"

case "$action" in
    init)
        terraform init -backend-config="config/$env/backend.tfbackend" -reconfigure
        ;;
    plan)
        terraform init -backend-config="config/$env/backend.tfbackend" -reconfigure
        terraform plan \
            -var-file=config/base.tfvars \
            -var-file="config/$env/terraform.tfvars" \
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
