---
name: taskwork
description: Use to start or resume work under the taskwarrior convention — find or create the task for this repo, read prior handoff annotations, log decisions/gotchas during work, and leave a handoff annotation before finishing. Trigger when the user says "start work", "resume work", "log a task", "handoff", "what was I doing", or before beginning a fresh implementation session.
---

# Taskwork — taskwarrior convention cheat-sheet

This is the operational, invocable version of `guides/taskwarrior-workflow.md`.
Use it any time you need the exact command for a taskwarrior step, without
reading the full narrative guide.

## Find or start the task

```bash
task project:<repo> list
```

No task yet? Create one before writing code:

```bash
task add "<title>" project:<repo> +feature
task <id> start
```

## Read prior handoffs

Before doing anything else in a resumed session, read the task's
annotations — they're the last agent's (or your own past session's) notes:

```bash
task <id> information
```

## Log as you go

```bash
task <id> annotate "decision: <choice> because <reason>"
task <id> annotate "gotcha: <non-obvious constraint>"
```

## Handoff before finishing

Always leave one of these before context closes, even mid-task:

```bash
task <id> annotate "handoff: done=<...>, next=<...>, traps=<...>"
task <id> stop
```

Task fully done:

```bash
task <id> done
```

## Reference design/plan docs in handoffs

If this task's work went through the superpowers `brainstorming`/`writing-plans`
skills, they'll have written a design and/or plan doc under
`docs/superpowers/specs/` or `docs/superpowers/plans/`. Point to those paths in the
handoff so a resuming agent doesn't have to rediscover them:

```bash
task <id> annotate "handoff: done=<...>, next=<...>, traps=<...>, docs=docs/superpowers/plans/<file>.md"
```

## Convention

Prefix annotations with `handoff:`, `decision:`, or `gotcha:` — nothing
else. This lets future agents `grep` the task's annotations for the kind of
context they need instead of reading everything.
