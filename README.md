# agent-techniques

A portable set of Claude Code skills and rules, originally extracted from
[crosslink](https://github.com/dollspace-gay/crosslink) and extended.
The general-purpose parts (language rules, code-quality standards, workflow skills)
were very interesting but I also wanted more control over how these integrated
with an memory mechanism for agents.

This project abstracts specific memory presistance with the
`AGENT_TECHNIQUES_MEMORY_MECHANISM` environment variable which is used to tell the
agents which particular flavor of memory you want to use.
Whatever is used it should be able to allow agents and humans to share memory between
sessions for handoff messages or other bits of data that need persisting.

Several files under `skills/` and `rules/` are copied or adapted from
crosslink (MIT licensed) and stripped of their crosslink-specific coupling;
see [LICENSE](LICENSE) for the original copyright notice.

## Layout

```
skills/
  qa/                       quality-assurance pass
  architect/                strategic dispatch/verification layer
  maintain/                 periodic codebase-health pass
  review-pre-commit/        pre-commit quality gate
  dev-release/              changelog + release helper
  preflight/                load rules + grounding context before implementing
  use-memory-mechanism/     agent memory use conventions
  weekly-companion/         phone-driven weekly todos + effort log (private data repo)
rules/
  quality.md                code-quality standards
  rigor.md                  production-rigor standards
  web.md                    external-content / prompt-injection security protocol
  languages/                shell, python, javascript(-react), typescript(-react)
guides/
  taskwarrior-workflow.md   full taskwarrior convention narrative
  weekly-companion-design.md  design + usage paradigms for the weekly companion
  phone-weekly-sessions.md  set up week-long voice-driven sessions from the Claude app
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

## Agent Techniques Memory Mechanism

This kit has no specific issue tracker or session manager required. You can use
hand managed files or a purpose built tool like Linear,
[taskwarrior](https://taskwarrior.org/), or
[beads](https://github.com/gastownhall/beads). The key is that you must register
and explain how to use whatever memory layer.

The key features required of a memory mechansim are
- creating discrete bits of work to do in a way that persists between sessions
- a status mechansim on those chunks to mark what is in progress or complete
- an ability to annotate the descrete work descriptions for the purpose of handoff notes

For example, when using taskwarrior cli, this would look like the following for particular
project `project:<repo>`:

- **Start:** `task project:<repo> list` (or `task add "<title>"
  project:<repo> +feature` if none exists yet), then `task <id> start`.
- **During work:** `task <id> annotate "decision: ..."` /
  `"gotcha: ..."`.
- **Handoff:** `task <id> annotate "handoff: done=..., next=..., traps=..."`
  before ending a session.

A guide file should be written for your choice of memory mechanism. For exaple,
see `guides/taskwarrior-workflow.md` for the full convention for taskwarrior.

A guide should be created and will then get picked up by the `use-memory-mechansim`
skill in `skills/use-memory-mechansim/SKILL.md`.

## Language rules

Language rules aren't auto-injected — the `preflight` skill detects the
project's manifests (`package.json`, `tsconfig.json`, `pyproject.toml`, etc.)
and reads only the matching rule files from `rules/languages/`.

## Weekly companion (personal todos from your phone)

`skills/weekly-companion/` runs a week-long cloud session you talk to from the
Claude app: dictated notes become work/life todos and an effort log, persisted
to a separate **private** data repo, with ranked priorities on request. It is
installed into the data repo with its own `scripts/bootstrap.sh`, not
`install.sh`. Design: [guides/weekly-companion-design.md](guides/weekly-companion-design.md).
Setup: [guides/phone-weekly-sessions.md](guides/phone-weekly-sessions.md).
Tests: `skills/weekly-companion/tests/run-tests.sh`.
