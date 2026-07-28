<!--
SPDX-FileCopyrightText: 2023 Julian-Samuel Gebühr
SPDX-FileCopyrightText: 2023 - 2024 Slavi Pantaleev
SPDX-FileCopyrightText: 2025 Suguru Hirahara
SPDX-FileCopyrightText: 2026 MASH project contributors

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Running multiple instances of the same service on one server or virtual machine

On this playbook, each Ansible role can only be invoked once and made to install one instance of the service it is responsible for. So, if you need multiple instances (of whichever service), you'll need some workarounds.

Let's say you are setting up [PeerTube](services/peertube.md) and [NetBox](services/netbox.md), both of which require a [Valkey](services/valkey.md) instance, on the same server or virtual machine represented by `mash.example.com`.

If you just add `valkey_enabled: true` to `vars.yml` for `mash.example.com`, a single shared Valkey instance (`mash-valkey`) would be set up. However, it is not recommended because sharing the Valkey instance has security concerns and possibly causes data conflicts. In this case, you should not add `valkey_enabled: true` to `vars.yml` but install dedicated Valkey instances for each of them.

To install those instances, you can follow the steps below:

1. Adjust the `hosts` file
2. Adjust the configuration of the supplementary inventory hosts to use a new "namespace"
3. Edit the `vars.yml` file for the main host

ℹ️ This document takes Valkey as an example, but the same steps can be applied to host multiple instances or whole stacks of any kind.

## Inventory hosts and managed nodes

An **inventory host** is a logical Ansible identity, not necessarily a separate server or virtual machine. Its name selects its own `inventory/host_vars/<inventory-host>/vars.yml` file and is used with the `-l` flag. In this example, `ansible_host` specifies the address of the target system.

Ansible calls the target system a **managed node**. In MASH, this is the Linux operating-system environment and Docker host being configured. A **supplementary inventory host** is an additional logical inventory identity with its own `host_vars` and a specific purpose, such as installing a dedicated dependency for one application. Its `ansible_host` value determines which managed node it targets—it can target the same managed node as the main inventory host or a different one.

The recipes on this page intentionally use the same `ansible_host` value for the main and supplementary inventory hosts, so that their separately configured services are installed on one managed node.

The example on this page has this relationship:

```text
main inventory host + its host_vars ───────────────────┐
                                                       ├─ same ansible_host value
supplementary inventory host(s) + their host_vars ─────┘
                                                            │
                                                            ▼
                                                   one managed node
                                                   (one Linux server or VM;
                                                   one Docker host)
                                                   ├─ Docker network for NetBox
                                                   │  ├─ NetBox container
                                                   │  └─ dedicated Valkey container
                                                   └─ Docker network for PeerTube
                                                      ├─ PeerTube container
                                                      └─ dedicated Valkey container
```

The inventory hosts are therefore separate configuration and execution identities, but they do not represent nested or additional operating systems. Ansible can select and run them independently, and the unique prefixes in step 2 keep the resulting service names and paths separate. A different `ansible_host` target is possible, but the host-local Docker networks, Unix sockets, and systemd unit dependencies used by these recipes do not extend across managed nodes. A remote dependency needs a separately reachable and secured TCP endpoint, service-specific connection settings, and suitable service ordering on each managed node.

See [Using Ansible for the playbook](ansible.md) for the control-node and managed-node model, and [Inventory aliases](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html#inventory-aliases) for the underlying Ansible feature.

## 1. Adjust `hosts`

At first, set up `inventory/hosts` as follows, so that the inventory hosts for the service instances target the same managed node.

💡 **Notes**:

- Make sure to replace `mash.example.com` with your hostname and `YOUR_SERVER_IP_ADDRESS_HERE` with the IP address or resolvable name of the managed node, respectively.
- `mash_example_com` can be any valid Ansible inventory group name and does not need to match the managed node's hostname.

```ini
[mash_servers]
[mash_servers:children]
mash_example_com

[mash_example_com]
mash.example.com ansible_host=YOUR_SERVER_IP_ADDRESS_HERE
mash.example.com-netbox-deps ansible_host=YOUR_SERVER_IP_ADDRESS_HERE
mash.example.com-peertube-deps ansible_host=YOUR_SERVER_IP_ADDRESS_HERE
```

This creates a new group (called `mash_example_com`) which contains all 3 inventory hosts:

- (**new**) `mash.example.com-netbox-deps` — a supplementary inventory host for your [NetBox](services/netbox.md) dependencies
- (**new**) `mash.example.com-peertube-deps` — a supplementary inventory host for your [PeerTube](services/peertube.md) dependencies
- (old) `mash.example.com` — your main inventory host

You can add a new entry to `[mash_example_com]` to include another supplementary inventory host in the group.

### Note: use `-l` to select an inventory host

When running Ansible commands later on, use the `-l` flag to limit which inventory host to run them against. Here are a few examples:

- `just install-all` — runs the [installation](installing.md) process on all inventory hosts (3 hosts in this case)
- `just install-all -l mash_example_com` — runs the installation process on all inventory hosts in the `mash_example_com` group (the same 3 hosts as `just install-all` in this case)
- `just install-all -l mash.example.com-netbox-deps` — runs the installation process only on the `mash.example.com-netbox-deps` inventory host

## 2. Adjust the configuration of the supplementary inventory hosts to use a new "namespace"

Targeting the same managed node with multiple inventory hosts without further configuration causes conflicts, because services will use the same paths (e.g. `/mash/valkey`) and service/container names (`mash-valkey`) everywhere.

To avoid conflicts, adjust the `vars.yml` file for the new inventory hosts (`mash.example.com-netbox-deps` and `mash.example.com-peertube-deps` in this example) and set non-default and unique values for the variables which override service names and directory path prefixes.

First, create new directories where `vars.yml` for the supplementary inventory hosts are stored. Their paths should be `inventory/host_vars/mash.example.com-netbox-deps` and `inventory/host_vars/mash.example.com-peertube-deps`.

Then, create a new `vars.yml` file inside each of them with a content below.

💡 **Notes**:

- As this `vars.yml` file will be used for the new inventory host, make sure to set `mash_playbook_generic_secret_key`. It does not need to be the same as the one in `vars.yml` for the main inventory host.
- These variables are not related to the hostname of the server. For example, even if it is `www.example.com`, you do not need to include `www` in either of them. If you are not sure which string you should set, you might as well use the values as they are.

For the supplementary inventory host for NetBox, create `inventory/host_vars/mash.example.com-netbox-deps/vars.yml` with this content.

```yaml
# NetBox dependencies - supplementary inventory host
#
# Inventory host: mash.example.com-netbox-deps
# Purpose: dedicated Valkey for NetBox
# Managed node: same server or VM targeted by mash.example.com

---

########################################################################
#                                                                      #
# Playbook                                                             #
#                                                                      #
########################################################################

# Put a strong secret below, generated with `pwgen -s 64 1` or in another way
mash_playbook_generic_secret_key: ''

# Override service names and directory path prefixes
mash_playbook_service_identifier_prefix: 'mash-netbox-'
mash_playbook_service_base_directory_name_prefix: 'netbox-'

########################################################################
#                                                                      #
# /Playbook                                                            #
#                                                                      #
########################################################################

########################################################################
#                                                                      #
# valkey                                                               #
#                                                                      #
########################################################################

valkey_enabled: true

########################################################################
#                                                                      #
# /valkey                                                              #
#                                                                      #
########################################################################
```

For the supplementary inventory host for PeerTube, create `inventory/host_vars/mash.example.com-peertube-deps/vars.yml` with this content.

```yaml
# PeerTube dependencies - supplementary inventory host
#
# Inventory host: mash.example.com-peertube-deps
# Purpose: dedicated Valkey for PeerTube
# Managed node: same server or VM targeted by mash.example.com

---

########################################################################
#                                                                      #
# Playbook                                                             #
#                                                                      #
########################################################################

# Put a strong secret below, generated with `pwgen -s 64 1` or in another way
mash_playbook_generic_secret_key: ''

# Override service names and directory path prefixes
mash_playbook_service_identifier_prefix: 'mash-peertube-'
mash_playbook_service_base_directory_name_prefix: 'peertube-'

########################################################################
#                                                                      #
# /Playbook                                                            #
#                                                                      #
########################################################################

########################################################################
#                                                                      #
# valkey                                                               #
#                                                                      #
########################################################################

valkey_enabled: true

########################################################################
#                                                                      #
# /valkey                                                              #
#                                                                      #
########################################################################
```

With these `vars.yml` files, **two** individual Valkey instances will be created:

- `mash-netbox-valkey` with its base data path in `/mash/netbox-valkey`
- `mash-peertube-valkey` with its base data path in `/mash/peertube-valkey`

These instances reuse the `mash` user and group and the `/mash` data path, but are not in conflict with each other.

## 3. Edit `vars.yml` for the main host

Having configured `vars.yml` for Valkey instances for PeerTube and NetBox, add the following configuration to `vars.yml` for the main host (`inventory/host_vars/mash.example.com/vars.yml`):

```yaml
########################################################################
#                                                                      #
# netbox                                                               #
#                                                                      #
########################################################################

# Other NetBox configuration here

# Point NetBox to its dedicated Valkey instance
netbox_environment_variable_redis_hostname: mash-netbox-valkey
netbox_environment_variable_redis_cache_hostname: mash-netbox-valkey

# Make sure the NetBox container is connected to the container network of its dedicated Valkey service (mash-netbox-valkey)
netbox_container_additional_networks_custom:
  - mash-netbox-valkey

# Make sure the NetBox service (mash-netbox.service) starts after its dedicated Valkey service (mash-netbox-valkey.service)
netbox_systemd_required_services_list_custom:
  - mash-netbox-valkey.service

########################################################################
#                                                                      #
# /netbox                                                              #
#                                                                      #
########################################################################

########################################################################
#                                                                      #
# peertube                                                             #
#                                                                      #
########################################################################

# Other PeerTube configuration here

# Point PeerTube to its dedicated Valkey instance
peertube_redis_hostname: mash-peertube-valkey

# Make sure the PeerTube container is connected to the container network of its dedicated Valkey service (mash-peertube-valkey)
peertube_container_additional_networks_custom:
  - "mash-peertube-valkey"

# Make sure the PeerTube service (mash-peertube.service) starts after its dedicated Valkey service (mash-peertube-valkey.service)
peertube_systemd_required_services_list_custom:
  - "mash-peertube-valkey.service"

########################################################################
#                                                                      #
# /peertube                                                            #
#                                                                      #
########################################################################
```

## Installation

Finally, install the service instances for each supplementary inventory host before running the [installation](installing.md) command for the main inventory host:

```sh
just install-all -l mash.example.com-netbox-deps
just install-all -l mash.example.com-peertube-deps
just install-all -l mash.example.com
```

> [!WARNING]
> Ansible treats inventory aliases as separate hosts and [may run their tasks in parallel](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html#inventory-aliases) even when they target the same managed node. Do not rely on an unscoped `just install-all` or `just setup-all` command to serialize the initial installation or a configuration change which affects both sides.

The `*_systemd_required_services_list_custom` entries shown above solve a later and different ordering problem: after the systemd unit files exist, they make systemd activate the dependency service before its consumer. They do not order Ansible installation tasks.

## Questions & Answers

**Can't I just use the same Valkey instance for multiple services?**

> You may or you may not. See the [Valkey](services/valkey.md) documentation for why you shouldn't do this.

**Can't I just create one inventory host and a separate stack for each service** (e.g. Nextcloud + all dependencies on one inventory host; PeerTube + all dependencies on another inventory host; with both inventory hosts targeting the same managed node)?

> That's a possibility which is somewhat clean. The downside is that each "full stack" comes with its own Postgres database which needs to be maintained and upgraded separately.
