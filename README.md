# pilot-hdc-ovh-infra
This is a IaC repository that contains all the necessary code to setup the infrastructure that will run Pilot-HDC on OVH cloud.

## Manual steps
Before you try to run the terraform code, you'll need to do certain steps in OVH:

1) Create an apikey with the following permissions:
```
GET/POST/PUT/DELETE /cloud/project/*
```

2) Add the ssh key that will be used by default.

3) Create the floating ips that will be used by the nginx VMs.

## Documentation

| Doc                                          | Covers                                                               |
|----------------------------------------------|----------------------------------------------------------------------|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System architecture, data flows, component boundaries                |
| [docs/CICD.md](docs/CICD.md)                 | GitHub Actions workflows, secrets, what is / isn't automated         |
| [docs/NFS-SETUP.md](docs/NFS-SETUP.md)       | NFS server bring-up (RWX storage for K8s)                            |
| [docs/WORKBENCH-SETUP.md](docs/WORKBENCH-SETUP.md) | FreeIPA + Guacamole desktop VMs (identity + remote desktop)     |

## VM Services (quick reference)

Three VM services live outside `make ansible` because their playbooks are too disruptive for routine site runs (dist-upgrade + reboot + filesystem ops). Full runbooks in the docs above. Short version:

| Service                     | TF flags                                            | Bootstrap                                                  | Docs                                     |
|-----------------------------|-----------------------------------------------------|------------------------------------------------------------|------------------------------------------|
| **NFS** (RWX storage)       | `deploy_nfs`, `nfs_volume_size`                     | `make ansible-nfs EXTRA_ARGS="-l nfs-<env> -e ssh_port=22"`| [NFS-SETUP.md](docs/NFS-SETUP.md)        |
| **FreeIPA** (identity)      | `deploy_freeipa`, `freeipa_volume_size`             | `make ansible-freeipa EXTRA_ARGS="-l freeipa-<env> -e ssh_port=22"` | [WORKBENCH-SETUP.md](docs/WORKBENCH-SETUP.md) |
| **Guacamole** (desktop VMs) | `deploy_guacamole`, `workspace_projects`, image/flavor IDs | `make ansible-guacamole EXTRA_ARGS="-l guacamole-<project>-<env> -e ssh_port=22"` | [WORKBENCH-SETUP.md](docs/WORKBENCH-SETUP.md) |

Common pattern for all three:

1. Flip `deploy_*` in tfvars, `make plan-<env>` + `make apply-<env>`
2. **Attach the block volume** in OVH Console (TF can't attach pre-existing volumes)
3. Add VM IP to `ansible/vars/sensitive.yml`
4. First bootstrap run with `-e ssh_port=22` (VM still on default port)
5. Run `ssh-hardening.yml` last (dist-upgrade reboot can reset sshd port)
6. Subsequent runs use hardened port automatically

## Secret Management (SOPS + age)

Terraform variable files (`.tfvars`) and Ansible secrets (`ansible/vars/sensitive.yml`) are encrypted with [SOPS](https://github.com/getsops/sops) using [age](https://github.com/FiloSottile/age) and committed to git.

### Prerequisites

```bash
# macOS
brew install age sops pre-commit

# Ubuntu/Debian
sudo apt install age
# sops: download binary from https://github.com/getsops/sops/releases
# pre-commit: pip install pre-commit
```

### First-time setup (key holder)

1. Generate an age keypair:
   ```bash
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   ```
   Save the **public key** from the output (starts with `age1...`). Back up the private key file securely.
   SOPS auto-discovers keys at this path — no env var needed.

2. Add your public key to `.sops.yaml` at the repo root (create if missing):
   ```yaml
   creation_rules:
     - path_regex: '\.tfvars$'
       age: 'age1your-public-key-here'
   ```
   This tells SOPS which key to encrypt with. Without it, `sops -e` will fail.

### Adding a new team member

Add their `age1...` public key to `.sops.yaml` (comma-separated in the `age:` field), then re-encrypt all existing files so they can decrypt:
```bash
make sops-reencrypt
```
This requires your private key (existing recipient). Commit the updated `.sops.yaml` and re-encrypted tfvars together.

### First-time setup (existing key)

If a keypair already exists for this repo, get the private key from a team member via a secure channel (password manager, encrypted message, in-person) and place it at:
```bash
mkdir -p ~/.config/sops/age
# save the private key contents to keys.txt
```
SOPS auto-discovers the key at this path — decryption just works.

### After cloning

```bash
pre-commit install
```
This installs the pre-commit hook that blocks committing unencrypted secrets.

### Working with encrypted files

All `make` targets **auto-decrypt** on the fly — no manual decryption needed. Plaintext is written to tmpfiles and cleaned up on exit.

```bash
# Edit ansible secrets (YAML — opens in $EDITOR, re-encrypts on save)
sops ansible/vars/sensitive.yml

# Edit a tfvars file (HCL/dotenv format — needs explicit type flags)
sops --input-type dotenv --output-type dotenv terraform/config/dev/terraform.tfvars

# Encrypt a new tfvars file
sops -e -i --input-type dotenv --output-type dotenv path/to/new.tfvars

# Decrypt to stdout (read-only)
sops -d --input-type dotenv --output-type dotenv terraform/config/dev/terraform.tfvars
```

SOPS handles YAML natively. For `.tfvars` (HCL/dotenv format), `--input-type dotenv --output-type dotenv` is required — without it, SOPS wraps the file in JSON which breaks Terraform.

### CI/CD

CI decrypts all secrets using the `SOPS_AGE_KEY` GitHub secret containing the age private key. See `.github/workflows/` for details.

## Acknowledgements
The development of the HealthDataCloud open source software was supported by the EBRAINS research infrastructure, funded from the European Union's Horizon 2020 Framework Programme for Research and Innovation under the Specific Grant Agreement No. 945539 (Human Brain Project SGA3) and H2020 Research and Innovation Action Grant Interactive Computing E-Infrastructure for the Human Brain Project ICEI 800858.

This project has received funding from the European Union’s Horizon Europe research and innovation programme under grant agreement No 101058516. Views and opinions expressed are however those of the author(s) only and do not necessarily reflect those of the European Union or other granting authorities. Neither the European Union nor other granting authorities can be held responsible for them.

![EU HDC Acknowledgement](https://hdc.ebrains.eu/img/HDC-EU-acknowledgement.png)
