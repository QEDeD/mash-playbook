<!--
SPDX-FileCopyrightText: 2025 MASH project contributors

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# ihatemoney

[ihatemoney](https://github.com/spiral-project/ihatemoney) is a self-hosted shared budget manager, that this playbook can install, powered by the [ansible-role-ihatemoney](https://github.com/IUCCA/ansible-role-ihatemoney) Ansible role.


## Dependencies

This service requires the following other services:
- a [Postgres](postgres.md) database
- a [Traefik](traefik.md) reverse-proxy server


## Configuration

To enable this service, add the following configuration to your `vars.yml` file and re-run the [installation](../installing.md) process:

```yaml
########################################################################
#                                                                      #
# ihatemoney                                                           #
#                                                                      #
########################################################################

ihatemoney_enabled: true

# To enable the Admin dashboard:
# - go through an installation without specifying this variable
# - once ihatemoney is running, run this command to generate a hashed password: `docker exec -it mash-ihatemoney ihatemoney generate_password_hash`
# - populate this variable with the hashed password and run the installation process again
# ihatemoney_admin_password:

# The `ihatemoney_public_project_creation` variable controls project creation access.
# When set to `True`, anyone can create a project without requiring the admin password.
# If `ihatemoney_public_project_creation` is not set, or is set to `False`,
# the admin password is required to create a project (and therefore, must be defined above).
# ihatemoney_public_project_creation: true

ihatemoney_hostname: mash.example.com
ihatemoney_path_prefix: /ihatemoney

########################################################################
#                                                                      #
# /ihatemoney                                                          #
#                                                                      #
########################################################################
```

## Usage

After running the command for installation, the ihatemoney instance becomes available at the URL specified with `ihatemoney_hostname` and `ihatemoney_path_prefix`. With the configuration above, the service is hosted at `https://mash.example.com/ihatemoney`.

If you'd like to enable the Admin dashboard, follow the comments for the `ihatemoney_admin_password` in the [Configuration](#configuration) section above.
