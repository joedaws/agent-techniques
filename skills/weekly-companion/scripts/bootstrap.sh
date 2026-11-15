#!/usr/bin/env bash
# One-time setup of a private data repo: installs this skill into
# <target>/.claude/skills/weekly-companion, writes the managed CLAUDE.md
# block, and seeds areas.md. Safe to re-run: the skill and CLAUDE.md block
# are refreshed; an existing areas.md (user-owned) is never touched.
set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly SKILL_DIR
readonly SKILL_NAME="weekly-companion"
readonly BLOCK_START="<!-- ${SKILL_NAME}:start -->"
readonly BLOCK_END="<!-- ${SKILL_NAME}:end -->"

usage() {
    printf 'Usage: %s --target <data-repo-dir>\n' "$(basename "$0")" >&2
}

install_skill() {
    local target="$1"
    local destination="${target}/.claude/skills/${SKILL_NAME}"
    [[ "${destination}" != "${SKILL_DIR}" ]] || die "target already hosts this skill copy: ${target}"
    mkdir -p "${target}/.claude/skills"
    rm -rf "${destination}"
    cp -R "${SKILL_DIR}" "${destination}"
    log_info "installed skill into ${destination}"
}

# Replaces the managed block in CLAUDE.md, or appends it if absent.
write_claude_md_block() {
    local target="$1"
    local claude_md="${target}/CLAUDE.md"
    local template="${SKILL_DIR}/templates/CLAUDE.md"
    local staged
    staged="$(mktemp -t weekly-companion-claude.XXXXXX)"
    if [[ -f "${claude_md}" ]]; then
        awk -v start="${BLOCK_START}" -v end="${BLOCK_END}" '
            $0 == start { skipping = 1; next }
            skipping && $0 == end { skipping = 0; next }
            !skipping { print }
        ' "${claude_md}" > "${staged}"
    fi
    cat "${template}" >> "${staged}"
    mv "${staged}" "${claude_md}"
    log_info "wrote managed block to ${claude_md}"
}

seed_areas() {
    local target="$1"
    if [[ -e "${target}/areas.md" ]]; then
        log_info "areas.md exists; leaving it untouched"
        return 0
    fi
    cp "${SKILL_DIR}/templates/areas.md" "${target}/areas.md"
    log_info "seeded ${target}/areas.md"
}

main() {
    local target=""
    while (($# > 0)); do
        case "$1" in
            --target) target="${2:?--target needs a value}"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) usage; die "unknown argument: $1" ;;
        esac
    done
    [[ -n "${target}" ]] || { usage; die "--target is required"; }
    [[ -d "${target}" ]] || die "target does not exist: ${target}"
    target="$(cd "${target}" && pwd)"
    git -C "${target}" rev-parse --git-dir >/dev/null 2>&1 || die "target is not a git repo: ${target}"

    install_skill "${target}"
    write_claude_md_block "${target}"
    seed_areas "${target}"
}

main "$@"
