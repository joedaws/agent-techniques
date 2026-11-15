# Weekly companion from your phone

Drive a week-long Claude Code cloud session from the Claude app: dictate
voice notes as they occur to you, and ask "what are my priorities?" at any
point. The `weekly-companion` skill turns notes into work/life todos plus an
effort log, and pushes everything to a **private** data repo after every
message. Design rationale: [weekly-companion-design.md](weekly-companion-design.md).

## Why the pieces fit together this way

| Constraint | Consequence |
|---|---|
| This kit repo is public | Personal data lives in a separate private repo (e.g. `life-log`). |
| Cloud containers are reclaimed when idle; the conversation is not | Every message ends with `sync.sh` (commit + push). A resumed session re-clones and sees everything. |
| Each session normally pushes to its own branch | The weekly session must push to `main`, or next week's session will not see this week. You grant that explicitly in the kickoff message. |
| Phone dictation is messy | Raw text goes verbatim into `inbox.md` first; the structured files are interpretation the session echoes back for correction. |

## One-time setup (≈10 minutes)

1. **Create a private GitHub repo**, e.g. `<you>/life-log`, with a README so
   `main` exists.
2. **Give Claude access to it**: install the Claude GitHub App on that repo
   (or on all repos) so cloud sessions can clone and push it.
3. **Bootstrap it** from any cloud session in this kit repo — on your phone:

   > Attach my repo `<you>/life-log` with push access, clone it next to this
   > repo, run `skills/weekly-companion/scripts/bootstrap.sh --target <that
   > clone>`, then commit and push to life-log `main`. You have my permission
   > to push to `main` in life-log.

4. **Fill in `areas.md`** — goals and tie-breakers are what priorities are
   ranked against. Dictating "update my areas: …" in the weekly session works.

## Every week

1. In the Claude app, open **Code**, pick the `life-log` repo, start a new
   session, and send the kickoff message:

   > Start my week. Use the weekly-companion skill. You have my permission to
   > commit and push to `main` in this repo for this whole session. My time
   > zone is America/Chicago.

2. Say yes when it offers check-ins: a weekday-morning priorities prompt and
   a Friday review, created as scheduled tasks that fire into this same
   session.
3. All week, open that session and **tap the microphone to dictate** (the
   Claude app's dictation, or your keyboard's). Examples:
   - "Need to email Sam about the contract, and book the vet for Friday."
   - "Done with the contract email. Spent two hours on the migration, stuck on auth."
   - "What are my priorities?" · "What did I actually do on Tuesday?"
4. Friday (or "end the week"): it writes `review.md` with the stats table,
   what slipped, and stale items. Archive the session; start a fresh one on
   Monday. A fresh session per week keeps context small and the review clean.

## What "observability" means here

`week-stats.sh` produces, per area (work / life / untagged): open, done,
`!1` still open, stale (carried 2+ weeks), log entries and logged minutes,
plus captures per day. The priorities answer has a **WATCH** section that
flags mismatches — effort going somewhere your goals are not, items carried
week after week, an area with no logged effort. Because everything is plain
markdown in git, `git log` on the data repo is a full timeline, and you can
read or edit any week from GitHub on your phone.

## Caveats

- What the session receives is the transcript, not audio. Check the echo-back
  for mis-heard names.
- Scheduled tasks need the session to still exist; archiving it stops them.
  The weekly review removes this week's check-ins.
- Treat the data repo as sensitive: keep it private and limit who has access.
