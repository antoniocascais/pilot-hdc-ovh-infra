# NFS Server Setup

RWX persistent storage for K8s workloads. Private-network-only VM, accessed via nginx bastion.

Not in `make ansible`. Runs separately via `make ansible-nfs` (dist-upgrade + filesystem creation, too disruptive for routine site runs).

## Prerequisites

- S3 backend credentials exported: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (see `terraform/bootstrap/README.md`)
- SOPS age key present (see [README](../README.md#secret-management-sops--age))

## Steps

1. Add to `terraform/config/<env>/terraform.tfvars`:
   ```
   deploy_nfs      = true
   nfs_volume_size = 50
   ```
   Edit with `sops --input-type dotenv --output-type dotenv terraform/config/<env>/terraform.tfvars`.

2. `make plan-<env>` → `make apply-<env>`.

3. **Attach the block volume to the NFS instance in OVH Console.** TF provider cannot attach pre-existing volumes.

4. SSH to the NFS VM via bastion (agent forwarding required), verify the device:
   ```bash
   ssh-add ~/.ssh/your-ovh-key
   ssh -A ubuntu@<nginx-ip> -p <ssh-port>
   # from nginx:
   ssh ubuntu@<nfs-private-ip> lsblk
   ```
   Expect `/dev/sdb` (override with `-e nfs_block_device=/dev/sdX` if different).

5. Add NFS VM private IP + per-env allowed CIDR to `ansible/vars/sensitive.yml`:
   ```bash
   sops ansible/vars/sensitive.yml
   ```
   ```yaml
   nfs_hosts:
     <env>:
       ip: <terraform output nfs_addresses>
       network: <env-subnet-cidr>    # e.g. 10.0.0.0/24 for dev
   ```

6. Verify connectivity:
   ```bash
   ./ansible/run.sh ansible nfs -m ping -e ssh_port=22
   ```

7. Bootstrap (first run, VM on port 22):
   ```bash
   make ansible-nfs EXTRA_ARGS="-l nfs-<env> -e ssh_port=22"
   ```

8. SSH hardening. **Must run after** nfs-server.yml (dist-upgrade reboot resets port):
   ```bash
   ./ansible/run.sh ansible-playbook playbooks/ssh-hardening.yml -l nfs-<env> -e ssh_port=22
   ```

9. Subsequent runs: `make ansible-nfs EXTRA_ARGS="-l nfs-<env>"` (auto-uses hardened port).

## Verification

From any host on the private network (e.g. a K8s node):

```bash
showmount -e <nfs-private-ip>        # expect /nfs/export <env-subnet-cidr>
mount -t nfs <nfs-private-ip>:/nfs/export /mnt && touch /mnt/test && rm /mnt/test
```

## Gotchas

- **Volume attach is manual.** OVH TF provider has no clean attachment primitive for pre-existing volumes. Attach in Console after the first apply.
- **Per-env CIDR in sensitive.yml.** Template uses `nfs_hosts[nfs_env].network`. Missing the network key breaks the export ACL.
- **Run SSH hardening last.** dist-upgrade can replace `sshd_config` conffile and reset the port. Apply hardening on the stable system, or the next dist-upgrade wipes it.
- **Quota split.** Volume quota and instance-core quota are separate in OVH. A partial apply can leave orphan volumes in state. Leaving them is cheaper than destroy+recreate after a quota bump.
