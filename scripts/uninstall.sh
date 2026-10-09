#!/bin/bash
# Remove Canary's known files; repeated removal is a successful no-op.

# Arguments: ANSI style number. Outputs: style only when color is enabled.
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
  printf '\n  CANARY — Uninstall\n'
  color 0
  printf '  Usage: bash scripts/uninstall.sh\n\n'
  printf '  SKILLS_DIR     Destination (default: ~/.agents/skills)\n'
  printf '  NO_COLOR=1     Disable colors\n'
  printf '  FORCE_COLOR=1  Enable colors in redirected output\n\n'
}

# Check all known entries before removing any files.
# Arguments: destination directory. Exits nonzero for unsafe entry types.
validate_destination() {
  local destination=$1 file
  [[ ! -L "${destination}" ]] || fail 'Refusing a symlinked installation.'
  [[ -d "${destination}" ]] || fail 'Installation path is not a directory.'
  for file in SKILL.md name.txt; do
    if [[ -L "${destination}/${file}" ]]; then
      fail "Refusing symlinked file: ${destination}/${file}"
    fi
    if [[ -e "${destination}/${file}" &&
          ! -f "${destination}/${file}" ]]; then
      fail "Not a regular file: ${destination}/${file}"
    fi
  done
}

# Remove known files only, retaining directories containing anything else.
# Arguments: destination directory. Outputs: removal or preservation status.
remove_installation() {
  local destination=$1
  local remaining=()
  rm -f "${destination}/SKILL.md" "${destination}/name.txt"
  shopt -s nullglob dotglob
  remaining=("${destination}"/*)
  if [[ ${#remaining[@]} -eq 0 ]]; then
    rmdir "${destination}"
    color 32
    printf '✓ Canary uninstalled: %s\n' "${destination}"
  else
    color 33
    printf 'Canary files removed; extra files preserved in: %s\n' \
      "${destination}"
  fi
  color 0
}

main() {
  set -euo pipefail
  if [[ $# -eq 1 && ( $1 == -h || $1 == --help ) ]]; then
    show_help
    return 0
  fi
  [[ $# -eq 0 ]] || fail 'Unexpected arguments. Use --help.'
  local root=${SKILLS_DIR:-${HOME:?HOME must be set}/.agents/skills}
  local destination
  case "${root}" in
    /*|./*|../*) ;;
    *) root=./${root} ;;
  esac
  destination=${root}/canary
  if [[ ! -e "${destination}" && ! -L "${destination}" ]]; then
    printf 'Canary is already absent: %s\n' "${destination}"
    return 0
  fi
  validate_destination "${destination}"
  remove_installation "${destination}"
}

main "$@"
