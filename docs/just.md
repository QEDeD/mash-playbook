<!--
SPDX-FileCopyrightText: 2023 - 2024 Slavi Pantaleev
SPDX-FileCopyrightText: 2024 - 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Running `just` commands

This playbook supports running playbook commands via [`just`](https://github.com/casey/just) — a more modern command-runner alternative to `make`. It can be used to invoke `ansible-playbook` commands with less typing.

The `just` utility executes shortcut commands (called as "recipes"), which invoke `ansible-playbook`, [`ansible-galaxy`](https://docs.ansible.com/ansible/latest/cli/ansible-galaxy.html) or [`agru`](https://github.com/etkecc/agru) (depending on what is available in your system). The targets of the recipes are defined in [`justfile`](../justfile).

For some recipes such as `just update`, our `justfile` recommends installing `agru` (a faster alternative to `ansible-galaxy`) to speed up the process.

Here are some examples of shortcuts:

| Shortcut                                       | Result                                                                                                         |
|------------------------------------------------|----------------------------------------------------------------------------------------------------------------|
| `just roles`                                   | Install the necessary Ansible roles pinned in [`requirements.yml`](../templates/requirements.yml)              |
| `just update`                                  | Run `git pull` (to update the playbook) and install the Ansible roles                                          |
| `just install-all`                             | Run `ansible-playbook -i inventory/hosts setup.yml --tags=install-all,start`                                   |
| `just setup-all`                               | Run `ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start`                                     |
| `just install-all --ask-vault-pass`            | Run commands with additional arguments (`--ask-vault-pass` will be appended to the above installation command) |
| `just run-tags install-miniflux,start`         | Run specific playbook tags (here `install-miniflux` and `start`)                                               |
| `just install-service miniflux`                | Run `just run --tags=install-miniflux,start-group --extra-vars=group=miniflux` with even less typing           |
| `just start-all`                               | (Re-)starts all services                                                                                       |
| `just stop-group postgres`                     | Stop only the Postgres service                                                                                 |

While [our documentation on prerequisites](prerequisites.md) lists `just` as one of the requirements for installation, using `just` is optional. If you find it difficult to install it, do not find it useful, or want to prefer raw `ansible-playbook` commands for some reason, feel free to run all commands manually. For example, you can run `ansible-galaxy` directly to install the Ansible roles: `rm -rf roles/galaxy; ansible-galaxy install -r requirements.yml -p roles/galaxy/ --force`.

## Difference between playbook tags and shortcuts

It is worth noting that `just` "recipes" are different from [playbook tags](playbook-tags.md). The recipes are shortcuts of commands defined in `justfile` and can be executed by the `just` program only, while the playbook tags are available for the raw `ansible-playbook` commands as well. Please be careful not to confuse them.

For example, these two commands are different:

- `just install-all`
- `ansible-playbook -i inventory/hosts setup.yml --tags=install-all`

The just recipe runs `start` tag after `install-all`, while the latter runs only `install-all` tag. The correct shortcut of the latter is `just run-tags install-all`.

Such kind of difference sometimes matters. For example, when you install a server into which you will import old data (see [here](installing.md#installing-a-server-into-which-youll-import-old-data)), you are not supposed to run `just install-all` or `just setup-all`, because these commands start services immediately after installing components, which may prevent you from importing the data.

## Conditional service restart

The standard `just` recipes automatically add the playbook tags shown below. Users type only the command in the first column.

| Command                        | Tags added by the recipe      | Restart behavior                                              |
| ------------------------------ | ----------------------------- | ------------------------------------------------------------- |
| `just install-all`             | `install-all,start`           | Conditional: restart only services marked as needing restart. |
| `just install-service SERVICE` | `install-SERVICE,start-group` | Conditional within the selected service group.                |
| `just setup-all`               | `setup-all,start`             | Unconditional: restart all targeted services.                 |
| `just setup-service SERVICE`   | `setup-SERVICE,start-group`   | Unconditional within the selected service group.              |
| `just start-all`               | `start-all`                   | Unconditional: restart all services.                          |
| `just start-group GROUP`       | `start-group`                 | Unconditional within the selected service group.              |

In conditional mode, unchanged running services are left alone, while unchanged stopped services are started.

For raw `ansible-playbook` or `just run-tags` invocations, conditional restart is enabled only when the selected tags include an `install-*` tag and no `setup-*` tag. Runs without an `install-*` tag, including standalone start or restart tag selections, restart their targeted services unconditionally.

This behavior can be overridden with the `devture_systemd_service_manager_conditional_restart_enabled` variable. For example, to force unconditional restarts during installation: `just install-all --extra-vars='{"devture_systemd_service_manager_conditional_restart_enabled": false}'`
