# home-automation-server-ansible
This is a Home automation docker stack server installation playbook for ansible

## NAS setup for NFS storage (TrueNAS SCALE)

When `gv_storage_location_type: nfs` is used, the server stores all container data on an
NFS share. The share must be prepared on the NAS **before** running the playbook.
Instructions below assume TrueNAS SCALE with a pool named `NAS-root` — adjust names to
your environment.

### 1. Create the dataset

*Datasets → select the pool → Add Dataset*

- **Name**: e.g. `home-automation-server-data`
- **Dataset Preset**: `Generic`

### 2. Set the ACL properties (important)

The pool default (`acltype=nfsv4` with inherited ACEs) breaks the playbook: files created
over NFS inherit NFSv4 ACLs and the chown in Ansible's `copy`/`template` tasks fails with
`chown failed: [Errno 1] Operation not permitted`. The dataset must use plain POSIX
permissions. From the TrueNAS shell:

```shell
zfs set acltype=posix NAS-root/home-automation-server-data
zfs set aclinherit=discard NAS-root/home-automation-server-data
```

Verify:

```shell
zfs get acltype,aclmode,aclinherit NAS-root/home-automation-server-data
```

Expected: `acltype posix`, `aclinherit discard`. Once files are being created, `ls -l` on
the client must show no trailing `+` on the permission bits — a `+` means ACLs are still
being attached and the properties above were applied after files already existed (delete
the affected tree and let the playbook recreate it).

### 3. Set the dataset ownership

The playbook creates a local user with uid/gid `1005` (see `gv_local_ha_uid` /
`gv_local_ha_gid` in `ansible-playbook/inventories/default/group_vars/all.yml`). Give the
dataset root to that uid/gid from the TrueNAS shell:

```shell
chown 1005:1005 /mnt/NAS-root/home-automation-server-data
```

### 4. Create the NFS share

*Shares → UNIX (NFS) Shares → Add*

- **Path**: `/mnt/NAS-root/home-automation-server-data`
- **Maproot User / Maproot Group**: leave **empty**
- **Mapall User**: `ha-user`, **Mapall Group**: `home-automation-server-users` — create
  this user/group on the NAS first with uid/gid `1005`, matching `gv_local_ha_uid` /
  `gv_local_ha_gid`. With Mapall, every operation from the client (root included) executes
  as this user on the NAS, so all files are force-owned `1005:1005` regardless of who
  writes them.
- Optionally restrict **Hosts** to the home automation server's address.

Implications of the Mapall setup (all verified against this playbook):

- The playbook's `owner:`/`group:` chowns to uid/gid 1005 succeed as no-ops.
- A chown to **any other** uid/gid over NFS fails with `Operation not permitted` —
  containers writing to this share must not run as root or as any other uid and expect to
  chown (this is why influxdb, grafana and mosquitto run with `user: 1005` in the compose
  file).

Enable the NFS service (*System → Services → NFS*). Enabling **NFSv4** in the NFS service
options is recommended; the clients auto-negotiate the highest version offered, and the
playbook works with either v3 or v4.

### 5. Configure the playbook

In `ansible-playbook/inventories/default/group_vars/all.yml`:

```yaml
gv_storage_location_type: nfs
gv_nfs_server_address: <NAS address>
gv_server_data_root_local_mount_path: /mnt/server_data
gv_server_data_remote_path: /mnt/NAS-root/home-automation-server-data
```

The playbook installs autofs on the server and mounts the share on demand at
`gv_server_data_root_local_mount_path`.

## Running

```shell
cd ansible-playbook
./install.sh      # full provisioning run
./start-all.sh    # start all container stacks (tag: start-stacks)
./stop-all.sh     # stop all container stacks (tag: stop-stacks)
```
