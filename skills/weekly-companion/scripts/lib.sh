#!/usr/bin/env bash
# Shared helpers for the weekly-companion scripts. Source, do not execute.
# Callers set their own strict-mode preamble before sourcing.
# The constants below are consumed by the scripts that source this file,
# which shellcheck cannot see when linting lib.sh on its own.
# shellcheck disable=SC2034

readonly WEEKS_DIR_NAME="weeks"
readonly WEEK_ID_PATTERN='^[0-9]{4}-W[0-9]{2}$'
readonly INBOX_FILE="inbox.md"
readonly TODOS_FILE="todos.md"
readonly LOG_FILE="log.md"

log_info() {
    printf '[%s] INFO  %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
}

die() {
    printf '[%s] ERROR %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
    exit 1
}

# Prints the ISO-8601 week id (e.g. 2026-W46) for "now".
# %G/%V are supported by both GNU and BSD date.
current_week_id() {
    date +%G-W%V
}

validate_week_id() {
    local week_id="$1"
    [[ "${week_id}" =~ ${WEEK_ID_PATTERN} ]] \
        || die "invalid week id '${week_id}' (expected YYYY-Www, e.g. 2026-W46)"
}

# Resolves the data-repo root: explicit argument, else the git toplevel of $PWD.
resolve_root() {
    local requested_root="$1"
    if [[ -n "${requested_root}" ]]; then
        [[ -d "${requested_root}" ]] || die "root directory does not exist: ${requested_root}"
        (cd "${requested_root}" && pwd)
        return 0
    fi
    git rev-parse --show-toplevel 2>/dev/null \
        || die "not inside a git repo; pass --root <data-repo-dir>"
}

week_dir_path() {
    local root="$1"
    local week_id="$2"
    printf '%s/%s/%s\n' "${root}" "${WEEKS_DIR_NAME}" "${week_id}"
}

require_week_dir() {
    local week_dir="$1"
    [[ -d "${week_dir}" ]] \
        || die "week not initialized: ${week_dir} (run week-init.sh first)"
}
