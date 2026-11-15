#!/usr/bin/env bash
set -euo pipefail

# Rename point: change this if you rename the kit repo.
MARKER="agent-kit"

KIT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"

TARGET="$PWD"
FORCE=0
DRY_RUN=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [--target <dir>] [--force] [--dry-run] [-h|--help]

Copies this kit's skills and rules into a target repo's .claude/ directory,
and inserts a managed block into the target repo's CLAUDE.md.

  --target <dir>   Target repo to install into (default: current directory)
  --force          Overwrite existing skill/rule files instead of skipping them
  --dry-run        Print the actions that would be taken; write nothing
  -h, --help       Show this help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --target)
      TARGET="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

TARGET="$(cd "$TARGET" 2>/dev/null && pwd || true)"
if [ -z "$TARGET" ]; then
  echo "Error: --target directory does not exist." >&2
  exit 1
fi

if ! git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Warning: $TARGET does not look like a git repo." >&2
  if [ "$FORCE" -eq 1 ]; then
    echo "Continuing anyway (--force)." >&2
  else
    read -r -p "Continue anyway? [y/N] " reply
    case "$reply" in
      [yY]|[yY][eE][sS]) ;;
      *) echo "Aborted." >&2; exit 1 ;;
    esac
  fi
fi

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "+ $*"
  else
    "$@"
  fi
}

skills_installed=0
skills_skipped=0
skills_overwritten=0
rules_installed=0
rules_skipped=0
rules_overwritten=0

run mkdir -p "$TARGET/.claude/skills" "$TARGET/.claude/rules/languages"

for skill_dir in "$KIT_DIR"/skills/*/; do
  name="$(basename "$skill_dir")"
  # Personal-data skill; installed into a private data repo via its own
  # scripts/bootstrap.sh, never into code repos.
  if [ "$name" = "weekly-companion" ]; then
    continue
  fi
  dest="$TARGET/.claude/skills/$name"
  if [ -e "$dest" ] && [ "$FORCE" -ne 1 ]; then
    echo "skipped (exists): skills/$name"
    skills_skipped=$((skills_skipped + 1))
    continue
  fi
  if [ -e "$dest" ]; then
    echo "overwritten: skills/$name"
    skills_overwritten=$((skills_overwritten + 1))
  else
    echo "installed: skills/$name"
    skills_installed=$((skills_installed + 1))
  fi
  run rm -rf "$dest"
  run cp -r "$skill_dir" "$dest"
done

for rule_file in "$KIT_DIR"/rules/*.md; do
  name="$(basename "$rule_file")"
  dest="$TARGET/.claude/rules/$name"
  if [ -e "$dest" ] && [ "$FORCE" -ne 1 ]; then
    echo "skipped (exists): rules/$name"
    rules_skipped=$((rules_skipped + 1))
    continue
  fi
  if [ -e "$dest" ]; then
    echo "overwritten: rules/$name"
    rules_overwritten=$((rules_overwritten + 1))
  else
    echo "installed: rules/$name"
    rules_installed=$((rules_installed + 1))
  fi
  run cp "$rule_file" "$dest"
done

for lang_file in "$KIT_DIR"/rules/languages/*; do
  name="$(basename "$lang_file")"
  dest="$TARGET/.claude/rules/languages/$name"
  if [ -e "$dest" ] && [ "$FORCE" -ne 1 ]; then
    echo "skipped (exists): rules/languages/$name"
    rules_skipped=$((rules_skipped + 1))
    continue
  fi
  if [ -e "$dest" ]; then
    echo "overwritten: rules/languages/$name"
    rules_overwritten=$((rules_overwritten + 1))
  else
    echo "installed: rules/languages/$name"
    rules_installed=$((rules_installed + 1))
  fi
  run cp "$lang_file" "$dest"
done

CLAUDE_MD="$TARGET/CLAUDE.md"
START_MARKER="<!-- ${MARKER}:start -->"
END_MARKER="<!-- ${MARKER}:end -->"

BLOCK="$START_MARKER
Before implementing code in this repo, run the \`preflight\` skill to load
the relevant language/quality/rigor rules and project context.

This repo uses a memory mechanism for task tracking and
handoffs (see the \`use-memory-mechanism\` skill): find or create a task for your work
using the mechanism, read prior handoff annotations, and leave a handoff or other
annotation before ending a session. See the skill for the specific invocation based
on the memory mechanism loaded.
$END_MARKER"

update_claude_md() {
  if [ ! -f "$CLAUDE_MD" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "+ create $CLAUDE_MD with $MARKER managed block"
    else
      printf '%s\n' "$BLOCK" > "$CLAUDE_MD"
    fi
    echo "CLAUDE.md: created with managed block"
    return
  fi

  if grep -qF "$START_MARKER" "$CLAUDE_MD" 2>/dev/null; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "+ replace $MARKER managed block in $CLAUDE_MD"
    else
      tmp="$(mktemp)"
      awk -v start="$START_MARKER" -v end="$END_MARKER" -v block="$BLOCK" '
        $0 == start { print block; skipping = 1; next }
        skipping && $0 == end { skipping = 0; next }
        skipping { next }
        { print }
      ' "$CLAUDE_MD" > "$tmp"
      mv "$tmp" "$CLAUDE_MD"
    fi
    echo "CLAUDE.md: managed block replaced"
  else
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "+ append $MARKER managed block to $CLAUDE_MD"
    else
      printf '\n%s\n' "$BLOCK" >> "$CLAUDE_MD"
    fi
    echo "CLAUDE.md: managed block appended"
  fi
}

update_claude_md

total_skills_installed=$((skills_installed + skills_overwritten))
total_rules_installed=$((rules_installed + rules_overwritten))

echo
echo "Summary:"
echo "  Skills: $total_skills_installed installed/overwritten, $skills_skipped skipped"
echo "  Rules:  $total_rules_installed installed/overwritten, $rules_skipped skipped"
echo "  CLAUDE.md updated"
echo
echo "Next step: run the preflight skill in $TARGET"
