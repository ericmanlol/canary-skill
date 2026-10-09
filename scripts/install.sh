#!/bin/bash
# Install Canary from any directory; identical installs are successful no-ops.

# Print a requested ANSI style when color output is enabled.
# Arguments: ANSI style number. Outputs: escape sequence, or nothing.
color() {
  if [[ -z "${NO_COLOR:-}" ]] &&
      { [[ -t 1 && "${TERM:-}" != dumb ]] ||
        [[ "${FORCE_COLOR:-0}" == 1 ]]; }; then
    printf '\033[%sm' "$1"
  fi
}

fail() {
  color 31 >&2
  printf '✗ %s\n' "$1" >&2
  color 0 >&2
  exit 1
}

show_help() {
  color '1;36'
  printf '\n  CANARY\n'
  color 0
  printf '  Install: bash /path/to/canary-skill/scripts/install.sh\n\n'
  printf '  CANARY_NAME    Preferred name (default: installed name, then USER)'
  printf '\n  SKILLS_DIR     Destination (default: ~/.agents/skills)\n'
  printf '  NO_COLOR=1     Disable colors\n'
  printf '  FORCE_COLOR=1  Enable colors in redirected output\n\n'
  printf "  Example: CANARY_NAME='The Dude' bash scripts/install.sh\n\n"
}

validate_name() {
  local name=$1
  if [[ -z "${name}" || ${#name} -gt 100 ]]; then
    fail 'Set CANARY_NAME to a name of 1–100 characters.'
  fi
  if [[ "${name}" =~ [[:cntrl:]] ]]; then
    fail 'The name must be one line without control characters.'
  fi
  if [[ ! "${name}" =~ [^[:space:]] ]]; then
    fail 'The name cannot be only whitespace.'
  fi
}

# Refuse unsafe or incomplete existing installations before reading or writing.
# Arguments: destination directory. Exits nonzero when validation fails.
validate_existing() {
  local destination=$1 file
  [[ -d "${destination}" && ! -L "${destination}" ]] ||
    fail "Unsafe installation directory: ${destination}"
  for file in SKILL.md name.txt; do
    [[ -f "${destination}/${file}" && ! -L "${destination}/${file}" ]] ||
      fail "Expected a regular file: ${destination}/${file}"
  done
}

# Stage changes before publishing; leave unrelated files and equal files alone.
# Arguments: destination directory, source skill, preferred name.
# Name changes require an explicit CANARY_NAME. Renames are atomic per file.
update_existing() {
  local destination=$1 source_file=$2 name=$3
  (
    local staging
    staging=$(mktemp -d "${destination}/.update.XXXXXX")
    trap 'rm -f "${staging}/SKILL.md" "${staging}/name.txt"; \
      rmdir "${staging}"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    cp "${source_file}" "${staging}/SKILL.md"
    printf '%s\n' "${name}" > "${staging}/name.txt"
    if ! cmp -s "${staging}/SKILL.md" "${destination}/SKILL.md"; then
      mv "${staging}/SKILL.md" "${destination}/SKILL.md"
    fi
    if [[ ${CANARY_NAME+x} ]] &&
        ! cmp -s "${staging}/name.txt" "${destination}/name.txt"; then
      mv "${staging}/name.txt" "${destination}/name.txt"
    fi
  )
}

# Return success only for regular, identical installed files.
# Arguments: destination directory, source skill, preferred name.
# Returns: 0 for an exact match; 1 for a conflict or incomplete installation.
installation_matches() {
  local destination=$1 source_file=$2 name=$3
  [[ -d "${destination}" && ! -L "${destination}" ]] || return 1
  [[ -f "${destination}/SKILL.md" &&
     ! -L "${destination}/SKILL.md" ]] || return 1
  [[ -f "${destination}/name.txt" &&
     ! -L "${destination}/name.txt" ]] || return 1
  cmp -s "${source_file}" "${destination}/SKILL.md" || return 1
  cmp -s <(printf '%s\n' "${name}") "${destination}/name.txt"
}

# Remove only files created by a failed installation; preserve published skills.
# Arguments: reserved destination directory. Called by the install EXIT trap.
cleanup_installation() {
  local destination=$1
  if [[ ! -e "${destination}/SKILL.md" ]]; then
    rm -f "${destination}/name.txt" "${destination}/.SKILL.md"
    rmdir "${destination}" 2>/dev/null || true
  fi
}

# Reserve a new directory and publish the entry point after all data is ready.
# Arguments: destination directory, source skill, preferred name.
# A subshell keeps cleanup traps local and their variables alive through EXIT.
install_new() {
  local destination=$1 source_file=$2 name=$3
  (
    mkdir -p "$(dirname -- "${destination}")"
    mkdir "${destination}"
    trap 'cleanup_installation "${destination}"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    printf '%s\n' "${name}" > "${destination}/name.txt"
    cp "${source_file}" "${destination}/.SKILL.md"
    mv "${destination}/.SKILL.md" "${destination}/SKILL.md"
  )
}

report_installation() {
  color 32
  printf '\n✓ %s\n' "$1"
  color 0
  printf '  Name  %s\n  Path  %s\n\n' "$2" "$3"
}

# Parse options, resolve caller configuration, and reconcile installation state.
# Arguments: optional -h or --help. Returns: 0 on success; nonzero on failure.
main() {
  set -euo pipefail
  if [[ $# -eq 1 && ( $1 == -h || $1 == --help ) ]]; then
    show_help
    return 0
  fi
  [[ $# -eq 0 ]] || fail 'Unexpected arguments. Use --help.'

  local name
  local root=${SKILLS_DIR:-${HOME:?HOME must be set}/.agents/skills}
  local script_dir source_file destination
  script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
  source_file=${script_dir}/../skills/canary/SKILL.md
  case "${root}" in
    /*|./*|../*) ;;
    *) root=./${root} ;;
  esac
  destination=${root}/canary
  [[ -r "${source_file}" ]] || fail "Cannot read: ${source_file}"

  if [[ -e "${destination}" || -L "${destination}" ]]; then
    validate_existing "${destination}"
  fi
  if [[ ${CANARY_NAME+x} ]]; then
    name=${CANARY_NAME}
  elif [[ -f "${destination}/name.txt" ]]; then
    name=$(cat "${destination}/name.txt")
  else
    name=${USER-}
  fi
  validate_name "${name}"

  if [[ -d "${destination}" ]]; then
    if installation_matches "${destination}" "${source_file}" "${name}"; then
      report_installation 'Canary is already up to date' "${name}" \
        "${destination}"
      return 0
    fi
    update_existing "${destination}" "${source_file}" "${name}"
    report_installation 'Canary updated' "${name}" "${destination}"
    return 0
  fi
  install_new "${destination}" "${source_file}" "${name}"
  report_installation 'Canary installed' "${name}" "${destination}"
}

main "$@"
