<!-- weekly-companion:start -->
This is a private personal data repo driven by the `weekly-companion` skill.
Load that skill at the start of every session and follow it for every message.

- One session per ISO week. Data lives in `areas.md` and `weeks/<YYYY-Www>/`.
- Persist with the skill's `scripts/sync.sh` after every message that changes
  data. Push to `main`: this repo has no code review, and next week's session
  must see this week's data on the default branch.
- Messages are usually dictated on a phone. Store them verbatim first, then
  interpret, then echo back what you understood.
- Do not run `preflight`, coding rules, or code-review skills here; there is
  no code in this repo.
<!-- weekly-companion:end -->
