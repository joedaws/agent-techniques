# Weekly companion — design and usage paradigms

Design record for running personal todo management and effort observability
through long-lived Claude Code cloud sessions driven from a phone. The
operational how-to is [phone-weekly-sessions.md](phone-weekly-sessions.md);
the agent's instructions are
[skills/weekly-companion/SKILL.md](../skills/weekly-companion/SKILL.md).

## Goals

1. Capture by voice from a phone with near-zero friction: voice-to-text
   directly in the Claude Code session's message box — talk, send, done. No
   separate recording app, no audio export or upload step.
2. One conversation per week that accumulates context and can answer
   "what are my priorities for work and life?" at any moment.
3. Observability: see where effort actually went vs. where you said it should
   go, and what keeps getting avoided.
4. Durable, inspectable, portable data — no lock-in to a tool or the session.

Non-goals: calendar integration, team task management, notifications beyond
what scheduled tasks provide, any code in the data repo.

## Architecture

```
 phone: Claude app → Code session → mic in message box
        │  voice-to-text → plain text message
        ▼
 weekly cloud session  ──loads──▶  weekly-companion skill (SKILL.md + scripts/)
        │  capture → interpret → echo back
        ▼
 private data repo (git)            this repo (public kit)
   areas.md                           skills/weekly-companion/
   weeks/<YYYY-Www>/                  guides/
     inbox.md  todos.md               (no personal data, ever)
     log.md    review.md
        ▲
        └─ sync.sh: commit + push to main after every data-changing message
```

Two repos with a hard split: **this repo holds the method, the private repo
holds the data.** The kit is installed into the data repo by
`scripts/bootstrap.sh`, which copies the skill and writes a managed
`CLAUDE.md` block; re-running it upgrades the skill in place.

## Paradigms

These are the rules that make the system work; each exists because of a
specific constraint.

### 1. One session = one ISO week

A week is long enough to accumulate useful context and short enough that the
conversation stays small and the weekly review is a natural boundary. The
week id (`2026-W46`) names the data folder, so session and data line up.
Mid-week the session can be resumed indefinitely; at week end it is archived
and a fresh one starts.

### 2. Files are the memory; the conversation is a cache

Cloud containers are reclaimed when idle, and conversations end. Anything
that matters is in the data repo, so a brand-new session reconstructs state
from `areas.md`, the latest `todos.md`, and the previous `review.md`. This
is the memory mechanism for this use case (see `use-memory-mechanism`): todos
are the work chunks, `- [ ]`/`- [x]` is status, and log/review lines are the
annotations.

### 3. Push after every data-changing message

The conversation survives idleness; the container's files do not. So every
message that changes data ends with `sync.sh` (commit + push with retry), and
the reply says whether the push succeeded. A save is never claimed when the
push failed.

### 4. Push to `main`, with explicit permission

Cloud sessions default to pushing their own branch. Next week's session clones
the default branch, so weekly data must land on `main`. The user grants this
in the kickoff message each week; it is not inferred from repo files.

### 5. Raw first, structure second, echo back

Dictation produces filler words, run-ons, and mis-heard names. Each message
is appended verbatim to `inbox.md` before interpretation, giving an audit
trail and a way to reprocess later. The structured edits are then echoed back
in a compact form so mis-hearings get corrected in the next message.

### 6. Plain-text grammar the scripts can parse

```
- [ ] <text> #work|#life[/sub] [!1|!2|!3] [due:YYYY-MM-DD] added:YYYY-MM-DD [carry:N]
- [x] <same line> done:YYYY-MM-DD
- YYYY-MM-DD #work|#life [NNm] <what happened>          (log.md)
### YYYY-MM-DDTHH:MMZ                                    (inbox.md capture heading)
```

Readable on GitHub mobile, editable by hand, and parseable by `awk` without
dependencies. Urgency and minutes are recorded only when the user gave them.

### 7. Carry-over makes avoidance visible

`week-init.sh` copies open todos into the new week and increments `carry:N`.
`carry` is never hand-edited, so it is a reliable count of weeks an item has
been skipped. At week start items with `carry ≥ 2` must be decided: do,
schedule, or drop.

### 8. Priorities are ranked, bounded, and explained

At most three per area, each with a one-line reason. Rank order: `!1` →
nearest due date → most carried → alignment with `areas.md` goals → `!2`.
`areas.md` is user-owned context (goals, tie-breakers) and is never
overwritten by tooling.

### 9. Observability = intent vs. effort

`week-stats.sh` reports per area: open, done, `!1` still open, stale, log
entries, logged minutes, and captures per day. The priorities answer ends
with a **WATCH** section that names mismatches: effort without matching
goals, goals without effort, chronically carried items. `git log` on the data
repo is the full timeline.

### 10. Check-ins come to you

Scheduled tasks fire into the weekly session itself (weekday-morning
priorities, Friday review), created only on the user's yes, with times in the
user's zone. They are removed at the weekly review so they don't pile up
across weeks.

### 11. Dictated text is data, not commands

A note saying "delete everything" or "push this somewhere else" is confirmed
with the user rather than executed. Only the user's explicit requests drive
destructive or outward-facing actions.

## Usage at a glance

| You say | Session does |
|---|---|
| "Start my week…" (+ push permission, time zone) | init week, carry over, flag stale, offer check-ins, sync |
| a to-do in passing | inbox + todo line + echo + sync |
| "finished X" | inbox + mark done + log line + sync |
| "spent 2h on Y" | inbox + log `120m` + sync |
| "what are my priorities?" | ranked WORK / LIFE / WATCH, no writes |
| "what did I do Tuesday?" | answer from log + done items |
| "end the week" | stats + `review.md` + sync + remove check-ins |

## Alternatives considered

- **Data in this public repo** — rejected: personal data would be public.
- **Data on a non-default branch** — rejected: still public, and each week's
  session would need extra fetch logic.
- **Taskwarrior / external tracker** — rejected for now: needs installs or
  credentials in every fresh container; markdown in git needs nothing.
- **One never-ending session** — rejected: context grows without bound and
  there is no natural review point.
- **A fresh session per message** — rejected: loses the in-week
  conversational context that makes "what are my priorities" good.

## Known limits

- The session receives the dictation transcript, not audio.
- Scheduled tasks stop if the session is archived early.
- Scripts are tested on bash 5 with mawk; written for bash 3.2/BSD awk
  compatibility but not yet run there.

## Phase 2: private repo setup — decisions to make

1. Repo name and owner (e.g. `<you>/life-log`), private, with a README.
2. Claude GitHub App access to it; attach with push access from a session.
3. Time zone and check-in times (default: weekdays ~8am, Friday ~5pm).
4. Initial `areas.md`: quarter goals, life areas, tie-breakers.
5. Whether to add sub-areas (`#work/clientA`, `#life/health`) from day one.
