# Docker test host

This directory contains the assets needed to spin up a disposable "managed node" locally to exercise the playbook without touching production infrastructure.

## Requirements

- Docker Engine (needs to support `--cgroupns host` and privileged containers)

## Usage

Start the containerized host:

```sh
just test-host-up
```

This builds the local image and starts a privileged container named `mash-test-host` listening on SSH port `2222`. Systemd runs as PID 1 inside the container so the playbook can manage services normally.

Stop and remove the test host when finished:

```sh
just test-host-down
```

Tail logs if you need to debug the container launch:

```sh
just test-host-logs
```

## Credentials

- SSH user: `ansible`
- SSH password: `ansible`
- Passwordless sudo is enabled for the `ansible` user.

## Targeting the host with Ansible

A helper inventory file is available at `inventory/test-hosts` with SSH connection settings. Once the container is running you can test connectivity with:

```sh
ansible -i inventory/test-hosts test_hosts -m ping
```

You can then apply roles or the full playbook against the `mash-test` host by pointing `ansible-playbook` (or the existing `just run` helpers) at `inventory/test-hosts`.
