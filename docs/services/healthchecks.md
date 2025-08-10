<!--
SPDX-FileCopyrightText: 2023 - 2024 Slavi Pantaleev
SPDX-FileCopyrightText: 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Healthchecks

[Healthchecks](https://healthchecks.io/) is simple and Effective **Cron Job Monitoring** solution.


## Dependencies

This service requires the following other services:

- a [Postgres](postgres.md) database
- a [Traefik](traefik.md) reverse-proxy server
- (optional) the [exim-relay](exim-relay.md) mailer


## Configuration

To enable this service, add the following configuration to your `vars.yml` file and re-run the [installation](../installing.md) process:

```yaml
########################################################################
#                                                                      #
# healthchecks                                                         #
#                                                                      #
########################################################################

healthchecks_enabled: true

healthchecks_hostname: mash.example.com
healthchecks_path_prefix: /healthchecks

########################################################################
#                                                                      #
# /healthchecks                                                        #
#                                                                      #
########################################################################
```

### Authentication

The first superuser account is created after installation. See [Usage](#usage).
You can create as many accounts as you wish.

### Email integration

If you've enabled the [exim-relay](exim-relay.md) mailer service, Healtchecks will automatically be configured to send through it.

If you need to configure Healthchecks to send email directly, the [ansible.role.healthchecks](https://github.com/mother-of-all-self-hosting/ansible-role-healthchecks) Ansible role provides various variables for tweaking the email-sending configuration in its `default/main.yml` file (`healthchecks_environment_variable_default_from_email` and various `healthchecks_environment_variable_email_*` variables).

### Integrating with other services

Refer to the [upstream `.env.example` file](https://github.com/healthchecks/healthchecks/blob/master/docker/.env.example) for discovering additional environment variables.

You can pass these to the Healthchecks container using the `healthchecks_environment_variables_additional_variables` variable. Example:

```yml
healthchecks_environment_variables_additional_variables: |
  DISCORD_CLIENT_ID=123
  DISCORD_CLIENT_SECRET=456
```


## Usage

After running the command for installation, the Healthchecks instance becomes available at the URL specified with `healthchecks_hostname` and `healthchecks_path_prefix`. With the configuration above, the service is hosted at `https://mash.example.com/healthchecks`.

To get started, create a superuser account by **SSH-ing into into the server** and running a command as below:

```sh
docker exec -it mash-healthchecks /opt/healthchecks/manage.py createsuperuser
```

After creating the superuser account, you can open the URL to log in and start setting up healthchecks.


## Recommended other services

- [Prometheus](prometheus.md) — a metrics collection and alerting monitoring solution
