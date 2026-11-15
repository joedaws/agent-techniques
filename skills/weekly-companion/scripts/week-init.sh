#!/usr/bin/env bash
# Creates weeks/<YYYY-Www>/ in the data repo and carries over open todos
# from the most recent earlier week. Idempotent: an existing week is left alone.
set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

usage() {
    printf 'Usage: %s [--root <data-repo>] [--week <YYYY-Www>]\n' "$(basename "$0")" >&2
}

# Prints the id of the latest week directory strictly before $2, or nothing.
find_previous_week() {
    local weeks_root="$1"
    local week_id="$2"
    [[ -d "${weeks_root}" ]] || return 0
    local candidate
    local previous=""
    for candidate in "${weeks_root}"/*/; do
        candidate="$(basename "${candidate}")"
        [[ "${candidate}" =~ ${WEEK_ID_PATTERN} ]] || continue
        [[ "${candidate}" < "${week_id}" ]] || continue
        [[ "${candidate}" > "${previous}" ]] && previous="${candidate}"
    done
    printf '%s' "${previous}"
}

# Prints the open todo lines of a todos file with carry:N incremented.
carried_open_todos() {
    local todos_path="$1"
    [[ -f "${todos_path}" ]] || return 0
    awk '
        /^- \[ \] / {
            if (match($0, / carry:[0-9]+/)) {
                count = substr($0, RSTART + 7, RLENGTH - 7) + 1
                $0 = substr($0, 1, RSTART - 1) " carry:" count substr($0, RSTART + RLENGTH)
            } else {
                $0 = $0 " carry:1"
            }
            print
        }
    ' "${todos_path}"
}

write_todos_file() {
    local week_dir="$1"
    local week_id="$2"
    local carried="$3"
    {
        printf '# Todos — %s\n\n' "${week_id}"
        printf '<!-- open:  - [ ] <text> #work|#life [!1|!2|!3] [due:YYYY-MM-DD] added:YYYY-MM-DD [carry:N] -->\n'
        printf '<!-- done:  - [x] <same line> done:YYYY-MM-DD -->\n\n'
        printf '## Open\n\n'
        [[ -n "${carried}" ]] && printf '%s\n' "${carried}"
        printf '\n## Done\n\n'
    } > "${week_dir}/${TODOS_FILE}"
}

write_week_files() {
    local week_dir="$1"
    local week_id="$2"
    local carried="$3"
    mkdir -p "${week_dir}"
    printf '# Inbox — %s\n\nRaw captures, verbatim. Append-only.\n' "${week_id}" > "${week_dir}/${INBOX_FILE}"
    printf '# Effort log — %s\n\n<!-- - YYYY-MM-DD #work|#life [NNm] <what happened> -->\n\n' "${week_id}" \
        > "${week_dir}/${LOG_FILE}"
    write_todos_file "${week_dir}" "${week_id}" "${carried}"
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

    local root week_dir
    root="$(resolve_root "${requested_root}")"
    week_dir="$(week_dir_path "${root}" "${week_id}")"
    if [[ -d "${week_dir}" ]]; then
        log_info "week ${week_id} already initialized; nothing to do"
        printf '%s\n' "${week_dir}"
        return 0
    fi

    local previous carried=""
    previous="$(find_previous_week "${root}/${WEEKS_DIR_NAME}" "${week_id}")"
    if [[ -n "${previous}" ]]; then
        carried="$(carried_open_todos "$(week_dir_path "${root}" "${previous}")/${TODOS_FILE}")"
    fi
    write_week_files "${week_dir}" "${week_id}" "${carried}"
    log_info "initialized ${week_id} (carried from: ${previous:-none})"
    printf '%s\n' "${week_dir}"
}

main "$@"
