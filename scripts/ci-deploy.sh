#!/bin/bash
set -euo pipefail

# CI deploy helper — runs plan + apply for a single TF module
# Usage: ./scripts/ci-deploy.sh <module> <env>
#   module: infra | keycloak
#   env: dev | prod

module=${1:?Usage: $0 <module> <env>}
env=${2:?Usage: $0 <module> <env>}

case "$module" in
    infra)    dir="terraform" ;;
    keycloak) dir="terraform/keycloak" ;;
    *)
        echo "Unknown module: $module (expected: infra, keycloak)"
        exit 1
        ;;
esac

if [[ ! "$env" =~ ^(dev|prod)$ ]]; then
    echo "Unknown env: $env (expected: dev, prod)"
    exit 1
fi

cd "$dir"
./run.sh "$env" plan
./run.sh "$env" apply
