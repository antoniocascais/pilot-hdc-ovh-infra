# Workbench Setup (FreeIPA + Guacamole)

Per-project remote desktop access, backed by FreeIPA for identity.

- **FreeIPA**: LDAP + Kerberos + HBAC + sudo policy. One server per env. Docker-based (`freeipa/freeipa-server:rocky-9-4.12.2`) on a private VM with `/data` on a block volume.
- **Guacamole desktop VMs**: per-project Ubuntu 22.04 VMs with XRDP + XFCE4, Singularity CE, git-annex, datalad, TurboVNC, pilotcli. Enrolled as FreeIPA clients. Users reach them through Guacamole web (K8s) → guacd → XRDP.

Neither is in `make ansible`. Run separately via `make ansible-freeipa` / `make ansible-guacamole`.

## How the pieces connect

```
browser
  ↓ OIDC (Keycloak, federated to EBRAINS IAM)
Guacamole web (K8s workspace app)
  ↓ guacd
Desktop VM (XRDP + XFCE4)  ──FreeIPA client──▶  FreeIPA VM
                                                   ↑
admin UI: https://ldap.<freeipa_domain>/ipa/ui/ ──┘
          (nginx SNI passthrough + L7 reverse proxy + Let's Encrypt)
```

Hostnames (from inventory / sensitive.yml):

| Item               | Dev                                          | Prod                                  |
|--------------------|----------------------------------------------|---------------------------------------|
| FreeIPA realm      | `DEV.HDC.EBRAINS.EU`                         | `HDC.EBRAINS.EU`                      |
| FreeIPA host       | `ldap.dev.hdc.ebrains.eu`                    | `ldap.hdc.ebrains.eu`                 |
| Guac host pattern  | `ldap-<project>.dev.hdc.ebrains.eu`          | `ldap-<project>.hdc.ebrains.eu`       |

## Prerequisites

- S3 backend creds exported (see `terraform/bootstrap/README.md`)
- SOPS age key present
- Keycloak realm + per-project OIDC clients already applied (`terraform/keycloak/`)
- DNS A record `ldap.<freeipa_domain>` → nginx floating IP (external, handled outside this repo)

---

## Part 1: FreeIPA server (once per env)

Do this before adding any Guacamole servers.

1. Enable in `terraform/config/<env>/terraform.tfvars`:
   ```
   deploy_freeipa       = true
   freeipa_volume_size  = 20
   ```

2. `make plan-<env>` → `make apply-<env>`.

3. **Attach the block volume** in OVH Console: `freeipa-data-<env>` → `freeipa-<env>`.

4. Grab the VM IP (`terraform output freeipa_addresses`) and seed `ansible/vars/sensitive.yml`:
   ```bash
   sops ansible/vars/sensitive.yml
   ```
   ```yaml
   freeipa_hosts:
     <env>:
       ip: <freeipa-private-ip>
   freeipa_admin_password:
     <env>: <strong-password>
   freeipa_ds_password:
     <env>: <strong-password>
   ```

5. Ensure the inventory entry in `ansible/inventory/hosts.yml` under `freeipa:`:
   ```yaml
   freeipa-<env>:
     ansible_host: "{{ freeipa_hosts.<env>.ip }}"
     ansible_ssh_common_args: '-o ProxyCommand="ssh -W %h:%p -p {{ target_ssh_port }} -i {{ ssh_key_path }} ubuntu@{{ nginx_hosts.<env>.ip }}"'
     freeipa_env: <env>
     freeipa_domain: <env>.hdc.ebrains.eu   # prod: hdc.ebrains.eu
     freeipa_project_hosts:
       - ldap-<project>.<freeipa_domain>    # per-project guac hosts
     freeipa_sudo_users:
       - user: <user>
         hosts:
           - ldap-<project>.<freeipa_domain>
   ```
   `freeipa_env` is the env discriminator for env-keyed password lookups. Miss it and the first template task fails with `AnsibleUndefinedVariable`.

6. Bootstrap FreeIPA (first run, VM on port 22). Takes around 10 to 15 min: dist-upgrade + reboot + Docker pull + `ipa-server-install` (3 to 8 min inside the container):
   ```bash
   make ansible-freeipa EXTRA_ARGS="-l freeipa-<env> -e ssh_port=22"
   ```
   Watch install progress in a side terminal:
   ```bash
   ssh -A ubuntu@<nginx-ip> -p <ssh-port> ssh ubuntu@<freeipa-ip> 'sudo docker logs -f freeipa-freeipa-1'
   ```
   The playbook polls `kinit admin` 60× @ 10s. Expected wait during `ipa-server-install`.

7. SSH hardening (last):
   ```bash
   ./ansible/run.sh ansible-playbook playbooks/ssh-hardening.yml -l freeipa-<env> -e ssh_port=22
   ```

8. Activate nginx SNI routing + issue LE cert for `ldap.<freeipa_domain>`:
   ```bash
   make ansible EXTRA_ARGS="-l nginx-<env>"
   ```

9. Verify:
   ```bash
   curl -sI https://ldap.<freeipa_domain>/ipa/ui/ | head -5
   # expect: 301 -> /ipa/ui (or 200), valid LE cert
   ```

---

## Part 2: Add a Guacamole desktop server for a new project

FreeIPA must already exist (Part 1).

1. Add the project to `workspace_projects` in tfvars:
   ```
   deploy_guacamole    = true
   workspace_projects  = ["existingproject", "newproject"]
   guacamole_image_id  = "<Ubuntu 22.04 image ID>"
   guacamole_flavor_id = "<flavor ID>"
   ```

2. Add the new host's FQDN to the FreeIPA inventory entry (so Part 1 step 5 now includes it in `freeipa_project_hosts` and `freeipa_sudo_users`).

3. Add the new host entry under `guacamole:` in `hosts.yml`:
   ```yaml
   guacamole-<newproject>-<env>:
     ansible_host: "{{ guacamole_hosts.<env>.<newproject>.ip }}"
     ansible_port: "{{ ssh_port | default(guacamole_target_ssh_port) }}"
     ansible_ssh_common_args: '-o ProxyCommand="ssh -W %h:%p -p {{ target_ssh_port }} -i {{ ssh_key_path }} ubuntu@{{ nginx_hosts.<env>.ip }}"'
     guacamole_project: <newproject>
     freeipa_env: <env>
     freeipa_domain: <env>.hdc.ebrains.eu    # prod: hdc.ebrains.eu
     freeipa_server_ip: "{{ freeipa_hosts.<env>.ip }}"
   ```

4. `make plan-<env>` → `make apply-<env>`.

5. **Attach the block volume** in OVH Console: `guacamole-data-<newproject>-<env>` → `guacamole-<newproject>-<env>`.

6. Add the VM IP to `sensitive.yml`:
   ```yaml
   guacamole_hosts:
     <env>:
       <newproject>:
         ip: <guacamole-private-ip>
   ```

7. Re-run FreeIPA playbook to register the new host (hostgroup + HBAC + sudo):
   ```bash
   make ansible-freeipa EXTRA_ARGS="-l freeipa-<env>"
   ```

8. Bootstrap the guac VM (first run, port 22):
   ```bash
   make ansible-guacamole EXTRA_ARGS="-l guacamole-<newproject>-<env> -e ssh_port=22"
   ```

9. SSH hardening:
   ```bash
   ./ansible/run.sh ansible-playbook playbooks/ssh-hardening.yml -l guacamole-<newproject>-<env> -e ssh_port=22
   ```

---

## Verification

### FreeIPA

```bash
# Exec into the container
ssh -A ubuntu@<nginx-ip> -p <ssh-port> ssh ubuntu@<freeipa-ip>
sudo docker exec -it freeipa-freeipa-1 bash

# First admin login. Admin-set passwords expire on first use (forced change flow).
kinit admin           # enters change flow; if it errors: ipa passwd admin then kpasswd

# Enrolled hosts and derived objects
ipa host-find                                     # self + all guac hosts
ipa hostgroup-show hostgroup_<guac-fqdn>          # naming: hostgroup_<fqdn>
ipa hbacrule-find                                 # access_<fqdn>project + allow_all + allow_systemd-user
ipa sudorule-find                                 # sudo-powers_<fqdn>
```

Web UI: `https://ldap.<freeipa_domain>/ipa/ui/`

### Guacamole desktop VM

```bash
# Block volume + Docker data-root on /data01
ssh <guac-vm> 'df -h /data01 && docker info | grep "Docker Root Dir"'

# XRDP listening on 3389
ssh <guac-vm> 'ss -tlnp | grep 3389'

# FreeIPA client enrollment. LDAP user resolvable.
ssh <guac-vm> 'id <freeipa-user>'

# Tools
ssh <guac-vm> 'singularity --version && git-annex version --raw && datalad --version && dpkg -l | grep turbovnc && pilotcli --help | head -1'
```

### End-to-end (browser)

1. Hit the Guacamole web URL. Expect: OIDC redirect to Keycloak, then EBRAINS IdP login, then back to Guac landing.
2. **Before disabling `guacadmin`**: log in as `guacadmin` (DB default), find the auto-created OIDC user, grant `ADMINISTER` plus matching connection/group/session perms. Verify the OIDC user's Settings pane shows **Users / Connections / Groups / Sessions**.
3. Open the RDP connection to the workspace VM, login as a FreeIPA user, run `sudo -l` and `sudo whoami`.
4. Only after step 2 succeeds: disable `guacadmin` in Guac UI. Remove `secret/workspace guacadmin-password` from Vault (stale after disable).

---

## Gotchas

- **Volume attach is manual.** OVH TF provider has no clean attachment primitive. Attach in OVH Console after the first apply.
- **FreeIPA first-boot is slow.** `ipa-server-install` takes 3 to 8 min inside the container. The playbook's 60×10s retry on `kinit admin` is the designed wait.
- **Admin password first-login expiry.** FreeIPA forces change on admin-set passwords. `kinit admin` enters change flow. If it errors, use `ipa passwd admin` then `kpasswd` to clear the flag.
- **Naming conventions** (from `templates/freeipa/configure_freeipa.sh.j2`):
  - Hostgroup: `hostgroup_<fqdn>`
  - HBAC rule: `access_<fqdn>project`
  - Sudo rule: `sudo-powers_<fqdn>`
- **`allow_all` HBAC ships enabled.** While active, it bypasses project-specific rules (any IPA user can access any host). Consider `ipa hbacrule-disable allow_all` once project rules are verified. Keep dev and prod consistent.
- **Nginx SNI = stream + L7, not pure L4.** Traffic: `stream 443` → `ssl_preread` on SNI → `127.0.0.1:8443` L7 (terminates LE cert) → FreeIPA backend. HSTS from ingress-nginx forces L7. L4 passthrough alone fails.
- **Certbot uses webroot, not the nginx plugin.** `--nginx` injects `listen 443 ssl` which conflicts with the stream block. Use `certonly --webroot` over port 80.
- **Guacamole OIDC lockout trap.** If OpenID auto-redirect is on and you delete `guacadmin` before granting a real OIDC user admin, nobody can log in. No password-reset path without SQL into `postgres-guacamole-0`. Grant admin on the OIDC user first, verify, then disable guacadmin.
- **Guacamole = public OIDC client.** No client secret. `secret/guacamole` in Vault holds only postgres creds, shared across projects.
- **guacd 1.2.0 SSH protocol is broken.** libssh2 1.8.0 only supports `ssh-rsa`; OpenSSH 8.9 (Ubuntu 22.04) dropped it. Use RDP, not the SSH protocol in Guacamole. The guac VM's sshd has compat overrides (`HostKeyAlgorithms +ssh-rsa`, weak kex) scoped to guac hosts only.
- **Guacamole RDP cert.** Self-signed on the XRDP side. Enable "Ignore server certificate" in the connection config.
- **Env-keyed secret lookups require the env discriminator.** Any `{{ var[env] }}` lookup (`freeipa_admin_password[freeipa_env]`, etc.) needs `freeipa_env` or `guacamole_env` set as a per-host inventory var. Miss it and the template task fails with `AnsibleUndefinedVariable`.
- **Run SSH hardening last.** Main playbook runs dist-upgrade + reboot. `sshd_config` conffile can get replaced and the port reset. Apply hardening on the stable system, or the next run wipes it.
- **Ubuntu 24.04 uses `ssh.socket`.** Hardening auto-detects via `systemctl is-active ssh.socket`. Do not add manual overrides in `/etc/systemd/system/ssh.socket.d/`; they load after `sshd-socket-generator` and clobber it. Change `Port` in `sshd_config`, daemon-reload, restart `ssh.socket`.
