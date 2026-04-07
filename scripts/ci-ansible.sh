#!/bin/bash
set -euo pipefail

# Usage: ./scripts/ci-ansible.sh <playbook> [extra-args...]
#   playbook: site | nfs | freeipa | guacamole

playbook=${1:?Usage: $0 <playbook> [extra-args...]}
shift

case "$playbook" in
    site)      pb="playbooks/site.yml" ;;
    nfs)       pb="playbooks/nfs-server.yml" ;;
    freeipa)   pb="playbooks/freeipa-server.yml" ;;
    guacamole) pb="playbooks/guacamole-vm.yml" ;;
    *)
        echo "Unknown playbook: $playbook (expected: site, nfs, freeipa, guacamole)"
        exit 1
        ;;
esac

# Provision SSH key from GH secret
: "${CI_SSH_PRIVATE_KEY:?Set CI_SSH_PRIVATE_KEY}"
SSH_KEY_FILE="${RUNNER_TEMP:-/tmp}/ssh_key"
printf '%s\n' "$CI_SSH_PRIVATE_KEY" > "$SSH_KEY_FILE"
chmod 600 "$SSH_KEY_FILE"
trap 'rm -f "$SSH_KEY_FILE"' EXIT INT TERM

./ansible/run.sh ansible-playbook "$pb" \
    -e "ssh_key_path=$SSH_KEY_FILE" \
    "$@"
