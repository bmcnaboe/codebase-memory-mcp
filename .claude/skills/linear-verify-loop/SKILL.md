---
name: linear-verify-loop
description: Orchestrates the post-run acceptance phase for a batched Linear-ticket Ralph run. Use when invoked by the linear eval framing prompt (ralph-evaluate.sh renders scripts/dev/ralph/linear-eval-framing.md, which points here). Reads the ticket ledger (.ralph/acceptance-report.md seeded from linear-ledger-template.md) and the linear-specs run plan, picks one mode per loop — VERIFY (acceptance-test a group of tickets via the linear-accept skill), REWORK (fix tickets sent back to the needs-work state, max 2 rework cycles per ticket), or GATE-FIX (repair a red final-tier gate) — and delegates the actual work to a sub-agent via the Task tool. Stays lean across loops; enforces the per-ticket rework cap; runs until every target ticket is at the pinned passed state or terminally FAILED/UNSURE. Not user-invoked in interactive sessions — linear-accept and linear-fix are the interactive counterparts.
---

# Linear verify loop

You are the **acceptance orchestrator** for a completed Linear-ticket Ralph run. You
verify and fix nothing yourself — each loop you read the ledger, pick one mode,
dispatch one sub-agent via the Task tool, and record the outcome. Stay lean; the
sub-agent carries the heavy context.

## Inputs (from the framing prompt)

- **Run plan** (ground truth): the `linear-specs/…/plan.md` that drove the main run.
  Its header lists the target tickets and **verify groups**; its Tickets section
  snapshots each ticket's acceptance criteria.
- **Ticket ledger**: `.ralph/acceptance-report.md`. Your working document. The loop's
  task-counter reads it — every `- [ ]` line is unfinished work, so the file may
  contain checkboxes ONLY as the top-level line plus one row per ticket.

## Workspace — read the pin

Every target ticket lives in the workspace, team, and ticket prefix pinned in
**`.claude/linear-workspace.md`** (this doc refers to them as the workspace slug,
`<TEAM_NAME>`, and `<TEAM_KEY>`). The Linear MCP tools take no workspace parameter, so
each sub-agent must confirm the entities it fetches carry a
`https://linear.app/<workspace-slug>/` url before writing. This run is headless — nobody
is watching to catch a wrong-workspace write — so a sub-agent that finds the connector
scoped elsewhere must write the mismatch to the ledger's Findings and return WITHOUT
touching any ticket, rather than guessing.

The pin file also names the workflow **state names** the loop keys on — the in-review
ceiling `<IN_REVIEW_STATE>`, the passed state `<REVIEWED_STATE>`, and the needs-work
state `<REOPENED_STATE>`.

## The ledger contract

One row per ticket, exactly:

`- [ ] <TEAM_KEY>-N — <title> · status: <Linear status> · reworks: 0/2`

A row becomes `[x]` only when terminal:

- `status: <REVIEWED_STATE>` — passed acceptance, or
- `FAILED (capped)` — sent back to `<REOPENED_STATE>` with no rework budget left, or
- `UNSURE (needs human)` — two verify passes ended unsure with nothing changing.

Ownership: sub-agents update row **status** and append **Findings** bullets (plain
`<TEAM_KEY>-N: ✅/❌ …` bullets, never checkbox syntax). You alone update **reworks**
counters, mark rows terminal, maintain the header fields and **History**, and flip
the top-level checkbox. Never edit the run plan, never commit the ledger (it lives
under gitignored `.ralph/`), never push, never move any ticket to `Done`.

## Per-loop workflow

**Step 1 — Read the ledger and the plan header** (Read tool; nothing else).

**Loop 1 initialization:** if the Tickets section has no rows yet, create one per
target ticket from the plan (title from the snapshot, `status: <IN_REVIEW_STATE>`,
`reworks: 0/2`), then proceed.

**Step 2 — Pick the mode deterministically from the ledger** (never by alternating
with the previous loop):

1. **Early exit** — top-level checkbox `[x]` and **Status:** `CLEAN` → emit
   `<ralph>COMPLETE</ralph>`. Nothing else.
2. **Cap enforcement (inline, before dispatch)** — any unchecked row with
   `status: <REOPENED_STATE>` and `reworks: 2/2`: mark it `[x] … FAILED (capped)`, and
   post one comment on the ticket (Linear MCP tools are deferred — ToolSearch, keyword
   `linear`): "🤖 Failed acceptance after 2 rework cycles — leaving it in the needs-work
   state for human attention." The Linear status stays `<REOPENED_STATE>`. This is the
   only Linear write you make yourself.
3. **REWORK** — any unchecked row with `status: <REOPENED_STATE>` and rework budget left →
   dispatch REWORK for all such tickets, and increment each one's `reworks` counter
   **now**, at dispatch time.
4. **VERIFY** — otherwise, any unchecked row (`<IN_REVIEW_STATE>`, unknown, or unsure) →
   dispatch VERIFY for the **next verify group** (from the plan header) that
   contains such tickets. One group per loop — sub-agents share the dev
   environment, so groups never run in parallel.
5. **All rows terminal but top-level still `[ ]`** → dispatch VERIFY as a
   **confirmation pass** (fresh final gate + no-regression spot check; no per-ticket
   re-acceptance needed).

If the previous loop's VERIFY reported a **red final gate**, dispatch **GATE-FIX**
before any other mode (after step 2's cap check).

**Step 3 — Dispatch one sub-agent** (Task tool, `subagent_type: general-purpose`),
then wait. Prompts:

- **VERIFY**:

  > Invoke the `linear-accept` skill for each of <TICKET-a, TICKET-b> in that order —
  > approach `in-place`, sharing one booted environment across tickets. All tickets
  > are in the Linear workspace pinned in `.claude/linear-workspace.md` (team
  > `<TEAM_NAME>`); confirm each fetched issue's url starts with
  > `https://linear.app/<workspace-slug>/` and, if not, add a Findings bullet and
  > return without writing to Linear. Run plan
  > (criteria snapshots): `<PLAN_PATH>`. Ledger: `<LEDGER_PATH>`. First, if the
  > ledger's **Final gate** header doesn't show a green run covering the current
  > HEAD: run the final-tier gate — command from `[gates].final` in
  > `.ralph/command-policy`, runner path in `.ralph/gate-runner`, invoked exactly as
  > `bash "$(cat .ralph/gate-runner)" final <command>`, foreground, generous tool
  > timeout (600000 ms); exit 75 means still running — re-run the same command to
  > keep waiting. If the gate is red: update the Final gate header, add a Findings
  > bullet, and return WITHOUT verifying or moving any ticket. If green (or
  > already covered): update the header, then run linear-accept fully per ticket —
  > evidence, verdict, status move to `<REVIEWED_STATE>` or `<REOPENED_STATE>`. You are
  > headless: never ask questions; an UNSURE verdict leaves the ticket's status untouched
  > and notes `unsure` in its ledger row. After each ticket, update its ledger row
  > status; mark rows `[x]` only when `<REVIEWED_STATE>`. Do not fix code, do not touch
  > reworks counters, do not flip the top-level checkbox. Return 2–3 sentences:
  > final-gate state and each ticket's verdict.

- **REWORK**:

  > Tickets <TICKET-a (cycle N/2), TICKET-b (cycle M/2)> were sent back to
  > `<REOPENED_STATE>` by acceptance testing. All are in the Linear workspace pinned in
  > `.claude/linear-workspace.md` (team `<TEAM_NAME>`); confirm each fetched issue's url
  > starts with `https://linear.app/<workspace-slug>/` and, if not, stop and report the
  > mismatch instead of writing to Linear.
  > For each, in order: read the ticket and its latest needs-work findings
  > comment (Linear MCP; ToolSearch keyword `linear`), move it to In Progress, fix
  > strictly what the findings describe — no scope creep — with tests covering the
  > failure. Run the basic-tier gate (command from `[gates].basic` in
  > `.ralph/command-policy`; runner in `.ralph/gate-runner`, label `basic`) after
  > each fix; commit per ticket as `fix(<scope>): <desc> (<TEAM_KEY>-N)`; then move the
  > ticket back to `<IN_REVIEW_STATE>` with a comment summarizing the fix. You are
  > headless — full autonomy, no questions, no plan mode. Status ceiling:
  > `<IN_REVIEW_STATE>`. Update each ticket's ledger row status to `<IN_REVIEW_STATE>`. Do
  > not add Findings, do not touch reworks counters or checkboxes. Return 2–3 sentences
  > per ticket.

- **GATE-FIX**:
  > The final-tier gate is red (see the ledger's Final gate header and
  > `.ralph/gates/final-latest.log`). Root-cause and fix it — the failure may be in
  > run code or infrastructure. Commit the fix. Re-run the final gate via
  > `bash "$(cat .ralph/gate-runner)" final <command from [gates].final>`
  > (foreground, 600000 ms timeout, re-run on exit 75) and update the ledger's
  > Final gate header with the result. Never hand-write `.ralph/gates/*` files.
  > Do not touch tickets or ledger rows. Return 2–3 sentences.

**Step 4 — Record.** When the sub-agent returns: apply your owned updates (unsure
tracking: a row whose second consecutive VERIFY verdict is `unsure` with no status
change becomes `[x] … UNSURE (needs human)` plus a ticket comment). Append one
History line — `loop N - MODE(tickets) - <summary>` — and bump **Last loop** /
**Last mode**.

**Step 5 — Flip the top-level checkbox** only when every row is terminal AND the
loop that just returned was a VERIFY pass reporting a green final gate covering
current HEAD. Set **Status:** `CLEAN` in the same edit. Then stop — the loop's
task-counter sees the clean ledger and exits (its completion guard independently
re-checks the `final` gate breadcrumb).

## What not to do

- Don't verify, fix, or run gates yourself (the one exception: the inline
  cap-enforcement comment in Step 2).
- Don't pick the mode by alternation; the ledger state decides.
- Don't dispatch more than one sub-agent per loop — they share one dev environment.
- Don't let any sub-agent instruction drift the checkbox contract: no new `- [ ]`
  lines anywhere in the ledger, ever.
- Don't move any ticket to Done, don't push, don't merge — those stay human.

## Why sub-agents

Same reason as the stock acceptance loop: the verifier needs an independent read.
Sub-agents start from a fresh context seeded only with your dispatch prompt, so a
VERIFY pass judges the repo and the live tickets — not your orchestration history,
and not the work loop's self-assessment.
