<!--
SPDX-FileCopyrightText: 2026 MASH project contributors

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Nextcloud Recovery Note: 2026-04-08 Incident

## Purpose

Record the incident in a way that supports later upstream review without
collapsing together:

- upstream source state
- local controller vendored dependency state
- tracked inventory state
- managed-node rendered artifact state
- managed-node runtime / loaded state
- observed symptom / verification state

## Audit Model

### Statement strength

- `observed`: seen directly in a log, file, deploy record, or browser result
- `confirmed by inspection`: derived deterministically from inspected source or
  config state
- `inferred`: best explanation that fits the observed and inspected evidence

### Audit caveat

The local controller's vendored dependency state is not fully covered by git,
because `roles/galaxy/**` is git-ignored in this repo. Git history is therefore
not enough to reconstruct the exact control-node role state at incident time.

### Timestamp semantics

- Upstream source-history timestamps show when a state existed in source
  history, not when or whether it propagated to the controller or the managed
  node.
- Controller deploy timestamps show local apply intent and effective deploy
  input at that time.
- Managed-node timestamps show rendered-artifact and runtime state on the
  target host.

## Boundary States

| Boundary state | Locus | Time | Status |
| --- | --- | --- | --- |
| Last known good | Managed-node symptom state | 2026-04-08 00:07 CEST | Nextcloud healthy before the DB rewrite. `observed` |
| First known bad DB artifact | Managed-node rendered artifact | 2026-04-08 00:08:04 CEST | `config.php` had `dbhost => ':5432'`. `observed` |
| First known bad DB runtime | Managed-node runtime / symptom | 2026-04-08 shortly after 00:08 CEST | Postgres socket errors and HTTP 500s began. `observed` |
| First DB mitigation deploy | Controller deploy input / apply | 2026-04-08 08:00:49Z | A `setup-nextcloud` deploy later rendered `dbhost => '/run-postgres'`. `observed` |
| First DB confirmed fixed | Managed-node artifact + runtime | 2026-04-08 10:01:15 to 10:01:36 CEST | `config.php` changed to `/run-postgres`; no new Postgres socket errors after restart. `observed` |
| First known bad Redis runtime | Managed-node runtime / symptom | After DB fix on 2026-04-08 | `RedisException: No such file or directory` against `unix:///run-valkey/valkey.sock`. `observed` |
| First Redis mitigation | Tracked inventory + later deploy | Same recovery window | Added `nextcloud_redis_socket_path_host` while retaining hostname as compatibility input. `observed` |
| First confirmed symptom recovery | Verification state | Same recovery window | Nextcloud served the `33.0.2` upgrade screen instead of an internal server error. `observed` |

## Source Timelines

### `ansible-role-nextcloud` upstream source state

| Time | Ref / version | Event type | State |
| --- | --- | --- | --- |
| 2026-03-28 14:16:34 +02:00 | `v33.0.1-0` | source change present | `vars/main.yml` still existed upstream and contained `nextcloud_config_dbhost` as `hostname:port` plus hostname-only `nextcloud_redis_is_configured`. `observed` |
| 2026-04-03 02:13:48 +09:00 | `v33.0.1-1` | source change present | `vars/main.yml` was no longer present upstream. Socket-aware DB defaults and socket-first Redis defaults were upstream source state from this point. `observed` |
| 2026-04-03 19:23:22 +09:00 | `v33.0.2-1` | source change present | `vars/main.yml` still absent upstream. `observed` |
| 2026-04-08 20:56:58 +02:00 | `v33.0.2-3` | source change present | Clean upstream role now defaults `nextcloud_redis_socket_enabled: false` and adds Redis validation for hostname/socket mixed states. The code path no longer looks like the same Redis bug class seen in the incident. `observed` |

### `mash-playbook` upstream source state

| Time | Ref / version | Event type | State |
| --- | --- | --- | --- |
| 2024-11-23 11:33:16 +02:00 | `014d5695` | source change present | Nextcloud docs showed hostname-based Valkey wiring via `nextcloud_redis_hostname` and container-network linkage. `observed` |
| 2026-04-03 02:25:09 +09:00 | `ce8a85f4` | source change present | Nextcloud docs switched to socket-path Valkey wiring via `nextcloud_redis_socket_path_host`. `observed` |

## Controller and Deploy Timeline

| Time | Locus | Event type | State |
| --- | --- | --- | --- |
| 2026-01-08 18:57:49 +01:00 | Tracked inventory | local tracked change | Local inventory added dedicated Nextcloud Valkey host vars using `nextcloud_redis_hostname: mash-nextcloud-valkey`. `observed` |
| 2026-04-07 22:04:55 local install time | Controller vendored dependency | vendor/update | `roles/galaxy/nextcloud/meta/.galaxy_install_info` recorded `version: v33.0.2-1`. `observed` |
| 2026-04-07 after role update | Controller vendored dependency | local acquired state | Despite the recorded `v33.0.2-1` install, the control node still had `roles/galaxy/nextcloud/vars/main.yml`. `observed` |
| 2026-04-08 analysis pass | Controller vendored dependency | local reproduction | A `/tmp` reproduction confirmed that `agru` can update from `v33.0.1-0` to `v33.0.2-1` and leave the removed `vars/main.yml` behind. `observed` |
| 2026-04-08 07:31:03Z to 07:31:48Z | Controller deploy | deploy/apply | `mash.20260408T073101.143954107Z.log` shows `COMMIT=037c27b4`, `DIRTY=yes`, and intended `dbhost => ':5432'`. `observed` |
| 2026-04-08 08:00:49Z to 08:01:35Z | Controller deploy | deploy/apply | `mash.20260408T080048.016350198Z.log` shows `COMMIT=037c27b4`, `DIRTY=no`, and intended `dbhost => '/run-postgres'`. `observed` |

## Managed-Node Timeline

| Time | Locus | Event type | State |
| --- | --- | --- | --- |
| 2026-04-08 00:07 CEST | Verification state | symptom observation | Nextcloud still healthy. `observed` |
| 2026-04-08 00:08:04 CEST | Rendered artifact | artifact write | `config.php` rewrote `dbhost` to `:5432`. `observed` |
| 2026-04-08 00:18:50 CEST | Runtime / loaded state | restart / startup | New Nextcloud container began the upgrade attempt. `observed` |
| 2026-04-08 00:20:18 CEST | Runtime / symptom | runtime failure | Upgrade failed with Postgres socket errors. `observed` |
| 2026-04-08 10:01:15 CEST | Rendered artifact | artifact write | `config.php` rewrote `dbhost` to `/run-postgres`. `observed` |
| 2026-04-08 10:01:36 CEST | Runtime / loaded state | restart / reload effect | Nextcloud restarted without new Postgres socket errors. `observed` |
| After 2026-04-08 10:01 CEST | Runtime / symptom | symptom observation | Redis/Valkey became the active blocker; runtime referenced `unix:///run-valkey/valkey.sock`. `observed` |
| Later in same recovery window | Verification state | symptom observation | Nextcloud served the pending `33.0.2` upgrade screen. `observed` |

## Propagation Chains

### DB failure chain

1. Upstream source state:
   `v33.0.1-1+` no longer shipped `vars/main.yml`. `observed`
2. Local controller vendored dependency state:
   the control node still had `roles/galaxy/nextcloud/vars/main.yml`, and that
   file computed `nextcloud_config_dbhost` in the non-socket-aware
   `hostname:port` form. `observed`
3. Deploy input:
   the 2026-04-08 07:31Z deployment from the controller intended
   `dbhost => ':5432'`. `observed`
4. Managed-node rendered artifact:
   `config.php` on the managed node contained `dbhost => ':5432'`. `observed`
5. Managed-node runtime / symptom:
   Nextcloud then failed with missing Postgres socket errors and HTTP 500s.
   `observed`

DB root-cause framing:

- Current upstream `ansible-role-nextcloud` source state is not sufficient to
  explain the deployed DB behavior. `confirmed by inspection`
- The deployed DB behavior is best explained by stale local vendored role state
  surviving update on the controller. `inferred`, high confidence

Why existing installs were hit harder than fresh installs:

- The role rewrites DB settings in `config.php` only when `config.php` already
  exists.
- That gives already-installed instances a direct rewrite path during redeploy /
  upgrade.
- This incident does not prove fresh installs are safe. It shows only that the
  observed DB breakage propagated through a pre-existing `config.php`, which
  fresh installs do not have yet.

### Redis / Valkey failure chain

1. Upstream `mash-playbook` source state before 2026-04-03:
   docs supported hostname-based Valkey wiring. `observed`
2. Tracked inventory state:
   local inventory adopted that hostname-based pattern on 2026-01-08. `observed`
3. Upstream `ansible-role-nextcloud` source state in the `v33.0.1-1` to
   `v33.0.2-1` range:
   Redis/Valkey defaults were socket-first:
   `nextcloud_redis_socket_enabled: true`,
   `nextcloud_environment_variables_redis_host` prefers
   `/run-valkey/valkey.sock`, and the server unit mounts `/run-valkey` only
   when `nextcloud_redis_socket_path_host` is non-empty. `confirmed by inspection`
4. Local controller vendored dependency state at recovery time:
   the stale local `roles/galaxy/nextcloud/vars/main.yml` still defined
   `nextcloud_redis_is_configured` as hostname-only. `observed`
5. Deploy input before mitigation:
   inventory had `nextcloud_redis_hostname` but no
   `nextcloud_redis_socket_path_host`. Combined with the socket-first role
   defaults, that yields:
   - Redis configured = true
   - `REDIS_HOST=/run-valkey/valkey.sock`
   - no `/run-valkey` bind mount
   `confirmed by inspection`
6. Managed-node runtime / symptom:
   Nextcloud then failed against `unix:///run-valkey/valkey.sock`. `observed`
7. Mitigation deploy input:
   tracked inventory added `nextcloud_redis_socket_path_host` and retained
   `nextcloud_redis_hostname` as a compatibility input for the stale local
   `nextcloud_redis_is_configured` logic. `observed`
8. Verification state:
   Nextcloud recovered at the symptom level. `observed`
9. Later upstream source state in clean `v33.0.2-3`:
   the role defaulted Redis back to TCP and added validation for
   hostname/socket mixed states. That suggests the remaining upstream follow-up
   is now mainly docs and migration clarity, not the same role-code defect.
   `observed`

Redis / Valkey root-cause framing:

- The runtime failure does not require a current-upstream role DB-style bug.
- It does require a mixed state across loci:
  older tracked inventory plus the socket-first role behavior present in the
  deployed `v33.0.2-1`-style role state.
- The successful mitigation also depended on current local controller dependency
  state, because the hostname was retained as a compatibility input for the
  stale vendored `nextcloud_redis_is_configured` logic.
- Clean upstream `v33.0.2-3` now appears to have fixed the code-side Redis
  behavior by changing the default back to TCP and validating explicit mode
  selection.

Missing-guardrails synthesis:

- The incident was not just a single bad default. It also exposed two separate
  guardrail gaps:
  stale removed role files could survive controller-side update, and the Redis /
  Valkey mixed state in the deployed role state was allowed to reach runtime
  instead of failing earlier. Clean upstream `v33.0.2-3` later appears to have
  addressed that second gap in code.

## Recovery State by Fix Class

### Local-only rescue

- Vendored role on the controller:
  `roles/galaxy/nextcloud/vars/main.yml` was locally trimmed so it no longer
  overrides `nextcloud_config_dbhost`.
- This rescued the DB path, but it is not a tracked change.

### Tracked local mitigation

- Incident-time tracked mitigation added
  `nextcloud_redis_socket_path_host: /mash/nextcloud-valkey/run` while keeping
  `nextcloud_redis_hostname` as a compatibility input for the stale local role
  state.
- Current tracked cleanup target is stricter:
  `nextcloud_database_postgres_socket_enabled: true`,
  `nextcloud_redis_socket_enabled: true`, and
  `nextcloud_redis_socket_path_host: /mash/nextcloud-valkey/run`, with no
  hostname-based Redis compatibility input.

Combined local recovery fact:

- The incident did not resolve from analysis alone. The first observed symptom
  recovery followed a combined local change set:
  a local-only vendored role rescue for the DB path and a tracked inventory
  mitigation for the Redis / Valkey socket path.
- Git only captures part of that recovery path, because the controller-side
  vendored role rescue lived under `roles/galaxy/**`.

### Upstream durable fix

Not yet implemented. Candidate durable fixes belong in different places:

- controller dependency acquisition / cleanup path
- Redis / Valkey documentation and migration clarity
- consumer migration guidance

### Consumer adoption / cleanup

Local workarounds should not be removed until the controller can be shown to
operate with a clean vendored role tree and the incident-time hostname
compatibility input is no longer needed.

## Remaining Uncertainties

- Whether stale removed-file survival should be fixed in `mash-playbook`, in
  `agru`, or in both.
- Whether current upstream `ansible-role-nextcloud` docs should describe Redis
  mode selection more explicitly now that clean `v33.0.2-3` defaults back to
  TCP.
- Whether `mash-playbook` should add a migration note for older hostname-only
  Valkey setups once the local socket cleanup is deployed.
