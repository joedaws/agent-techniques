#!/usr/bin/env bash
# Commits the data repo's tracked areas (weeks/, areas.md) and pushes, retrying
# network failures with exponential backoff. Cloud containers are reclaimed
# when idle, so anything not pushed is lost.
set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

readonly MAX_PUSH_ATTEMPTS=4
# Overridable so tests need not wait through real backoff.
readonly INITIAL_BACKOFF_SECONDS="${WEEKLY_SYNC_BACKOFF_SECONDS:-2}"
readonly AREAS_FILE="areas.md"

usage() {
    printf 'Usage: %s --message <commit msg> [--root <data-repo>] [--branch <name>]\n' "$(basename "$0")" >&2
}

commit_changes() {
    local root="$1"
    local message="$2"
    local paths=("${WEEKS_DIR_NAME}")
    [[ -e "${root}/${AREAS_FILE}" ]] && paths+=("${AREAS_FILE}")
    git -C "${root}" add -- "${paths[@]}"
    if git -C "${root}" diff --cached --quiet; then
        log_info "no data changes to commit"
        return 0
    fi
    git -C "${root}" commit --quiet -m "${message}"
    log_info "committed: ${message}"
}

push_with_retry() {
    local root="$1"
    local branch="$2"
    local attempt=1
    local backoff="${INITIAL_BACKOFF_SECONDS}"
    while ! git -C "${root}" push --quiet -u origin "HEAD:refs/heads/${branch}"; do
        ((attempt < MAX_PUSH_ATTEMPTS)) \
            || die "push to ${branch} failed after ${MAX_PUSH_ATTEMPTS} attempts; data is committed locally only"
        log_info "push attempt ${attempt} failed; retrying in ${backoff}s"
        sleep "${backoff}"
        attempt=$((attempt + 1))
        backoff=$((backoff * 2))
    done
    log_info "pushed to origin/${branch}"
}

main() {
    local requested_root=""
    local message=""
    local branch=""
    while (($# > 0)); do
        case "$1" in
            --root) requested_root="${2:?--root needs a value}"; shift 2 ;;
            --message) message="${2:?--message needs a value}"; shift 2 ;;
            --branch) branch="${2:?--branch needs a value}"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) usage; die "unknown argument: $1" ;;
        esac
    done
    [[ -n "${message}" ]] || { usage; die "--message is required"; }

    local root
    root="$(resolve_root "${requested_root}")"
    [[ -d "${root}/${WEEKS_DIR_NAME}" ]] || die "no ${WEEKS_DIR_NAME}/ in ${root}; run week-init.sh first"
    if [[ -z "${branch}" ]]; then
        branch="$(git -C "${root}" symbolic-ref --quiet --short HEAD)" \
            || die "detached HEAD in ${root}; pass --branch <name>"
    fi

    commit_changes "${root}" "${message}"
    push_with_retry "${root}" "${branch}"
}

main "$@"
