# Taskwarrior workflow convention

This kit doesn't ship an issue tracker, session manager, or handoff system —
it uses [taskwarrior](https://taskwarrior.org/), a plain CLI tool, plus a
convention for how agents read and write it. There's no hook enforcing this;
agents follow it by habit, the same way they'd follow any other repo
convention.

Taskwarrior data lives in `~/.task` (per-user, not the repo). The link back
to a project is the `project:<repo>` attribute on each task, so multiple
repos can share one taskwarrior install without colliding.

## Start / resume

Find the task for the repo you're working in:

```bash
task project:<repo> list
```

If a task already exists for the work, read its annotations — these are the
prior agent's (or your own past session's) handoff notes:

```bash
task <id> information
```

If no task exists yet, create one before writing code:

```bash
task add "<title>" project:<repo> +feature
```

Mark it as your focus:

```bash
task <id> start
```

## During work

Record decisions and discoveries as they happen, not just at the end —
future readers (including future-you) shouldn't have to reconstruct intent
from a diff:

```bash
task <id> annotate "decision: chose X over Y because <reason>"
task <id> annotate "gotcha: Z affects this — <detail>"
```

## Handoff / end

Always leave a final annotation before context closes, even if the task
isn't done:

```bash
task <id> annotate "handoff: done=<what landed>, next=<what's left>, traps=<what to watch for>"
task <id> stop
```

## Complete

```bash
task <id> done
```

## Annotation prefixes

Prefix every annotation with one of `handoff:`, `decision:`, or `gotcha:` so
future agents can `grep` for intent instead of reading the whole history:

- `decision:` — a choice made and why, especially when a simpler-but-wrong
  alternative existed
- `gotcha:` — a non-obvious constraint or trap discovered during the work
- `handoff:` — state at the end of a session: what's done, what's next, what
  to watch for

See the [[taskwork]] skill for the condensed, invocable version of this
convention.
