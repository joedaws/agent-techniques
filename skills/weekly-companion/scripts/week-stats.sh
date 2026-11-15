#!/usr/bin/env bash
# Prints a markdown observability snapshot for one week: todo throughput per
# area, carried-over (stale) items, logged effort, and capture cadence.
set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

# Items carried this many weeks or more are reported as stale.
readonly STALE_CARRY_THRESHOLD=2

# Shared awk function: classifies a line as work, life or untagged.
readonly AWK_AREA_FN='
function area_of(line) {
    if (line ~ /(^| )#work([\/ ]|$)/) return "work"
    if (line ~ /(^| )#life([\/ ]|$)/) return "life"
    return "untagged"
}'

usage() {
    printf 'Usage: %s [--root <data-repo>] [--week <YYYY-Www>]\n' "$(basename "$0")" >&2
}

# Emits "area<TAB>metric<TAB>amount" records for the todos file.
todo_metrics() {
    local todos_path="$1"
    awk -v stale="${STALE_CARRY_THRESHOLD}" "${AWK_AREA_FN}"'
        /^- \[x\] / { print area_of($0) "\tdone\t1"; next }
        /^- \[ \] / {
            area = area_of($0)
            print area "\topen\t1"
            if ($0 ~ /(^| )!1( |$)/) print area "\turgent\t1"
            if (match($0, / carry:[0-9]+/) && substr($0, RSTART + 7, RLENGTH - 7) + 0 >= stale)
                print area "\tstale\t1"
        }
    ' "${todos_path}"
}

# Emits records for the effort log: one entry each, plus minutes when given.
log_metrics() {
    local log_path="$1"
    awk "${AWK_AREA_FN}"'
        /^- [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] / {
            area = area_of($0)
            print area "\tentries\t1"
            if (match($0, / [0-9]+m( |$)/)) print area "\tminutes\t" (substr($0, RSTART + 1) + 0)
        }
    ' "${log_path}"
}

render_area_table() {
    awk -F '\t' '
        { total[$1 SUBSEP $2] += $3 }
        END {
            print "| area | open | done | !1 open | stale | log entries | minutes |"
            print "|---|---|---|---|---|---|---|"
            split("work life untagged", areas, " ")
            for (i = 1; i <= 3; i++) {
                a = areas[i]
                printf "| %s | %d | %d | %d | %d | %d | %d |\n", a,
                    total[a SUBSEP "open"], total[a SUBSEP "done"], total[a SUBSEP "urgent"],
                    total[a SUBSEP "stale"], total[a SUBSEP "entries"], total[a SUBSEP "minutes"]
            }
        }
    '
}

render_capture_cadence() {
    local inbox_path="$1"
    printf '\nCaptures by day (UTC):\n'
    awk '/^### [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T/ { count[substr($2, 1, 10)]++ }
         END { for (d in count) printf "- %s: %d\n", d, count[d] }' "${inbox_path}" | sort
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
    require_week_dir "${week_dir}"

    printf '## Stats — %s\n\n' "${week_id}"
    { todo_metrics "${week_dir}/${TODOS_FILE}"; log_metrics "${week_dir}/${LOG_FILE}"; } | render_area_table
    printf '\nStale = carried %d+ weeks.\n' "${STALE_CARRY_THRESHOLD}"
    render_capture_cadence "${week_dir}/${INBOX_FILE}"
}

main "$@"
