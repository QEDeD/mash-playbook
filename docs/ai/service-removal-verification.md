<!--
SPDX-FileCopyrightText: 2026 MASH project contributors

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Service Removal Verification

This runbook is for cases where a service is disabled or supposedly uninstalled,
but the operator suspects leftovers on the managed host.

## Use this when

- a playbook run entered uninstall tasks, but it is unclear whether anything
  was actually removed
- a service appears disabled in inventory, but the host may still have systemd,
  Docker, filesystem, or DB leftovers
- an old or removed service may no longer be managed by the playbook and needs
  manual cleanup

## Working model

Separate these states:

- `documented model`: what the local playbook says should happen
- `current local state`: what logs and local repo files show
- `target state`: what "fully removed" means on the managed host

Do not treat "unit file absent" as sufficient proof by itself.

## Grounding workflow

1. Inspect the local repo first.
2. Derive:
- enable/disable variable
- service identifier
- base path
- container image and network
- uninstall task behavior
- any manual uninstall docs
3. If a playbook log is available, verify whether uninstall tasks were entered.
4. If removal tasks are skipped behind a `*_service_stat.stat.exists` check,
   infer only that the playbook thought the unit file was absent.

## Managed-host verification surfaces

Use only the surfaces supported by the service:

- systemd unit files
- `systemctl list-unit-files` and `list-units` entries that still show
  `not-found`
- dangling `.wants/` symlinks under `/etc/systemd/system`
- running or stopped containers
- cached images
- dedicated Docker networks
- bind mounts that still point at the expected base path
- service base path and key files
- DBs or DB roles if the service uses a DB

## Annoying corner cases

- `systemctl disable --now` does not delete the unit file itself.
- If the unit file was deleted manually before disablement, stale symlinks can
  remain under `.wants/` and produce `LoadState=not-found`.
- `ok` on an Ansible `stat` task only means the check ran; it does not prove
  the path exists.
- Role defaults are not always the effective values.
  - MASH template vars and shared playbook vars can rewrite identifiers, base
    paths, image names, and network names.
- Missing permission to traverse a service base path means the result is
  `unknown`, not "gone".
- A service can be mostly removed while Docker still retains an empty dedicated
  network or cached image.
- DB names and roles may not match the service identifier exactly; verify from
  config or role wiring before assuming no DB exists.
- Legacy or removed services may no longer be managed by the playbook at all.
  In those cases, manual uninstall docs are the source of truth.
- Polkit-backed `systemctl` operations may succeed while direct file deletion
  still fails because filesystem permissions are different.

## Result labels

- `fully removed`: no unit, no stale symlink, no runtime/data/DB leftovers
- `partially removed`: main service gone, but leftovers remain
- `still present`: service definition or major data/runtime state still exists
- `unknown`: important checks were unreadable or unavailable

## Cleanup guidance

When the operator explicitly requests cleanup, provide human-run command blocks
only and annotate:

- target host or scope
- expected impact
- retention expectation
- verification commands
- rollback direction

When applicable, clean up in this order:

1. disable and stop
2. remove unit files and stale symlinks
3. remove containers
4. remove networks and images
5. remove base paths
6. remove DBs and DB roles

After manual unit or symlink deletion, run `systemctl daemon-reload` before the
final verification pass.

## Shared skill

The shared custom skill `service-removal-verification` exists for this pattern.
Its source lives under `~/codex-support/skills`, and it is installed for
runtime use via `~/.agents/skills`.
