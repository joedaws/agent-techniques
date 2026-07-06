# agent-techniques

A portable set of Claude Code skills and rules, extracted from a trial of
[crosslink](https://github.com/dollspace-gay/crosslink). The general-purpose
parts (language rules, code-quality standards, workflow skills) were very interesting
so I want to see what it would look like to use a light flow control using TaskWarrior.

Several files under `skills/` and `rules/` are copied or adapted from
crosslink (MIT licensed) and stripped of their crosslink-specific coupling;
see [LICENSE](LICENSE) for the original copyright notice.

## Layout

```
skills/
  qa/                 quality-assurance pass
  architect/           strategic dispatch/verification layer
  maintain/            periodic codebase-health pass
  review-pre-commit/   pre-commit quality gate
  dev-release/         changelog + release helper
  preflight/           load rules + grounding context before implementing
  taskwork/            taskwarrior convention cheat-sheet
rules/
  quality.md           code-quality standards
  rigor.md             production-rigor standards
  web.md               external-content / prompt-injection security protocol
  languages/           shell, python, javascript(-react), typescript(-react)
guides/
  taskwarrior-workflow.md   full taskwarrior convention narrative
install.sh
```

## Install

```
./install.sh --target /path/to/repo
```

Copies `skills/*` into `<target>/.claude/skills/` and `rules/*` into
`<target>/.claude/rules/`, then inserts a managed block into the target's
`CLAUDE.md` (creating it if absent). Re-running is idempotent: the
`CLAUDE.md` block is replaced, not duplicated, and existing skill/rule files
are left alone unless `--force` is passed.

Flags: `--target <dir>` (default: current directory), `--force` (overwrite
existing files), `--dry-run` (print actions, write nothing).

After installing, run the `preflight` skill in the target repo to load the
relevant rules before implementing.

## Taskwarrior convention

This kit has no issue tracker or session manager. Instead, tasks are tracked
with [taskwarrior](https://taskwarrior.org/) and linked to a repo via
`project:<repo>`:

- **Start:** `task project:<repo> list` (or `task add "<title>"
  project:<repo> +feature` if none exists yet), then `task <id> start`.
- **During work:** `task <id> annotate "decision: ..."` /
  `"gotcha: ..."`.
- **Handoff:** `task <id> annotate "handoff: done=..., next=..., traps=..."`
  before ending a session.

See `guides/taskwarrior-workflow.md` for the full convention, or the
`taskwork` skill for the condensed command reference.

## Language rules

Language rules aren't auto-injected — the `preflight` skill detects the
project's manifests (`package.json`, `tsconfig.json`, `pyproject.toml`, etc.)
and reads only the matching rule files from `rules/languages/`.
