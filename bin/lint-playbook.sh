#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 MASH project contributors
#
# SPDX-License-Identifier: AGPL-3.0-or-later

set -euo pipefail

log() {
  echo "[lint-playbook] $*"
}

append_existing_path() {
  local -n target_paths=$1
  local path=$2

  if [[ -e "${path}" ]]; then
    target_paths+=("${path}")
  fi
}

append_env_paths() {
  local -n target_paths=$1
  local env_var_name=$2
  local label=$3
  local env_value="${!env_var_name:-}"
  local path

  if [[ -z "${env_value}" ]]; then
    return 0
  fi

  for path in ${env_value}; do
    if [[ -e "${path}" ]]; then
      target_paths+=("${path}")
    else
      log "note: ${label} ${path} skipped (not found)."
    fi
  done
}

append_host_var_files() {
  local -n target_paths=$1
  local host_vars_dir=${2:-inventory/host_vars}

  if [[ ! -d "${host_vars_dir}" ]]; then
    return 0
  fi

  while IFS= read -r file; do
    target_paths+=("${file}")
  done < <(find "${host_vars_dir}" -maxdepth 2 -type f \
    \( -name 'vars.yml' -o -name 'vars.yaml' \) \
    ! -name '*.bak' ! -path '*_bak/*' \
    ! -name 'vault*.yml' ! -name 'vault*.yaml' \
    | sort)
}

is_ansible_role_dir() {
  local dir=$1
  local marker

  for marker in tasks defaults handlers vars meta templates; do
    if [[ -e "${dir}/${marker}" ]]; then
      return 0
    fi
  done

  return 1
}

append_local_custom_roles() {
  local -n target_paths=$1
  local custom_roles_dir=${2:-roles/custom}
  local role_dir

  if [[ ! -d "${custom_roles_dir}" ]]; then
    return 0
  fi

  while IFS= read -r role_dir; do
    if is_ansible_role_dir "${role_dir}"; then
      target_paths+=("${role_dir}")
    fi
  done < <(find "${custom_roles_dir}" -mindepth 1 -maxdepth 1 -type d | sort)
}

dedupe_paths() {
  local -n source_paths=$1

  if [[ ${#source_paths[@]} -eq 0 ]]; then
    return 0
  fi

  printf '%s\n' "${source_paths[@]}" | sort -u | grep -Ev '(^|/)(\.venv|venv)(/|$)' || true
}

repo_root=$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null || true)
if [[ -z "${repo_root}" ]]; then
  log "error: run this script inside a git repository."
  exit 1
fi

cd "${repo_root}"

if [[ -f group_vars/mash_servers ]]; then
  playbook="mash"
elif [[ -f group_vars/matrix_servers ]]; then
  playbook="matrix"
else
  log "error: unable to detect playbook type (expected group_vars/mash_servers or group_vars/matrix_servers)."
  exit 1
fi

log "detected ${playbook^^} playbook at ${repo_root}"

git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
git_commit=$(git rev-parse --short HEAD 2>/dev/null || true)
if [[ -n "${git_branch}" && -n "${git_commit}" ]]; then
  log "git branch: ${git_branch} (${git_commit})"
else
  log "warning: unable to determine git branch/commit."
fi

lint_scope="${LINT_PLAYBOOK_SCOPE:-scoped}"
case "${lint_scope}" in
  scoped|full)
    ;;
  *)
    log "error: invalid LINT_PLAYBOOK_SCOPE='${lint_scope}'. Use 'scoped' or 'full'."
    exit 1
    ;;
esac
log "lint scope: ${lint_scope}"

upgrade_tools="${LINT_PLAYBOOK_UPGRADE_TOOLS:-1}"
case "${upgrade_tools}" in
  0|1)
    ;;
  *)
    log "error: invalid LINT_PLAYBOOK_UPGRADE_TOOLS='${upgrade_tools}'. Use '0' or '1'."
    exit 1
    ;;
esac
if [[ "${upgrade_tools}" == "1" ]]; then
  log "tool upgrades: enabled"
else
  log "tool upgrades: disabled (will only install missing packages)"
fi

python_bin="${PYTHON:-python3}"
venv_path="${LINT_PLAYBOOK_VENV:-${repo_root}/.venv}"

log "using Python interpreter: ${python_bin}"
log "desired virtualenv location: ${venv_path}"

python_cmd=$(command -v "${python_bin}" || true)
if [[ -z "${python_cmd}" ]]; then
  log "error: ${python_bin} is not available in PATH."
  exit 1
fi

if [[ ! -d "${venv_path}" ]]; then
  log "virtualenv missing, creating a new one..."
  "${python_cmd}" -m venv "${venv_path}"
else
  log "virtualenv already exists, reusing current installation."
fi

# If the venv is corrupted (missing activate), rebuild it.
if [[ ! -f "${venv_path}/bin/activate" ]]; then
  log "virtualenv missing activation script; rebuilding..."
  "${python_cmd}" -m venv --clear "${venv_path}"
fi

# shellcheck disable=SC1090,SC1091
source "${venv_path}/bin/activate"
log "virtualenv activated: ${venv_path}"

venv_python="${venv_path}/bin/python"

if ! "${venv_python}" - <<'PY' >/dev/null 2>&1; then
import pip  # noqa: F401
PY
  log "pip missing inside virtualenv; bootstrapping with ensurepip..."
  if ! "${venv_python}" -m ensurepip --upgrade >/dev/null 2>&1; then
    log "ensurepip unavailable in virtualenv; rebuilding virtualenv..."
    deactivate || true
    "${python_cmd}" -m venv --clear "${venv_path}"
    # shellcheck disable=SC1090,SC1091
    source "${venv_path}/bin/activate"
    venv_python="${venv_path}/bin/python"
    if ! "${venv_python}" - <<'PY' >/dev/null 2>&1; then
import pip  # noqa: F401
PY
      log "error: pip still unavailable. Install Python ensurepip/venv support and re-run."
      deactivate || true
      exit 1
    fi
  fi
fi

if [[ "${upgrade_tools}" == "1" ]]; then
  log "updating pip/setuptools/wheel..."
  "${venv_python}" -m pip install --upgrade pip setuptools wheel >/dev/null

  log "ensuring ansible-core, ansible-lint, and pre-commit are current..."
  "${venv_python}" -m pip install --upgrade ansible-core ansible-lint pre-commit >/dev/null
else
  mapfile -t missing_packages < <("${venv_python}" - <<'PY'
import importlib.util

checks = [
    ("ansible", "ansible-core"),
    ("ansiblelint", "ansible-lint"),
    ("pre_commit", "pre-commit"),
]

for module_name, package_name in checks:
    if importlib.util.find_spec(module_name) is None:
        print(package_name)
PY
)

  if [[ ${#missing_packages[@]} -gt 0 ]]; then
    log "installing missing packages: ${missing_packages[*]}"
    "${venv_python}" -m pip install "${missing_packages[@]}" >/dev/null
  else
    log "reusing installed ansible-core, ansible-lint, and pre-commit."
  fi
fi

gather_file_targets() {
  local mode=$1
  local -a paths=()

  append_host_var_files paths

  case "${mode}" in
    mash)
      append_existing_path paths inventory/hosts
      append_existing_path paths group_vars/mash_servers
      ;;
    matrix)
      append_existing_path paths inventory/hosts
      append_existing_path paths group_vars/matrix_servers
      if [[ "${lint_scope}" == "full" ]]; then
        append_existing_path paths group_vars/jitsi_jvb_servers
        append_existing_path paths jitsi_jvb.yml
      fi
      ;;
  esac

  append_env_paths paths EXTRA_LINT_PATHS EXTRA_LINT_PATH

  dedupe_paths paths
}

gather_role_targets() {
  local mode=$1
  local -a paths=()

  if [[ "${lint_scope}" == "full" ]]; then
    append_local_custom_roles paths roles/custom

    if [[ "${mode}" == "matrix" ]]; then
      append_existing_path paths roles/docker_ansible_summary
    fi
  fi

  append_env_paths paths LINT_PLAYBOOK_ROLE_PATHS LINT_PLAYBOOK_ROLE_PATH

  dedupe_paths paths
}

mapfile -t relevant_files < <(gather_file_targets "${playbook}")

if [[ ${#relevant_files[@]} -eq 0 ]]; then
  log "no relevant files detected; nothing to lint."
  deactivate
  exit 0
fi

log "lint target list (${#relevant_files[@]} files):"
printf '  - %s\n' "${relevant_files[@]}"

log "running pre-commit on filtered list..."
pre-commit run --files "${relevant_files[@]}"

mapfile -t ansible_targets < <(printf '%s\n' "${relevant_files[@]}" | grep -E '\.(yml|yaml)$' || true)
if [[ ${#ansible_targets[@]} -gt 0 ]]; then
  log "running ansible-lint on YAML files..."
  ansible-lint "${ansible_targets[@]}"
else
  log "skipping ansible-lint (no YAML files in target list)."
fi

mapfile -t role_targets < <(gather_role_targets "${playbook}")
if [[ ${#role_targets[@]} -gt 0 ]]; then
  log "running ansible-lint on role paths: ${role_targets[*]}"
  ansible-lint "${role_targets[@]}"
else
  log "no additional role directories selected for linting."
fi

if [[ "${LINT_PLAYBOOK_RUN_JUST:-0}" == "1" ]]; then
  if command -v just >/dev/null 2>&1; then
    log "running 'just lint' per request (this scans the entire repo)."
    just lint
  else
    log "skipping 'just lint'; executable not found."
  fi
else
  log "skipping 'just lint' (set LINT_PLAYBOOK_RUN_JUST=1 to enable)."
fi

deactivate
log "virtualenv deactivated."
