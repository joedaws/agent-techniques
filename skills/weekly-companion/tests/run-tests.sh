#!/usr/bin/env bash
# Behavior tests for the weekly-companion scripts. Plain bash, no framework.
# Each test runs in a fresh temp data repo. Exit status is nonzero on failure.
set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TESTS_DIR
# Used by the sourced test cases.
# shellcheck disable=SC2034
readonly SCRIPTS_DIR="${TESTS_DIR}/../scripts"
WORK_DIR="$(mktemp -d -t weekly-companion-tests.XXXXXX)"
readonly WORK_DIR
trap 'rm -rf "${WORK_DIR}"' EXIT

failures=0
passes=0

fail() {
    printf '  FAIL: %s\n' "$*" >&2
    return 1
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    [[ "${haystack}" == *"${needle}"* ]] || fail "expected to find [${needle}] in:"$'\n'"${haystack}"
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    [[ "${haystack}" != *"${needle}"* ]] || fail "did not expect [${needle}] in:"$'\n'"${haystack}"
}

new_data_repo() {
    local repo
    repo="$(mktemp -d "${WORK_DIR}/repo.XXXXXX")"
    git -C "${repo}" init --quiet --initial-branch=main
    git -C "${repo}" config user.email "test@example.invalid"
    git -C "${repo}" config user.name "test"
    # The host may enforce commit signing globally; test repos must not.
    git -C "${repo}" config commit.gpgsign false
    printf '%s\n' "${repo}"
}

run_test() {
    local test_name="$1"
    local status
    # errexit is ignored inside an `if` condition, so run the test as a plain
    # command with errexit re-enabled in its subshell and capture the status.
    set +o errexit
    ( set -o errexit; "${test_name}" ) 2>"${WORK_DIR}/stderr"
    status=$?
    set -o errexit
    if ((status == 0)); then
        passes=$((passes + 1))
        printf 'ok   %s\n' "${test_name}"
    else
        failures=$((failures + 1))
        printf 'FAIL %s\n' "${test_name}"
        sed 's/^/     /' "${WORK_DIR}/stderr"
    fi
}

# shellcheck source=test-cases.sh
source "${TESTS_DIR}/test-cases.sh"

main() {
    local test_name
    for test_name in $(declare -F | awk '{print $3}' | grep '^test_'); do
        run_test "${test_name}"
    done
    printf '\n%d passed, %d failed\n' "${passes}" "${failures}"
    ((failures == 0))
}

main "$@"
