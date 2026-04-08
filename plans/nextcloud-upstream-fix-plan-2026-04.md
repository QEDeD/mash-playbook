<!--
SPDX-FileCopyrightText: 2026 MASH project contributors

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Nextcloud Follow-Up Plan: 2026-04-08 Incident

## Purpose

Shape later issues and PRs so they are:

- causally correct
- auditable across state loci
- narrow enough for reviewer trust

This plan intentionally separates:

- local-only rescue
- tracked local mitigation
- upstream durable fix
- consumer adoption / cleanup

## Claim Readiness

| Claim | Current status | Why |
| --- | --- | --- |
| Current upstream `ansible-role-nextcloud` still has the DB rewrite bug | Not PR-ready | Clean upstream tags `v33.0.1-1` through `v33.0.2-1` do not contain the stale `vars/main.yml` that drove the deployed DB behavior. |
| Controller role update can preserve removed role files | Issue-ready; PR-ready once owner is chosen | Confirmed by local `/tmp` reproduction with `agru`, but the permanent owner may still be `agru`, `mash-playbook`, or a split fix. |
| Current upstream `ansible-role-nextcloud` docs are stale for Redis / Valkey mode selection | PR-ready with caveats | Clean upstream `v33.0.2-3` defaults `nextcloud_redis_socket_enabled: false` and validates hostname/socket combinations, but `docs/configuring-nextcloud.md` still describes socket mode as the default and omits the explicit socket-mode flag from the socket example. |
| MASH needs migration guidance for older hostname-only Nextcloud Valkey setups | PR-ready with caveats | Older MASH docs used hostname-only Valkey wiring; newer docs switched to socket-path wiring. The wording should stay migration-focused and avoid broad role-bug claims. |

Guardrail synthesis:

- The incident points to two different guardrail failures, which should stay
  separate in later PRs:
  controller-side dependency acquisition did not guarantee removed files were
  actually removed, and the older Redis / Valkey behavior transition left room
  for mixed old/new socket expectations before current upstream code tightened
  the mode selection rules.

Existing installs versus fresh installs:

- The DB incident should be framed as especially relevant to existing installs,
  because the bad path was propagated by rewriting an already-present
  `config.php` during redeploy.
- Do not generalize that behavior into a fresh-install safety claim without
  separate proof.

Timestamp / propagation reminder:

- Upstream history timestamps establish when a source state existed.
- They do not establish when that state reached the controller, the managed
  node, or the running process.
- PRs and issues should cite deploy-time and managed-node evidence separately
  when connecting source history to observed behavior.

## PR-Quality Rules

Before filing anything upstream:

1. State the locus for every important claim:
   upstream source, controller vendored dependency, tracked inventory, rendered
   artifact, runtime, or symptom.
2. Provide a propagation chain before implying causality.
3. Use the narrowest repo target supported by the evidence.
4. Do not mix local rescue evidence with claims about current upstream source
   state unless the propagation chain is explicit.

## Repo Targets

## 1. Controller dependency acquisition: `mash-playbook` and/or `agru`

### Problem statement

The controller can acquire a newer role version while still keeping files that
were removed upstream.

### Evidence chain

1. Upstream source:
   `ansible-role-nextcloud` `v33.0.2-1` does not ship `vars/main.yml`.
2. Controller vendored dependency state:
   local `roles/galaxy/nextcloud` recorded `v33.0.2-1` but still contained
   `vars/main.yml`.
3. Local reproduction:
   a `/tmp` `agru` update from `v33.0.1-0` to `v33.0.2-1` leaves the removed
   `vars/main.yml` in place.

### Ownership status

- `agru` is the narrowest proven reproduction locus today.
- `mash-playbook` may still be a valid fix locus if it chooses to defend
  against stale role trees before or after dependency acquisition.
- The current evidence is sufficient to open an issue, but not yet to decide
  the final PR target without maintainer input or a stronger workflow audit.

### Scope options

1. `mash-playbook`
   - clean `roles/galaxy` before `agru`
   - or change the update workflow so removed files cannot survive
2. `agru`
   - fix stale-file retention directly

### Issue / PR output wanted

- minimal reproduction script
- exact expected versus actual post-update role tree state
- owner decision: `mash-playbook`, `agru`, or split follow-up

## 2. `ansible-role-nextcloud`: Redis / Valkey docs alignment

### Problem statement

Clean upstream `ansible-role-nextcloud` `v33.0.2-3` no longer matches its own
Redis / Valkey docs:

- code defaults `nextcloud_redis_socket_enabled: false`
- validation requires explicit hostname-versus-socket mode selection
- docs still say Unix socket mode is the default
- the socket example still omits `nextcloud_redis_socket_enabled: true`

### Current evidence chain

1. Upstream source:
   clean `v33.0.2-3` defaults set:
   - `nextcloud_redis_socket_enabled: false`
2. Upstream source:
   clean `v33.0.2-3` validation rejects:
   - hostname + socket path together
   - hostname while socket mode is enabled
   - socket path while socket mode is disabled
3. Tracked inventory:
   the current upstream docs still describe socket mode as the default and the
   socket example still lacks the explicit socket-mode flag
4. Incident context:
   that doc/code drift matters because older hostname-only inventory existed in
   the field and the local recovery now needs explicit socket-mode inventory to
   stay on sockets after updating to a clean current role tree

### Candidate durable fix

Update `docs/configuring-nextcloud.md` so it matches the current code:

1. say explicitly that Redis / Valkey uses TCP by default in current upstream
2. update the socket example to set:
   - `nextcloud_redis_socket_enabled: true`
   - `nextcloud_redis_socket_path_host: ...`
3. keep the TCP example explicit with:
   - `nextcloud_redis_socket_enabled: false`
   - `nextcloud_redis_hostname: ...`
4. optionally add one short migration note that older hostname-only configs may
   need explicit mode selection during upgrades

### What this PR should not claim

- It should not claim that current upstream still contains the DB rewrite bug.
- It should not claim that current upstream still has the same Redis runtime bug
  class seen in the incident.
- It should not rely on local stale vendored `vars/main.yml` as if it were
  current upstream source state.

### Recommended strengthening before PR

- capture the exact `v33.0.2-3` doc lines alongside the matching defaults and
  validation lines
- keep the PR narrowly documentation-focused
- avoid reopening the code-path question unless new evidence appears

### Minimal doc checks

1. socket example includes `nextcloud_redis_socket_enabled: true`
2. TCP example includes `nextcloud_redis_socket_enabled: false`
3. descriptive text matches the current code default

## 3. `mash-playbook`: migration guidance for older Nextcloud Valkey configs

### Problem statement

MASH docs moved from hostname-based Valkey examples to socket-path examples, but
older inventories may still follow the earlier pattern.

### Evidence chain

1. Older MASH docs documented hostname-based Valkey wiring.
2. Local tracked inventory adopted that pattern.
3. Newer MASH docs switched to socket-path wiring.
4. Clean upstream role releases now require explicit socket-mode opt-in if the
   operator wants to keep using the Unix socket path.

### Candidate doc change

Add a short migration note near the Nextcloud Valkey section:

- older hostname-only configs may need explicit mode selection:
  - socket mode:
    set `nextcloud_redis_socket_enabled: true` and
    `nextcloud_redis_socket_path_host`
  - TCP mode:
    set `nextcloud_redis_socket_enabled: false` and keep hostname

## Local Cleanup Conditions

Treat local recovery workarounds as removable only after:

1. controller role acquisition has been re-run in a way that guarantees removed
   role files are gone
2. `roles/galaxy/nextcloud/vars/main.yml` is absent on the controller
3. a new targeted deploy succeeds without the vendored DB rescue
4. Nextcloud remains healthy with explicit socket-mode inventory:
   `nextcloud_database_postgres_socket_enabled: true`,
   `nextcloud_redis_socket_enabled: true`, and
   `nextcloud_redis_socket_path_host: ...`

Current incident-resolution fact:

- The symptom recovery observed during this incident came from a combined local
  change set, not a single upstream-aligned fix:
  a local vendored-role DB rescue plus a tracked inventory Redis / Valkey
  mitigation.

## Still-Assumed Areas

These areas are not yet fully proven:

- whether `mash-playbook`, `agru`, or both should own stale-role cleanup
- whether `ansible-role-nextcloud` docs should also include a short migration
  note or stay strictly example-focused
- whether `mash-playbook` should mirror that migration note after the local
  inventory cleanup is deployed
