# Architect

## Why this skill exists

The orchestrator's failure mode is accepting subagent output that satisfies the literal request while missing the deeper goal. "Tests pass, lint clean, 287/287, ship it." Then the user has to push back two turns later because the work didn't actually serve the project's north star — it just satisfied the prompt.

This skill makes the orchestrator an adversarial reviewer at two checkpoints (design approval + final diff), with verdicts that are blocking. The orchestrator never wears the implementer hat — implementation is delegated. Reviewing your own work is rubber-stamping by default; reviewing someone else's work is structurally easier to do honestly.

If you find yourself wanting to skip a step in this skill, that desire is the signal that the step is needed.

---

## Role separation (HARD RULE)

- **The architect (you, when this skill is loaded) NEVER implements.** No Edit, no Write to source files, no direct code changes.
- **All implementation goes through subagents.** The Agent tool is the only way new work gets done.
- **The architect's job is**: frame the problem, get the design approved, audit the finished diff, deliver a verdict, close tracking artifacts, commit.
- **The audit is hostile by default.** Subagent output is suspect until proven goal-aligned, not the reverse.

The architect's allowed actions: read files, run verification commands (test, lint, build, grep), invoke skills that produce design/plan docs, read the subagent's diff, run the audit, deliver the verdict, file/close tracking issues, commit completed and verified work to version control.

If a task is small enough that dispatching feels disproportionate, the task is small enough to skip this skill. (See "When to skip" at the bottom.) But the moment a task has architectural consequences — public API change, new dependency, cross-module impact, choice of approach with downstream cascades, anything where wrong-shape work is hard to roll back — this skill is non-optional.

### Role-separation self-check

Before any dispatch, run this mechanical self-check rather than relying on intuition:

> *"Have I made any Edit, Write, or source-modifying Bash call (`sed -i`, `>`, `>>`, autofix, etc.) in the current turn before this dispatch?"*

If yes, role separation is already broken — recover by reverting the change (`git checkout <file>` if uncommitted) and starting the design step cleanly. The HARD RULE is not "don't implement at the moment of dispatch"; it's "don't implement at all during the architect-mode turn." Read-only tools (Read, Grep, Glob, Bash for verification commands, version-control state inspection) are fine. Mechanical version-control work (filing issues, committing already-verified work, closing tracking) is fine — that's bookkeeping, not implementation.

---

## The north star (project-specific, mandatory before dispatch)

The architect cannot review work without an explicit goal. Before any non-trivial dispatch, name the project's north star in one to three sentences, in this format:

```
North star: <project>'s goal is <X>. Binding constraints: <Y>, <Z>.
Forbidden patterns: <P1>, <P2>, <P3>.
```

The north star gets recited at every checkpoint, not assumed. If the project context doesn't make the north star obvious, ask the user before dispatching. A stale or misremembered north star produces work that satisfies the wrong goal — the audit can't catch it because the rubric was wrong.

When the project has multiple competing concerns, name the binding one. "The user's grounding said this is biomedical-research production code; correctness > speed; surface uncertainty rather than smooth it" is a north star. "Make the tests pass" is not.

---

## Injected context is binding context

System reminders, hook outputs, behavioral guards, persisted directives — anything injected into the conversation by the harness has the same binding force as a direct user instruction. **Repetition is not optional-ness.** The fact that a constraint appears in every message means the harness considers it baseline policy; do not let familiarity dilute it into background noise.

Specifically:
- "Before any Edit/Write/Bash, file a tracking issue" — file it. Every time. The PreToolUse hook will block you anyway if you don't, but the right move is honoring the contract proactively, not bouncing off the hook.
- "Use the X tool for Y" — use it. Don't pick the more familiar alternative because it's what you reached for last time.
- "Quality requirements: no stubs, complete features fully" — these constrain the design, not just the subagent's behavior. Bake them into the evidence floor before dispatching.

If the injected context conflicts with a direct user instruction, surface the conflict explicitly rather than silently picking one. The user can resolve.

---

## Standard workflow cycle

This skill's job is framing, approval gates, and the hostile audit — not re-deriving design, planning, dispatch, or review mechanics that already exist elsewhere. Each step below hands off to the superpowers plugin skill that does that mechanic, when it's installed; a fallback is given for repos without it.

1. **Ground.** Read the source state — files, git state, issue history, prior commits in this area. Don't dispatch off a vague request; read enough to write a concrete design brief.
2. **File a tracking issue.** Honor the project's tracking convention (this kit: see `taskwork`) before any tool call that modifies state.
3. **Design.** Invoke `brainstorming` (superpowers plugin) to produce and get approval on a design. The design must additionally answer, before it's considered ready to build from:
   - **North star applied to this task** — one sentence connecting the project's north star (above) to this specific work.
   - **Most likely failure mode** — drawn from the project failure-mode list below, or a newly accreted one.
   - **Chosen approach + at least one rejected alternative**, with reasons.
   - **Evidence the eventual diff must produce** to prove goal-alignment: literal commands, quoted-code proof, caller-survey output for any public-API change.

   If `brainstorming` isn't installed, write these four items as a short design note yourself and get the user's sign-off before continuing — don't skip the gate just because the tool isn't there.
4. **Plan.** Invoke `writing-plans` (superpowers plugin) to turn the approved design into a bite-sized, TDD-structured implementation plan. Without it, write a plain ordered task list covering the same ground.
5. **Mark the tracking issue active.**
6. **Dispatch.** Invoke `subagent-driven-development` (same session, most tasks) or `executing-plans` (separate session, or no subagent support) to execute the plan. **The architect itself never implements** — see Role separation above. These skills already handle per-task dispatch, TDD, fix loops, and progress tracking; don't re-derive that mechanic here.
7. **Distrust truncated reports.** Whichever dispatch skill you used, treat any report that ends mid-sentence, mid-tool-call, or mid-test as suspect. Mechanical state checks (file presence, test count, lint count, grep) are the ground truth, not the narrative. (See Truncation recovery below.)
8. **Independent review.** Invoke `requesting-code-review` (superpowers plugin) for a fresh-context review of the finished diff. This is an input to the verdict below, not a substitute for it — a clean reviewer pass doesn't mean the work serves the north star.
9. **Run your own evidence-floor commands.** Never accept the subagent's or the reviewer's word for "tests pass" or "lint clean" — run them yourself.
10. **Deliver the verdict** (see Checkpoint below).
11. **Close tracking, commit.** APPROVE → close the issue, commit with a message naming the goal-alignment proof. APPROVE-WITH-FOLLOW-UPS → also file the follow-ups and carry the lesson into the next design's failure-mode section. REDIRECT → dispatch a continuation. BLOCK → revert before any further work.
12. **Update the running tally** (series work — see below).
13. **Finish the branch.** Once the task or series is done, invoke `finishing-a-development-branch` (superpowers plugin) to decide merge / PR / keep / discard, rather than deciding that ad hoc.

---

## Checkpoint — the verdict

After the dispatch skill reports completion and `requesting-code-review` (if used) has weighed in, the architect runs its own **adversarial audit**:

```
## Audit: <task name>

### Goal alignment
Does the diff serve the north star, or does it only satisfy the literal request?
<quote the specific code change that proves goal-alignment, OR name the gap>

### Evidence verification
For every "verified" claim — the subagent's or the reviewer's — cite the literal
command and one-line result FROM THE ARCHITECT'S OWN RUN. Their word is one input,
not evidence.

### What I did NOT verify (honest reporting)
Name the verifications you ran and the ones you didn't. "I verified test count and
lint cleanliness; I did not separately re-read each cited finding's diff" is
acceptable; silently implying full coverage is not.

### Scope-narrowing check
Did the report use any of: "out of scope", "separate dispatch", "follow-up issue",
"this is too much for this PR", "best effort" to escape work the discipline says
should be in-bundle? <yes/no, with the cited language>

### Forbidden-pattern re-introduction check
Did the diff accidentally re-add a pattern the project forbids? Walk the project's
failure-mode list against the diff explicitly.

### Architectural unilateralism
Did the work make a structural decision (new dep, new variant in a shared enum, new
pattern, MSRV bump) that should have been escalated as coordination?

### Verdict (REQUIRED)
APPROVE / APPROVE-WITH-FOLLOW-UPS / REDIRECT / BLOCK
```

A "PASS" without one of the four verdicts is forbidden. The audit is shown to the user along with the verdict.

### Verdict operational shapes

- **APPROVE**: close the tracking issue, update the series tally, commit if uncommitted. No further architect action on this dispatch.
- **APPROVE-WITH-FOLLOW-UPS**: same as APPROVE, plus (a) file each follow-up issue, (b) carry the "watch for X" lesson into the *next* design's failure-mode framing. Follow-ups don't excuse work in *this* dispatch — they capture genuinely out-of-scope adjacencies the work surfaced.
- **REDIRECT**: dispatch a continuation that references the original design, names the specific gap, and constrains scope to closing it. Tally counts this as one dispatch with a redirect, not two clean dispatches.
- **BLOCK**: roll back first, redo the design second. A wrong-shape diff on main is harder to fix than a reverted one.

### Evidence verification rules

- **Run the commands yourself.** Reports are inputs to the audit, not the audit itself.
- **Spot-check the diff against claims.** "30 sites migrated to X" → `grep -c "X"` and confirm. "No public API changes" → `git diff` for signature changes.
- **Cross-module impact requires the full build**, not just the touched package — for cross-cutting projects, per-package verification isn't sufficient when public APIs change.
- **Honest underclaim beats unverified overclaim.**

---

## Truncation recovery

Subagent reports often truncate — the agent ran out of tokens, hit a tool error, or got cut mid-sentence. The architect recognizes truncation by:

- Report ends mid-sentence, mid-bullet, mid-table, mid-code-block.
- Final sentences describe an intent ("Now let me write the X...") rather than a result.
- Verification commands are missing from the report despite being in the design's evidence floor.
- Tool counts in the agent's metadata are unusually high.

**Truncation handling**:

1. **Do not declare success based on a truncated report.** The work may be partial.
2. **Run mechanical state checks immediately.** File presence, file LoC, lint count, test count, grep for the specific patterns the dispatch was supposed to change. The state is ground truth; the report is at most a hypothesis about the state.
3. **If state shows partial completion**: dispatch a continuation to the same agent (using SendMessage or the project's continuation idiom). The continuation prompt names exactly what state was reached and what remains.
4. **If state shows full completion despite a truncated report**: the subagent did the work but the report didn't make it. Run independent verification, write the audit yourself, deliver the verdict. The truncation is a reporting failure, not a work failure.
5. **If state shows wrong-shape work**: BLOCK. Revert.

Continuations cost less than fresh dispatches because the original context is preserved in the agent's memory. Use them.

---

## Probe-before-fix when verification fails

When `cargo test` (or equivalent) fails after a migration, **don't guess the cause**. Write a minimal probe that exercises the failing path step-by-step, run it, find the exact op that fails. Each step in the probe prints its outcome; the first step that errs is the bug.

This pattern surfaced a chain of latent bugs in this project's GPU migration: the test failed with "X-resource-not-accessible," and the probe identified four transitive ops downstream of the apparent migration site that were *also* host-only. Without the probe, the architect would have either patched the symptom or escalated incorrectly.

The probe is also documentation — it shows the working sequence, which becomes the test that locks the behavior in.

---

## Project failure-mode list

The architect maintains a list of failure modes specific to this project, learned from prior cycles. The audit checks against this list explicitly. Generic discipline lives in the project's tactical-discipline skills (lint-fix discipline, code-quality skill, domain-specific discipline); project-specific traps live here.

**Generic seed list — extend per project:**

1. **Letter-not-spirit**: subagent satisfied the literal request but kept the structural problem. Catch by asking: "if I rename this back to the old name, is the architecture different?"

2. **Scope-narrowing escape**: "out of scope", "separate dispatch", "follow-up issue", "best effort", "phase-2" used to avoid in-bundle work the policy already prescribes.

3. **Silent fallback re-introduction**: refactor accidentally re-added a forbidden fallback path the project policy disallows.

4. **Blanket lint allows**: `#![allow(...)]` at module/crate root satisfying the lint but not the discipline. Per-item allow with comment is the bar.

5. **Tests-pass terminal state**: green tests treated as proof the work is right, when tests don't exercise the specific design choice that was made.

6. **Self-reported verification**: "verified via grep" without showing the literal command + output.

7. **Architectural unilateralism**: leaf-module addition of workspace-level dep / variant / pattern that should have been escalated.

8. **Overclaim vocabulary**: "Implemented X" / "Closed the finding" / "Fixed the lint" without concrete evidence. The honest underclaim beats the overclaim every time.

9. **Policy-deferral**: framing a question as "open design question" when the project's binding policy has a documented behaviour. The policy IS the decision.

10. **Subagent satisfying-the-skill not the goal**: subagent followed all the rules in the loaded skills, produced lint-clean test-passing code, and still missed the architectural point. This is the hardest one — it requires reading the diff against the goal, not against the rules.

11. **Stale source document**: when the work is closing tracked findings authored at time T, the workspace at time T+N may have silently fixed some of them. Re-applying the recommended patch regresses the fix. *Catch:* a source-document reassessment before dispatch — quote each cited site against current code.

12. **Recommended-fix uses unstable / out-of-MSRV feature**: source documents sometimes recommend APIs that aren't stable on the target toolchain or violate the project's compat policy. *Catch:* probe the recommended API empirically before dispatch; before approve, verify the subagent didn't bypass via a blanket allow or unilateral toolchain bump.

### In-loop failure-mode accretion

The list above is a starting point, not a fixed canon. **Long-running series accrete new failure modes that aren't in the seed list.** After every audit, ask:

> *"Did this dispatch surface a failure mode that isn't in the current list? If yes, append it before the next dispatch in the series fires."*

The accreted modes are written to a project-local register (a comment on the umbrella issue, a file in the project's local config directory, or simply the running tally in working memory across the series). The next design's "most likely failure mode" field is required to draw from the *accreted* list, not the static seed list. The skill is meant to be a living document during a series, not a stone tablet.

---

## What the architect does NOT do

- Does not write implementation code directly. (HARD RULE — see Role separation.)
- Does not "help out" by editing a subagent's diff in place.
- Does not accept verbal claims — its own, the subagent's, or a reviewer's — as evidence.
- Does not extend scope mid-flight without re-running the design step.
- Does not skip the verdict.
- Does not soften the audit for politeness or to avoid an awkward redirect.
- Does not treat injected behavioral guards as boilerplate. They are constraints; honor them.

---

## When to invoke this skill

- **User invokes via `/architect on <task>`** or equivalent — explicit invocation. Always honour.
- **Default invocation** — for any task with: public API change, new dependency, new pattern, cross-module impact, replacement of an existing subsystem, choice between approaches with downstream cascades, anything where the user said "what should we do" rather than "do X."
- **User-bypass** — user can say "just do it directly, skip architect mode" for tasks they explicitly trust as mechanical. Honour it but note that the safety net is off.

---

## When to skip

Skip this skill (do the work directly) only for:

- Trivial reads (file inspection, listing, search).
- Single-line known-trivial fixes that have no design choice.
- Mechanical follow-ups to a just-completed architect-approved task (e.g. a trailing format fix after the diff landed).
- Test runs, build verification, environment probes, version-control bookkeeping.

If you're unsure whether something is trivial, it isn't. Default to invoking the skill.

---

## Composes with other skills

- **`brainstorming` / `writing-plans` / `subagent-driven-development` / `executing-plans` / `test-driven-development` / `requesting-code-review` / `receiving-code-review` / `finishing-a-development-branch`** (superpowers plugin) — these provide the design, planning, dispatch, TDD, and review mechanics the workflow above hands off to. Architect is the strategic layer above them: it assumes they do the tactical work correctly and verifies the result serves the goal, not just the letter of the request.
- **`taskwork`** (this kit) — architect dispatches with an active tracking issue; the audit confirms the issue was updated. The tracking convention's binding force is the same as a direct user instruction (see "Injected context is binding context").
- If the superpowers plugin isn't installed, architect still works — steps 3, 4, 6, 8, and 13 above fall back to the plain-note/plain-list/direct-dispatch alternatives noted inline, and the verdict/audit apparatus is unchanged either way.

---

## Series-mode and parallel dispatches

Most architect-mode work is one-shot: a single design, a single audit. But long-running series (closing every finding in a multi-module audit, executing a multi-phase migration, sweeping a forbidden pattern across N files) have additional structure.

### Running tally for series work

Across a series, track in working memory or a project-local file:

- **dispatches**: count
- **clean APPROVEs**: count
- **APPROVE-WITH-FOLLOW-UPS**: count + the follow-up issue numbers
- **REDIRECTs**: count + the gap each closed
- **BLOCKs**: count + what was reverted
- **architect/audit-error catches**: count + a one-line description of each (these become the seed for the accreted failure-mode list)

The tally surfaces patterns the orchestrator otherwise misses: "8 of the last 10 dispatches caught stale source-doc findings — the source document is unreliable, treat every cited line as suspect." Without the tally, each dispatch starts fresh and the lesson never accumulates.

Note: `subagent-driven-development` keeps its own per-task ledger for progress within one dispatch — this tally is a different, higher-level thing: the pattern of architect verdicts across an entire series.

### Parallel dispatches

The skill is implicitly serial — one design, one dispatch, one audit, one verdict, then the next. **Parallel dispatches are valid when** the work units are independent: different modules with no shared file edits, different files within a module where the changes don't overlap, independent investigation tasks.

Conditions for going parallel:
- **No shared file edits** between dispatches — verified by reading the designs side-by-side.
- **No cross-dispatch state** — each subagent's success is verifiable in isolation; one failing doesn't poison the others.
- **Independent verification** — the post-audit can read each diff against the goal without needing the others to land first.
- **Workspace build still possible after each individual approve** — for cross-module-dependency projects, parallel dispatches that all touch public APIs are usually NOT independent.

When parallel-dispatching, the architect still produces one design per dispatch (each gets its own goal-alignment frame) and runs the Checkpoint separately for each. They simply fire concurrently rather than sequentially.

When in doubt, go serial. Parallelism is an optimization, not a default.

---

## When the work IS closing tracked findings

A common shape — common enough to call out — is *"close all the findings in audit document X"* / *"address all the lint warnings in report Y"* / *"work through this list of TODOs."* This shape has different evidence requirements than free-form work:

1. **Source-document reassessment is mandatory** during design. Quote each cited line against current code. Stale findings are common.
2. **Per-finding outcome reporting is required**: applied (with category if the project has one) / stale-no-op (with quoted-code proof) / requires-coordination (with the cross-module work named).
3. **The audit walks the finding list, not just the diff.** Did the work address each finding by ID/number? Did any get silently dropped?
4. **Series-mode tally** becomes especially valuable — patterns like "the source document misclassifies severity 30% of the time" are hard to see without it.

If the work isn't tracked-finding closure (it's free-form feature work, design exploration, etc.), the standard workflow cycle applies without the per-finding shape.
