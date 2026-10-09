#!/bin/bash
# Test the real installer in a disposable environment, without frameworks.

# Establish immutable fixture paths and isolate the caller's configuration.
# Globals set: REPO_DIR, INSTALLER, TEST_ROOT; HOME and installer environment.
setup() {
  REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
  INSTALLER=${REPO_DIR}/scripts/install.sh
  TEST_ROOT=$(mktemp -d)
  readonly REPO_DIR INSTALLER TEST_ROOT
  unset CANARY_NAME SKILLS_DIR CODEX_HOME
  export HOME=${TEST_ROOT}/home USER=sample-user NO_COLOR=1 FORCE_COLOR=0
  cd "${TEST_ROOT}"
}

cleanup() {
  rm -rf "${TEST_ROOT}"
}

report_failure() {
  printf 'Failed at test line %s\n' "$1" >&2
}

# Run a command that must fail. Globals read: TEST_ROOT. Arguments: command.
expect_failure() {
  if "$@" > "${TEST_ROOT}/failure.log" 2>&1; then
    printf 'Expected failure: %s\n' "$*" >&2
    cat "${TEST_ROOT}/failure.log" >&2
    exit 1
  fi
}

# Verify defaults, foreign working directory, and no rewrites on repeat installs.
# Globals read: INSTALLER, REPO_DIR, HOME, TEST_ROOT.
test_idempotence() {
  local destination=${HOME}/.agents/skills/canary
  bash "${INSTALLER}" >/dev/null
  [[ "$(cat "${destination}/name.txt")" == sample-user ]]
  cmp "${REPO_DIR}/skills/canary/SKILL.md" "${destination}/SKILL.md"
  touch -t 200001010000 "${TEST_ROOT}/timestamp"
  touch -r "${TEST_ROOT}/timestamp" \
    "${destination}/name.txt" "${destination}/SKILL.md"
  bash "${INSTALLER}" >/dev/null
  local file
  for file in name.txt SKILL.md; do
    [[ ! "${destination}/${file}" -nt "${TEST_ROOT}/timestamp" ]]
    [[ ! "${destination}/${file}" -ot "${TEST_ROOT}/timestamp" ]]
  done
  expect_failure env CANARY_NAME=Different bash "${INSTALLER}"
  [[ "$(cat "${destination}/name.txt")" == sample-user ]]
  printf '\nLocal change\n' >> "${destination}/SKILL.md"
  cp "${destination}/SKILL.md" "${TEST_ROOT}/modified-skill"
  expect_failure bash "${INSTALLER}"
  cmp "${destination}/SKILL.md" "${TEST_ROOT}/modified-skill"
}

# Verify names are literal data and invalid names cause no installation.
# Globals read: INSTALLER, TEST_ROOT.
test_names() {
  local name long_name
  local root=${TEST_ROOT}/skills\ with\ spaces
  # Keep command-substitution syntax literal to test safe name handling.
  # shellcheck disable=SC2016
  local literal='The Dude "Ace" $(touch SHOULD_NOT_EXIST)'
  CANARY_NAME="${literal}" SKILLS_DIR="${root}" \
    bash "${INSTALLER}" >/dev/null
  [[ "$(cat "${root}/canary/name.txt")" == "${literal}" ]]
  [[ ! -e SHOULD_NOT_EXIST ]]
  long_name=$(printf '%101s' x)
  for name in '' '   ' $'The Dude\nOther' $'The Dude\tOther' "${long_name}"; do
    expect_failure env CANARY_NAME="${name}" \
      SKILLS_DIR="${TEST_ROOT}/invalid" bash "${INSTALLER}"
  done
  [[ ! -e "${TEST_ROOT}/invalid" ]]
  expect_failure bash "${INSTALLER}" --unknown
  expect_failure bash "${INSTALLER}" --help extra
}

# Refuse destination and installed-file symlinks; accept caller-relative paths.
# Globals read: INSTALLER, TEST_ROOT.
test_paths() {
  local root=${TEST_ROOT}/links
  mkdir -p "${root}"
  ln -s "${TEST_ROOT}/missing" "${root}/canary"
  expect_failure env SKILLS_DIR="${root}" bash "${INSTALLER}"
  [[ -L "${root}/canary" ]]
  SKILLS_DIR=-relative bash "${INSTALLER}" >/dev/null
  [[ -f ./-relative/canary/SKILL.md ]]
  mv ./-relative/canary/name.txt "${TEST_ROOT}/external-name"
  ln -s "${TEST_ROOT}/external-name" ./-relative/canary/name.txt
  expect_failure env SKILLS_DIR=-relative bash "${INSTALLER}"
  [[ "$(cat "${TEST_ROOT}/external-name")" == sample-user ]]
}

# Inject copy and publish failures, then verify cleanup and a successful retry.
# Globals read: INSTALLER, TEST_ROOT, PATH.
test_rollback() {
  local command root bin
  for command in cp mv; do
    root=${TEST_ROOT}/rollback-${command}
    bin=${TEST_ROOT}/bin-${command}
    mkdir "${bin}"
    printf '#!/bin/sh\nexit 1\n' > "${bin}/${command}"
    chmod +x "${bin}/${command}"
    expect_failure env PATH="${bin}:${PATH}" SKILLS_DIR="${root}" \
      bash "${INSTALLER}"
    [[ ! -e "${root}/canary" ]]
    SKILLS_DIR="${root}" bash "${INSTALLER}" >/dev/null
    [[ -f "${root}/canary/SKILL.md" ]]
  done
}

# Check forced colors and their suppression without depending on a real TTY.
# Globals read: INSTALLER, NO_COLOR.
test_colors() {
  NO_COLOR='' FORCE_COLOR=1 bash "${INSTALLER}" --help > color
  FORCE_COLOR=1 bash "${INSTALLER}" --help > plain
  NO_COLOR='' FORCE_COLOR=0 TERM=dumb bash "${INSTALLER}" --help > dumb-output.txt
  grep -q $'\033' color
  if grep -q $'\033' plain || grep -q $'\033' dumb-output.txt; then
    printf 'Color controls were ignored.\n' >&2
    exit 1
  fi
}

main() {
  set -eEuo pipefail
  setup
  trap cleanup EXIT
  trap 'report_failure "${LINENO}"' ERR
  test_idempotence
  test_names
  test_paths
  test_rollback
  test_colors
  printf '✓ All installer checks passed\n'
}

main "$@"
