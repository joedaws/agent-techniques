#!/usr/bin/env bash
# Appends one raw capture (e.g. a dictated voice message) verbatim to the
# current week's inbox under a UTC timestamp heading. Text is read from stdin
# so multi-paragraph transcripts survive intact.
set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

usage() {
    printf 'Usage: %s [--root <data-repo>] [--week <YYYY-Www>] < capture.txt\n' "$(basename "$0")" >&2
}

main() {
    local requested_root=""
    local week_id=""
    while (($# > 0)); do
        case "$1" in
            --root) requested_root="${2:?--root needs a value}"; shift 2 ;;
            --week) week_id="${2:?--week needs a value}"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) usage; die "unknown argument: $1" ;;
        esac
    done
    [[ -n "${week_id}" ]] || week_id="$(current_week_id)"
    validate_week_id "${week_id}"

    local root week_dir capture_text
    root="$(resolve_root "${requested_root}")"
    week_dir="$(week_dir_path "${root}" "${week_id}")"
    require_week_dir "${week_dir}"

    capture_text="$(cat)"
    [[ -n "${capture_text//[[:space:]]/}" ]] || die "empty capture on stdin; nothing appended"

    printf '\n### %s\n\n%s\n' "$(date -u +%Y-%m-%dT%H:%MZ)" "${capture_text}" \
        >> "${week_dir}/${INBOX_FILE}"
    log_info "captured ${#capture_text} chars into ${week_id}/${INBOX_FILE}"
}

main "$@"
