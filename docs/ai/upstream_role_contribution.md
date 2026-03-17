<!--
SPDX-FileCopyrightText: 2026 MASH project contributors

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Upstream Role Contribution Workflow

## Purpose

- Optimize upstream role PRs and new-role creation for mergeability, not just
  correctness.
- Treat merged sibling-role patterns and recent maintainer direction as
  first-class
  inputs. Treat maintainer direction as observable signals such as explicit repo
  guidance, recent review comments, and accepted recent PR shape.
- In this document, `upstream/<default>` means the default branch of the
  authoritative `upstream` remote, and sibling roles means already merged roles
  in the same ecosystem that solve comparable problems.
- Do not use this workflow for local-only fork maintenance, support-file-only
  changes not intended upstream, or work with no upstream PR, refresh, or
  new-role decision.

## Required Pre-Change Review

- Inspect the current implementation and surrounding role behavior.
- Inspect merged sibling-role implementations for similar changes or hardening.
- Treat sibling-role precedent as strong shaping evidence, not automatic truth.
- Prefer recent merged patterns unless they conflict with explicit repo
  guidance, newer maintainer direction, or role-specific constraints.
- If meaningful sibling-role precedent is weak, inconsistent, or absent, state
  that explicitly and rely more heavily on explicit repo guidance, recent
  maintainer direction, and minimal upstream-friendly structure.
- Inspect git history and relevant PR discussion when they may clarify current
  constraints, accepted patterns, or prior reviewer concerns.
- Use `intent-and-constraints-review-v1` only when the relevant constraints are
  not already clear from the implementation, tests, repo guidance, and
  sibling-role patterns.

## Branch and Base Rules

- Upstream contribution branches must start from `upstream/<default>` or a
  clean `upstreamable/*` branch rebased onto it.
- Do not base upstream PR work on fork-maintenance branches that carry
  support-file deltas (changes under fork-tracked support paths that are not
  intended for upstream review).
- These fork-tracked support paths are not automatically upstreamable:
  - `AGENTS.md`
  - `docs/ai/**`
  - `.agents/skills/**`
  - `.codex/**`
  - `local-notes/**`
  - `plans/**`
- If the diff against `upstream/<default>` includes those paths without
  explicit intent, rebuild the branch from `upstream/<default>` and reapply
  only upstream-intended commits.

## Existing-Role PR Workflow

- Keep scope tight.
- Avoid unrelated lint, formatting, or variable-migration churn unless it is
  trivial and clearly justified.
- Prefer already accepted sibling-role shaping over one-off local
  implementations.
- Confirm the proposed change matches recent maintainer direction and accepted
  sibling-role patterns, not only local preference.
- Minimize diff churn and preserve reviewer context when updating a reviewed PR.
- Reduce the final review branch to one coherent commit unless a multi-commit
  series is clearly better for review.
- Ensure the PR title and body describe the exact final diff.

## New-Role Creation Workflow

- Study sibling roles before designing defaults, templates, docs, or
  validation.
- Align role structure, docs, validation, and variable naming with the current
  role ecosystem style used by already merged sibling roles when meaningful
  precedent exists; otherwise rely more heavily on explicit repo guidance,
  recent maintainer direction, and minimal upstream-friendly structure.
- Stabilize the role shape first, then wire it into the playbook in a separate
  step or clearly separated commit series.

## Refresh and Superseded PR Workflow

- If the implementation changes materially after review starts, refresh the PR
  body and add a short comment summarizing what changed, why it changed, and
  whether prior review comments are still applicable.
- If equivalent work lands upstream, close the PR and reference the superseding
  commit.
- When refreshing an existing PR, re-check current upstream before push and
  decide whether the PR should be refreshed, superseded, or closed.

## Pre-Push Checks

- `behind=0` vs `upstream/<default>`
- changed files are exactly intended
- support-path contamination check passes (no unintended changes under
  fork-tracked support paths)
- reported lint status is current and limited to the intended scope
- final branch history matches the intended review shape (single coherent
  commit or clearly justified commit series)
- PR body/comment alignment is re-checked after rebases, squashes, or
  force-pushes
- If repo-local guidance or automation is missing, explicitly state the gap and
  perform the equivalent manual checks before push.

## Output Contract

Before push or PR update, provide:

1. contribution scenario (`existing-role`, `new-role`, or `stale-pr-refresh`)
2. repo guidance and automation consulted, plus any missing pieces
3. sibling-role patterns followed or deliberately deviated from, and why
4. branch/base/preflight status, including whether checks were scripted or manual
5. support-path contamination status
6. review-shape status
7. readiness decision: ready, blocked, or needs reshaping
8. required PR title/body/comment updates

If blocked or needing reshaping, state the blocker and the next step to clear
it.
If deviating from normal shaping, repo guidance, or review history expectations,
state the reason briefly.
