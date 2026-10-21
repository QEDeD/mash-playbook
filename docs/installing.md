<!--
SPDX-FileCopyrightText: 2018 - 2025 Slavi Pantaleev
SPDX-FileCopyrightText: 2018 Aaron Raimist
SPDX-FileCopyrightText: 2018 - 2024 MDAD project contributors
SPDX-FileCopyrightText: 2019 Edgars Voroboks
SPDX-FileCopyrightText: 2019 Michael Haak
SPDX-FileCopyrightText: 2020 Kevin Lanni
SPDX-FileCopyrightText: 2024 Nikita Chernyi
SPDX-FileCopyrightText: 2024 Mitja Jež
SPDX-FileCopyrightText: 2024 - 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Installing

<sup>[Prerequisites](prerequisites.md) > [Configuring DNS settings](configuring-dns.md) > [Getting the playbook](getting-the-playbook.md) > [Configuring the playbook](configuring-playbook.md) > Installing</sup>

If you've configured your DNS records and the playbook, you can start the installation procedure.

## Update Ansible roles

Before installing, you need to update the Ansible roles that this playbook uses and fetches from outside.

To update your playbook directory and all upstream Ansible roles (defined in the `requirements.yml` file), run:

- either: `just update`
- or: a combination of `git pull` and `just roles`

If you don't have either `just` tool, you can run the `ansible-galaxy` tool directly: `rm -rf roles/galaxy; ansible-galaxy install -r requirements.yml -p roles/galaxy/ --force`

For details about `just` commands, take a look at: [Running `just` commands](just.md).

**Note**: if you're not using the [`just`](https://github.com/casey/just) utility, you need to create `setup.yml`, `requirements.yml` and `group_vars/mash_servers` based on the up-to-date templates found in the [`templates/` directory](../templates). If you are using `just`, these files are created and maintained up-to-date automatically.

## Installing services

The Ansible playbook's tasks are tagged, so that certain parts of the Ansible playbook can be run without running all other tasks.

The general command syntax is:

- (**recommended**) when using `just`: `just run-tags COMMA_SEPARATED_TAGS_GO_HERE`
- when not using `just`: `ansible-playbook -i inventory/hosts setup.yml --tags=COMMA_SEPARATED_TAGS_GO_HERE`

It is recommended to get yourself familiar with the [playbook tags](playbook-tags.md) before proceeding.

If you **don't** use SSH keys for authentication, but rather a regular password, you may need to add `--ask-pass` to the all Ansible (or `just`) commands.

If you log in as `root`, you don't need `-K`. If you log in as another user and `sudo` asks that user for a password, add `-K` (`--ask-become-pass`) to the command (with `just`, append it to the recipe, for example `just install-all -K`); Ansible then asks for the sudo password when the run starts. You need this even if you log in with an SSH key. To avoid typing it on every run, [encrypt it with Ansible Vault](https://docs.ansible.com/projects/ansible/latest/vault_guide/vault_encrypting_content.html#encrypting-individual-variables-with-ansible-vault) (`ansible-vault encrypt_string`) as `ansible_become_password` and add the result to your `inventory/host_vars/mash.example.com/vars.yml` file. An encrypted value spans several lines of YAML, so it cannot go on the host line in `inventory/hosts`. Then add `--ask-vault-pass` to the command (or [configure another Vault password source](https://docs.ansible.com/projects/ansible/latest/vault_guide/vault_using_encrypted_content.html#passing-a-single-password)) so that Ansible can decrypt it, and drop `-K`.

There 2 ways to start the installation process — depending on whether you're [Installing a brand new server (without importing data)](#installing-a-brand-new-server-without-importing-data) or [Installing a server into which you'll import old data](#installing-a-server-into-which-youll-import-old-data).

### Installing a brand new server (without importing data)

If this is **a brand new** server and you **won't be importing old data into it**, run all these tags:

```sh
# This is equivalent to: just run-tags install-all,start
just install-all

# Or, when not using just, you can use this instead:
# ansible-playbook -i inventory/hosts setup.yml --tags=install-all,start
```

This will do a full installation and start all services.

**Note**: if the command does not work as expected, make sure that you have properly installed and configured software required to run the playbook, as described on [Prerequisites](prerequisites.md).

### Installing a server into which you'll import old data

If you will be importing data into your newly created server, install it, but **do not** start its services just yet. Starting its services or messing with its database now will affect your data import later on.

To do the installation **without** starting services, run only the `install-all` tag:

```sh
just run-tags install-all

# Or, when not using just, you can use this instead:
# ansible-playbook -i inventory/hosts setup.yml --tags=install-all
```

> [!WARNING]
> Do not run the just "recipe" `just install-all` instead, because it automatically starts services at the end of execution. See: [Difference between playbook tags and shortcuts](just.md#difference-between-playbook-tags-and-shortcuts)

When this command completes, services won't be running yet.

You can now:

- [Importing an existing Postgres database (from another installation)](services/postgres.md#importing) (optional)

… and then proceed to starting all services:

```sh
# This is equivalent to: just run-tags start (or: just run-tags start-all)
just start-all

# Or, when not using just, you can use this instead:
# ansible-playbook -i inventory/hosts setup.yml --tags=start
```

Regardless of the installation way you have chosen, **if an error is not returned, the installation has completed and the services have been started successfully**🎉

## Things to do next

After you have started the services, you can:

- start using the configured services
- or set up additional services
- or learn how to [upgrade services when new versions are released](maintenance-upgrading-services.md)
- or come say Hi in our [Matrix](https://matrix.org) support room — [#mash-playbook:devture.com](https://matrixrooms.info/room/mash-playbook:devture.com). You might learn something or get to help someone else new to hosting services with this playbook.
- or help make this playbook better by contributing (code, documentation, or [coffee/beer](https://liberapay.com/mother-of-all-self-hosting/donate))

### ⚠️ Keep the playbook and services up-to-date

While this playbook helps you to set up services and maintain them, it will **not** automatically run the maintenance task for you. You will need to update the playbook and re-run it **manually**.

The upstream projects, which this playbook makes use of, occasionally if not often suffer from security vulnerabilities.

Since it is unsafe to keep outdated services running on the server connected to the internet, please consider to update the playbook and re-run it periodically, in order to keep the services up-to-date.

For more information about upgrading or maintaining services with the playbook, take a look at this page: [Upgrading services](maintenance-upgrading-services.md)

Feel free to **re-run the setup command any time** you think something is wrong with the server configuration. Ansible will take your configuration and update your server to match.

```sh
just install-all

# Or, to run potential uninstallation tasks too:
# just setup-all
```

To do it without `just`:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=install-all,start

# Or, to run potential uninstallation tasks too:
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

**Note**: refer to [this page on the playbook tags](playbook-tags.md) for more information about those tags.

## Privilege escalation settings

The playbook logs in with the user from `ansible_ssh_user` and then runs `sudo` itself: the main play sets `become: true` and `become_user: root`, and individual tasks switch to a service account such as `mash`, or turn escalation off, where they need to. [Ansible connection variables take precedence over those task keywords](https://docs.ansible.com/projects/ansible/latest/reference_appendices/general_precedence.html#variables), so a setting such as `ansible_become_user=root` in your inventory forces root for every task. By default the playbook therefore refuses to run for a host that defines `ansible_become`, `ansible_become_user` or the user variable of one of [Ansible's become plugins](https://docs.ansible.com/projects/ansible/latest/collections/index_become.html): `ansible_sudo_user`, `ansible_su_user`, `ansible_doas_user`, `ansible_dzdo_user`, `ansible_ksu_user`, `ansible_machinectl_user`, `ansible_pbrun_user`, `ansible_pfexec_user`, `ansible_run0_user` or `ansible_sesu_user`.

If a run stops with `Privilege escalation overrides are defined for this host`, remove the variables it names from that host's inventory line, host/group variables and `-e` extra variables, then run the same command again. Keep `ansible_ssh_user`, `ansible_become_method`, `ansible_become_password` (or `ansible_become_pass`) and the `-K` flag if you use them: the check does not look at escalation methods, passwords, flags or executable wrappers (flags and wrappers can still change which account a task gets), and it cannot know about user aliases added by custom become plugins. If another playbook needs the removed variables, give this playbook its own inventory. The check runs before fact gathering and stops the affected host; other hosts in the same run continue, and the run reports failure. It does not repair file ownership from earlier runs that used the overrides. Tasks delegated to the controller take these variables from the delegate host, which the check does not inspect, so keep them off any explicit `localhost` or `127.0.0.1` inventory entry too.

To keep the overrides deliberately, set `mash_playbook_privilege_escalation_validation_enabled: false` for the host or group, or add `-e mash_playbook_privilege_escalation_validation_enabled=false` to the command. This only skips the check: the main play still sets `become: true` and `become_user: root`, Ansible's precedence rules still apply, and you are responsible for the account each task ends up using.
