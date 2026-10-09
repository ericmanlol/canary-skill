#!/bin/bash
# Exercise uninstall behavior without touching the user's installed skills.

# Globals set: REPO_DIR, UNINSTALLER, TEST_ROOT and isolated environment.
setup() {
  REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
  UNINSTALLER=${REPO_DIR}/scripts/uninstall.sh
  TEST_ROOT=$(mktemp -d)
  readonly REPO_DIR UNINSTALLER TEST_ROOT
  export HOME=${TEST_ROOT}/home NO_COLOR=1 FORCE_COLOR=0
  unset SKILLS_DIR CANARY_NAME
  cd "${TEST_ROOT}"
}

cleanup() {
  rm -rf "${TEST_ROOT}"
}

expect_failure() {
  if "$@" > "${TEST_ROOT}/failure.log" 2>&1; then
    printf 'Expected failure: %s\n' "$*" >&2
    exit 1
  fi
}

# Create an installation at the given skills root using the real installer.
fixture() {
  CANARY_NAME='The Dude' SKILLS_DIR="$1" \
    bash "${REPO_DIR}/scripts/install.sh" >/dev/null
}

# Check default/custom paths, repeat removal, and preservation of sibling skills.
test_removal() {
  local root
  for root in "${HOME}/.agents/skills" 'custom path' '-relative'; do
    fixture "${root}"
    if [[ "${root}" == "${HOME}/.agents/skills" ]]; then
      bash "${UNINSTALLER}" >/dev/null
    else
      SKILLS_DIR="${root}" bash "${UNINSTALLER}" >/dev/null
    fi
    [[ ! -e "${root}/canary" ]]
    SKILLS_DIR="${root}" bash "${UNINSTALLER}" >/dev/null
  done
  mkdir -p "${HOME}/.agents/skills/another-skill"
  printf 'keep\n' > "${HOME}/.agents/skills/another-skill/SKILL.md"
  bash "${UNINSTALLER}" >/dev/null
  [[ -f "${HOME}/.agents/skills/another-skill/SKILL.md" ]]
}

# Extra files, including hidden files and directories, must survive.
test_extra_files() {
  local root=${TEST_ROOT}/extras
  fixture "${root}"
  printf 'keep\n' > "${root}/canary/.notes"
  mkdir "${root}/canary/references"
  SKILLS_DIR="${root}" bash "${UNINSTALLER}" >/dev/null
  [[ ! -e "${root}/canary/SKILL.md" ]]
  [[ ! -e "${root}/canary/name.txt" ]]
  [[ "$(cat "${root}/canary/.notes")" == keep ]]
  [[ -d "${root}/canary/references" ]]
  SKILLS_DIR="${root}" bash "${UNINSTALLER}" >/dev/null
}

# Validate every known file before deletion and never follow installation links.
test_refusals() {
  local root=${TEST_ROOT}/links
  mkdir "${root}"
  ln -s "${TEST_ROOT}/missing" "${root}/canary"
  expect_failure env SKILLS_DIR="${root}" bash "${UNINSTALLER}"
  [[ -L "${root}/canary" ]]
  root=${TEST_ROOT}/file-link
  fixture "${root}"
  mv "${root}/canary/name.txt" "${TEST_ROOT}/external-name"
  ln -s "${TEST_ROOT}/external-name" "${root}/canary/name.txt"
  expect_failure env SKILLS_DIR="${root}" bash "${UNINSTALLER}"
  [[ -f "${root}/canary/SKILL.md" ]]
  [[ "$(cat "${TEST_ROOT}/external-name")" == 'The Dude' ]]
  rm "${root}/canary/name.txt"
  mkdir "${root}/canary/name.txt"
  expect_failure env SKILLS_DIR="${root}" bash "${UNINSTALLER}"
  [[ -f "${root}/canary/SKILL.md" ]]
  expect_failure bash "${UNINSTALLER}" --unknown
}

main() {
  set -eEuo pipefail
  setup
  trap cleanup EXIT
  trap 'printf "Uninstall test failed at line %s\n" "${LINENO}" >&2' ERR
  test_removal
  test_extra_files
  test_refusals
  bash "${UNINSTALLER}" --help >/dev/null
  printf '✓ All uninstaller checks passed\n'
}

main "$@"
