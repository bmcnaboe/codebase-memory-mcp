---
name: linear-plan
description: Plan a batched, autonomous Ralph run over a set of Linear tickets. Trigger whenever the user gives a LIST of ticket references (two or more LETTERS-NUMBER ids like ABC-24 ABC-31, or bare integers as default-team shorthand — "24 31 38" → ABC-24 ABC-31 ABC-38, where the real prefix is pinned in `.claude/linear-workspace.md`) paired with an intent to plan, batch, group, sequence, or run them autonomously — "plan a run for 24, 31, 38", "batch these tickets through ralph", "/linear-plan ABC-24 ABC-31", "queue up 12 40 41 for the loop". The skill fetches every ticket, analyzes overlap and dependencies, designs gate-tiered tranches that combine related work, writes a run plan to linear-specs/<stamp>-<slug>/plan.md, commits it, and hands back the wt-ralphlinear launch command (work loop + chained linear-verify-loop acceptance phase). This is the batch counterpart to linear-fix: one ticket wanting direct work is linear-fix; a set of tickets wanting one orchestrated autonomous run is linear-plan. Don't trigger for authoring/editing tickets (linear-log), verifying finished work (linear-accept), or a single ticket unless the user explicitly wants the ralph flow for it.
argument-hint: "[ticket-ids…] [slug=<name>]"
---

# Linear Plan

Turn a list of Linear tickets into one efficient, autonomous Ralph run. The job is
analysis and packaging: fetch the tickets, find the overlaps, sequence the work into
test-gated tranches, and emit a run plan the stock Ralph loop can execute unattended —
then hand the operator the launch command. You do **not** implement anything here.

Pipeline position: **linear-log** authors tickets → **linear-plan** batches and
launches → the Ralph work loop implements → the **linear-verify-loop** acceptance
phase drives **linear-accept** / rework per ticket. The plan file you write is the
ground truth the whole run keys on — worth getting right.

## Tools you'll need

Linear tools come from the connected Linear MCP server and are usually **deferred** —
load them with `ToolSearch` (keyword `linear`) before first use; don't hardcode the
server's uuid prefix. You need `get_issue`, `list_comments`, and (rarely)
`list_issue_statuses`. No Linear writes happen in this skill — the loop itself claims
tickets when it starts working them.

## Workspace — read the pin

Every ticket this skill plans belongs to the workspace, team, and ticket prefix pinned in
**`.claude/linear-workspace.md`** — read it for the values (this doc refers to them as the
workspace slug, `<TEAM_NAME>`, and `<TEAM_KEY>`). The account may have more than one
workspace, and a run must never target another one.

The Linear MCP tools take **no workspace parameter** — the connected server resolves whichever
workspace its token is bound to. So the pin is a _check_, not an argument:

- **Verify while fetching.** Each `get_issue` result's `url` must start with the pinned
  `https://linear.app/<workspace-slug>/`. If the connector resolves anywhere else, **stop and
  tell the user** — a plan built against the wrong workspace would send the whole autonomous run
  after the wrong tickets.
- **Pass `team: "<TEAM_NAME>"`** on calls that accept it (and `list_issue_statuses`
  requires it).
- **Only `<TEAM_KEY>-` ids are ours.** Bare integers are always the pinned team
  (`24` → `<TEAM_KEY>-24`). A foreign prefix (`PROD-203`, `LIN-412`) presumably lives in the
  other workspace — confirm with the user before planning it in.

The plan you write carries this pin forward: its **Linear protocol** paragraph (Step 4) names
the workspace so the unattended loop and the verify phase inherit it.

## Reading the invocation

- **Ticket ids** — any mix of `LETTERS-NUMBER` ids and bare integers; normalize bare
  integers to the default team (`24` → `<TEAM_KEY>-24`). Order given is a hint, not a
  constraint — your sequencing analysis decides the real order.
- **`slug=<name>`** (optional) — run-dir slug override. Otherwise derive one from the
  tickets' common theme (e.g. `abc-24-31-38-export-fixes`).

If no ids were given, ask for them. One id is fine if the user explicitly wants the
ralph flow; suggest `/linear-fix` when it looks like they just want the work done.

## Step 1 — Fetch and orient

For each ticket: `get_issue` + `list_comments`. Render one compact line per ticket
(identifier, title, status, priority, labels) rather than the full house block — this
is a batch view. Then flag anything that changes the plan before you write it:

- **Not found / archived** → stop and ask; a typo'd id must not silently drop out.
- **Already `<REVIEWED_STATE>` or `Done`** → exclude it and say so.
- **`In Progress` with a real assignee or recent human commits** → surface the
  collision and ask whether to include it.
- **Blocked-by relations pointing outside the batch** → surface; the user decides
  whether to pull the blocker in or drop the dependent.

Read each description's `## Acceptance criteria` and `## Steps to reproduce`
(linear-log authors these), the comment thread's course-corrections, and the effort
labels (per the pin file's effort roster, if your workspace defines one).

## Step 2 — Analyze grouping and sequencing

The whole value of a batched run is doing shared work once. Build the analysis from
the tickets **and** the repo (grep for the surfaces each ticket names — files,
components, endpoints, packages):

- **Overlap** — tickets touching the same surface belong in the same tranche, and
  genuinely overlapping changes merge into a single combined task tagged with every
  ticket it serves. Never implement the same surface twice in one run.
- **Dependencies** — a ticket whose work builds on another's lands in a later tranche.
  Data-model / shared-package changes come before their consumers.
- **Independence stays cheap** — an unrelated small ticket is its own one-or-two-task
  tranche; don't force artificial groupings.
- **Spec-first tickets stand alone** — a ticket carrying the pin file's spec-first flag was
  filed as wanting a written spec before code. Give it a tranche of its own rather than
  folding it into a shared one, and surface it so the user can decide whether it belongs in
  a batched run at all.
- **Risk ordering** — put the riskiest tranche early (more loop budget left to absorb
  trouble), trivial cleanups last.
- **Never let a run invalidate its own completion bar.** `.ralph/command-policy`
  `[gates]` is frozen for the whole run (loop-managed state; the agent cannot edit it).
  If any ticket in the batch changes how the gate is _invoked_ — a new/renamed script,
  a new required argument, a different entry point — the pinned commands must already
  describe the post-change invocation, or the run's own work makes its bar unreachable.
  Prefer, in order: **(a)** author the policy with the post-change invocation up front
  and land the gate change in the first tranche; **(b)** split the gate change into its
  own run, apply the new policy, then batch the rest.
- **Effort rollup** — from the effort labels (pin-file roster, if defined), recommend
  the run's model and reasoning effort: any top-model-tier or spec-flagged ticket →
  the defaults (top-tier model, `xhigh`); an all-lower-tier, low-thinking
  batch can suggest a cheaper model/effort via `RALPH_MODEL` / `RALPH_EFFORT`. Also
  recommend loop caps: `RALPH_ITERATIONS` default 20 is usually fine; suggest
  `RALPH_EVAL_MAX_LOOPS` ≈ `3 × verify-group-count + 4` (see Step 3's verify groups).

Present the tranche design briefly (one line per tranche: tickets, theme, why this
order) before writing the file — the user may redirect.

## Step 3 — Write the run plan

Write to **`linear-specs/<YYYYMMDD-HHMMSS>-<slug>/plan.md`** at the repo root. This
file is both the loop's prompt body and its task checklist, so its format is a
contract. Hard rules first:

- **Checkbox discipline.** The loop counts every line matching `- [ ]` / `- [x]` as a
  task. Only real tasks may use that shape. In the Tickets snapshot section, render
  acceptance criteria as **plain bullets** (`- AC1: …`), never checkboxes.
- **Gates by tier only.** Say "basic gate", "full gate" — never the underlying
  commands. The framing prompt injects the project's real tier commands from
  `.ralph/command-policy` `[gates]`, and the plugin hook auto-wraps invocations.
- **Task ids + ticket tags.** Every task line: `- [ ] T### [<TEAM_KEY>-N] <description>`
  (multi-ticket tasks list every id: `[<TEAM_KEY>-24, <TEAM_KEY>-31]`). Commits reference
  both: `<type>(<scope>): <desc> (<TEAM_KEY>-N T###)` — `git log --grep <TEAM_KEY>-N` is
  how the acceptance phase later confirms the work is present.
- **Tranche closes are `[risky]`.** The framing runs the full gate on `[risky]`
  tasks — that marker on each tranche-close task is what makes tranches test-gated.

The plan's shape:

```markdown
# Linear run — <slug>

**Tickets:** ABC-24, ABC-31, ABC-38 · **Created:** <date>
**Branch:** linear/<slug>
**Recommended:** RALPH_MODEL=<…> · RALPH_EFFORT=<…> · RALPH_EVAL_MAX_LOOPS=<…>
**Verify groups:** A: ABC-24, ABC-31 · B: ABC-38 ← tranche-aligned; the verify
loop uses these to batch linear-accept runs.

## Execution

You are executing a batched Linear-ticket run inside the Ralph loop. Work every
remaining unchecked task in order, in a single continuous turn. Commit, read the
next task, keep going — the loop handles rotation; you handle the work.

The framing above owns the stop conditions, the after-every-commit breadcrumb
checks, the handoff contract, and the gate runner — follow it; none of that is
restated here.

Per task:

1. Read only what the task references (the Tickets section below carries each
   ticket's acceptance criteria); implement the minimum change that satisfies it.
2. Run the basic gate. Mark `[x]` only after it exits 0 — never around a red gate.
3. `git add <exact paths> && git commit -m "<type>(<scope>): <desc> (<TEAM_KEY>-N T###)"`.
   No agent footers, no `--amend`. Then the framing's after-commit checks decide:
   yield or read the next task.

Tranche-close tasks (marked `[risky]`) additionally: the full gate must be green,
then sync Linear for that tranche's tickets as the task describes.

Linear protocol: the Linear MCP tools are usually deferred — load them via
ToolSearch (keyword `linear`) on first use. Every ticket here is in the workspace
pinned in `.claude/linear-workspace.md` (workspace slug `<workspace-slug>`, team
`<TEAM_NAME>`); the tools take no workspace parameter, so before the first write
confirm a fetched issue's url starts with `https://linear.app/<workspace-slug>/`,
and pass `team: "<TEAM_NAME>"` on calls that accept it. A connector scoped to
another workspace is not a best-effort failure: skip Linear writes entirely and log
it, rather than writing to the wrong tracker. Otherwise Linear writes are
best-effort: if a Linear call fails, log it to `.ralph/errors.log` and keep
building — never block code work on the tracker. Catch up missed syncs at the next
tranche boundary.
Status ceiling during this loop is `<IN_REVIEW_STATE>`; never touch `<REVIEWED_STATE>`
or `Done`.

When every task is `[x]` and the full gate is green, emit
`<promise>ALL_TASKS_DONE</promise>`. Genuinely stuck after honest investigation:
emit `<ralph>GUTTER</ralph>` with the root cause.

## Tasks

### Tranche A — <theme> (ABC-24, ABC-31)

- [ ] T001 [ABC-24, ABC-31] Claim tranche: move ABC-24 and ABC-31 to In Progress,
      assignee <agent-user>, one-line start comment each
- [ ] T002 [ABC-24] <implementation task>
- [ ] T003 [ABC-24, ABC-31] <combined overlapping task>
- [ ] T004 [risky] Close tranche A: full gate green; move ABC-24, ABC-31 to
      <IN_REVIEW_STATE>, each with a comment summarizing what landed (commits, surfaces)

### Tranche B — …

## Tickets

### ABC-24 — <title>

<url> · Priority: <…> · Labels: <…>
Acceptance criteria (from the ticket — plain bullets, NOT checkboxes):

- AC1: …
- AC2: …
  Steps to reproduce (bugs): …
  Notes from comments: <distilled course-corrections that change the bar>
```

Snapshot the criteria **verbatim where possible** — the verify phase reads the live
ticket, so drift between snapshot and ticket should be visible, not papered over.
Right-size task granularity: one task ≈ one commit; a trivial ticket can be a single
task plus the tranche close.

## Step 4 — Preflight and commit

1. `.ralph/command-policy` has all three `[gates]` tiers (the loop refuses to start
   without them) — read it to confirm, don't edit it.
2. The linear eval templates exist (`scripts/dev/ralph/linear-eval-framing.md` and
   `linear-ledger-template.md`) — the verify chain needs them in the worktree.
3. Working tree is otherwise clean (the launcher requires it; the worktree branches
   from HEAD, so anything uncommitted won't exist in the run).
4. Commit the plan: `chore(linear-specs): plan <slug> (ABC-24 ABC-31 ABC-38)`.

## Step 5 — Hand off the launch

Print the launch command and what will happen — the operator runs it from their
terminal (loops run in tmux, not in this session):

```
wt-ralphlinear linear/<slug>            # newest plan is picked up automatically
```

Prefix any non-default recommendations from Step 2 (e.g.
`RALPH_EVAL_MAX_LOOPS=13 wt-ralphlinear linear/<slug>`). Note that the run chains
automatically: work loop → linear verify loop (linear-accept per verify group,
rework for `<REOPENED_STATE>` tickets, 2-rework cap). Point at `/monitoring-ralph
<fragment>` for watching it, and `ralph-linear-verify` for re-running verification
alone. Do not launch tmux yourself and do not start implementing tickets — the
plan is the deliverable.
