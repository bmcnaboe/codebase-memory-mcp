---
name: linear-accept
description: Autonomous acceptance testing of a Linear ticket — verify that work already claimed complete actually satisfies the ticket, judged from the end user's perspective, and record the verdict back on the ticket. Trigger whenever a message pairs a tracker issue ID (LETTERS-NUMBER — ABC-24, PROD-203 — or a bare integer like "accept 24", shorthand for the default team pinned in `.claude/linear-workspace.md`) with an intent to verify, accept, acceptance-test, QA, sign off on, or confirm-it-actually-works that ticket — typically one sitting in In Review. So "acceptance test ABC-24", "accept ABC-9", "does ABC-38 actually work end to end?", "QA PROD-203 before we ship", "verify the export ticket is really done", and "/linear-accept ABC-24" all qualify. The skill loads the ticket, drafts an acceptance test plan and attaches it, exercises the real product surfaces (the webapp via browser tooling for anything UI-observable; the API and agent-facing surfaces directly for the rest), captures evidence onto the ticket, then moves it to the passed or needs-work state pinned in `.claude/linear-workspace.md` — or leaves status untouched and asks when the verdict is unclear. The approach can be passed inline ("/linear-accept ABC-24 worktree"); it defaults to in-place. Prefer this over linear-fix when the ask is to check/verify/accept finished work rather than to do it, and linear-log when the ask is only to edit the ticket record. Don't trigger for filing a new issue, a plain status bump, or non-issue codes like ERR-503.
argument-hint: "[ticket-id] [in-place|worktree]"
---

# Linear Accept

Independently acceptance-test a Linear ticket and tell the truth about whether it's
actually done. The ticket is the shared source of truth — collaborators trust its status,
not your terminal — so the whole point of this skill is to turn "In Review" into a
_verdict backed by evidence_: an acceptance plan, real exercise of the product, artifacts
that prove what you saw, and a status that honestly reflects the result.

This is the verification counterpart to **linear-fix**. linear-fix _does_ the work an
issue describes; linear-accept _checks_ work that's already claimed done. If partway through
you find the ticket needs code changes, don't quietly fix it — that's linear-fix's job.
Record what's broken, move the ticket to the needs-work state (`<REOPENED_STATE>`, pinned in
`.claude/linear-workspace.md`), and let the fix happen as its own pass. Your credibility here
comes from being an honest reviewer, not a silent patcher.

## Judge from the end user's perspective

This project has up to three surfaces a real "user" touches, and acceptance is judged through
them:

- **The webapp** — the human UI. Drive it with **Playwright** for anything a user would
  see or click. Use **the repo's login mechanism** to boot the app and sign in; don't reinvent
  that flow.
- **The project's MCP server / product API** — the AI-agent-facing surface, if the project
  exposes one (its create / update / read tools). For an agent user, _this is the UI_. Writes
  may require specific context, permissions, or auth; exercise it as a real agent client would.
- **The API** (`apps/api`) — the REST backbone under both. Reach for it directly to verify
  non-UI behavior, set up state fast, or confirm what the UI is really persisting.

"End-user perspective" means the **acceptance bar is observable behavior**, not
implementation detail. But this needn't be purely black-box: peeking at the DB, API
responses, logs, or the diff to reach a state quickly, confirm a root cause, or check
_why_ something passed is fair game and often more thorough. Grey-box for efficiency; judge
by what a user experiences. The repo's `scripts/smoke/deploy-smoke.mjs` is the house model
for black-box-over-the-wire checks — echo its spirit for API/agent-surface verification.

## Tools you'll need

**Linear** tools come from the connected Linear MCP server and are usually **deferred** —
load them with `ToolSearch` (search the keyword `linear`) before first use. **Don't hardcode
the server's hash prefix** (`mcp__<uuid>__get_issue`; the uuid varies per session/machine):

- `get_issue` — fetch the issue (returns `attachments[]`, `gitBranchName`, status, labels).
- `list_comments` — read prior discussion and any earlier acceptance findings.
- `list_issue_statuses` — resolve the team's real state names before moving status.
- `save_issue` — change status (`id` = the identifier, `state` = a state name/id).
- `save_comment` — post findings (`issueId` + `body`, Markdown with literal newlines).
- `prepare_attachment_upload` + `create_attachment_from_upload` — attach the plan and
  evidence (recipe below). `get_attachment` reads a prior plan back; `delete_attachment`
  tidies a superseded one.

**Product surfaces**: Playwright MCP (`mcp__plugin_playwright_playwright__browser_*` — also
usually **deferred**; load via `ToolSearch`, keyword `browser`), the repo's login mechanism
(boot + auth), and Bash/`curl` for the API and any agent-facing surface.

## Workspace — read the pin

Every Linear activity in this project targets the workspace, team, and ticket prefix pinned in
**`.claude/linear-workspace.md`** — read it for the values (this doc refers to them as the
workspace slug, `<TEAM_NAME>`, and `<TEAM_KEY>`). The account may have more than one workspace,
and nothing here may touch another one. The same pin file names the workflow **state names** the
skill moves tickets to — the passed state `<REVIEWED_STATE>` and the needs-work state
`<REOPENED_STATE>` — resolve their real names with `list_issue_statuses` (if a pinned state
doesn't resolve, leave the ticket's status untouched and record the verdict in a comment
instead — see the pin file's graceful-fallback note).

The Linear MCP tools take **no workspace parameter** — the connected server resolves whichever
workspace its token is bound to. So the pin is a _check_, not an argument:

- **Verify before the first write.** Every entity Linear returns carries a `url`; it must start
  with the pinned `https://linear.app/<workspace-slug>/` (equivalently, `list_teams` returns
  `<TEAM_NAME>`). If the connector resolves anywhere else, **stop and tell the user** — do not
  move status, comment, or attach evidence in the other workspace.
- **Always pass `team: "<TEAM_NAME>"`** on calls that accept it — `save_issue`,
  `list_issues`, `list_projects`, `list_issue_labels`, `list_users` (and
  `list_issue_statuses`, which requires it) — so a re-scoped connector can't drift silently.
- **Only `<TEAM_KEY>-` ids are ours.** Bare integers are always the pinned team
  (`24` → `<TEAM_KEY>-24`). A foreign prefix (`PROD-203`, `LIN-412`) presumably lives in the
  other workspace — confirm with the user before acting on it rather than assuming it's a typo.

## Reading the invocation

Two things can ride along, both optional, in any order, named or bare:

- **The ticket ID** — the `LETTERS-NUMBER` identifier. Bare (`/linear-accept ABC-24`) or
  named (`ticket=ABC-24`, `id=ABC-24`). A bare integer (`24`, `ticket=24`) is shorthand for
  the default team — normalize it to `<TEAM_KEY>-24` before any Linear call.
- **The approach** — which environment to test in, so the user can skip the chooser:
  - `in-place`, `here`, `current`, `inplace` → **Path 1 (Test here)**
  - `worktree`, `wt`, `tree`, `clean` → **Path 2 (Clean worktree)**

Anything you can't confidently map to a path, ignore as a path hint and fall back to asking
in Step 2. If no ticket ID is present, ask for it.

## Step 1 — Orient: fetch, summarize, find the acceptance bar

`get_issue` on the identifier, then render **exactly** the house-style block linear-fix uses
so the output reads the same across the Linear skills:

```
**[{IDENTIFIER}: {title}]({url})**

- **Status:** {status} · **Priority:** {priority.name} · **Label:** {labels}
- **Team:** {team} · **Project:** {project}
- **Branch:** `{gitBranchName}`
- **Created:** {createdAt:YYYY-MM-DD} by {createdBy}

**Description:** {description}
```

(Join labels with `, `, dropping the segment if none; `Project` → `—` if absent; date only.)

Then add a three-line synthesis so the reader knows where things stand before any testing:

- **Objective** — what the ticket set out to deliver, in one line.
- **Work completed** — what was actually built (read `list_comments`; skim the diff / commits
  — `git log --oneline --grep {IDENTIFIER}` — and, if the ticket maps to a Spec Kit spec,
  read `specs/<…>/spec.md` + `quickstart.md`, which _are_ the intended acceptance criteria).
- **Current standing** — status, and whether a prior acceptance plan is already attached.

**Look for a prior plan:** scan `attachments[]` for an "Acceptance Test Plan" (or results)
this skill left before. If one exists, read it back and use it as the starting point — carry
its criteria and prior results forward and refine, rather than starting from a blank page.

**Confirm the work is actually in your tree.** This skill tests the code in your current
working tree — it deliberately does not switch to the ticket's branch. So before testing,
verify the ticket's work is present: `git log --oneline --grep {IDENTIFIER}` (or confirm the
branch merged / that you're on it). If it isn't there — e.g. the work sits on an unmerged
branch and you're on `main` — surface that and let the user decide (check out the branch, or
point you at the right environment). Testing code that isn't present fails every criterion and
would wrongly re-open the ticket; a false negative misleads the team as badly as a false pass.

Show this summary before going further — reading is always safe and never touches Linear.

## Step 2 — Pick the test environment

**If the invocation named an approach**, take it. **Otherwise default to Path 1 (Test here)** —
in-place on the current branch, no chooser. Either way, print one line noting the path
(`Testing in-place on the current branch (default).` or `Testing in a clean worktree (from
your invocation).`) and continue. Reach for the clean worktree only when the user names it —
or when the current environment can't give a trustworthy result (e.g. a mutated dev DB), in
which case switch and say why. The two paths:

1. **Test here** _(default)_ — use the current branch and whatever environment is already running. Fast;
   best right after the work was done, or when the code is on your current branch already.
2. **Clean worktree** — spin up an isolated worktree from the **current HEAD** (`wt switch
--create accept/<slug>`, the `<slug>` derived from the identifier + title as linear-fix
   does), which runs `worktree:up` for a **fresh DB seed and its own
   ports**. Best when you want a pristine, known-seed environment and don't want to disturb
   your running dev server. This tests the _current branch's code_ in a clean box — it does
   **not** check out the ticket's own branch.

Starting acceptance testing is non-destructive, so picking a path is authorization enough —
no second confirmation. Post a brief start comment via `save_comment` so collaborators know
review is underway (e.g. `🤖 Starting acceptance testing (clean worktree).`), and **leave the
status at In Review** while you test — the verdict moves it, not the start.

For the clean-worktree path: after `wt switch --create`, get the worktree path from
`git worktree list`, call **`EnterWorktree`** with `path:` = that path, and verify with `pwd`

- `git branch --show-current` before doing anything. (Same worktree mechanics and
  statusline-chip caveat as linear-fix Path 2 — see it if you need the details.) Then boot +
  auth there via the repo's login mechanism.

## Step 3 — Draft (or refresh) the acceptance test plan, and attach it

Decide the best way to verify _this_ change and write it down before executing — the plan
keeps you honest and gives the next reviewer a re-runnable script. **Right-size it**: a
one-line copy tweak deserves a couple of checks and a screenshot; a feature spanning several
screens deserves a full surface sweep. Map each acceptance criterion to the surface that proves
it (UI-observable → Playwright; data/agent/persistence behavior → API or the agent surface
directly). When the ticket names a specific surface or trigger ("from the agent surface"),
exercise that one directly at least once rather than a proxy — acceptance shouldn't lean on an
equivalence it exists to verify.

**Start from whatever the ticket gives you.** If linear-log left an `## Acceptance criteria`
section, that's your canonical bar — carry those items into the plan and verify each. But plenty
of tickets, especially hand-written ones, have no such section, only a terse description, or no
linked spec and no prior plan — that's normal, and everything here still runs. Treat every
structure (authored criteria, `## Steps to reproduce`, a spec, a prior plan, log-time repro
evidence) as a helpful head start when present, never a precondition; when one's missing, infer
the bar best-effort from what _does_ exist — description, title, comments, the diff — and carry
on. The one line not to cross: don't manufacture a confident pass/fail against a bar you had to
invent. If the intended behavior is genuinely unclear, that's precisely the **UNSURE** verdict
(Step 5) — say what's ambiguous and ask. For a bug, use `## Steps to reproduce` (or, if absent,
the description) as a regression check — the bug must no longer repro — with any log-time repro
evidence as the "before" baseline.

Write the plan to a temp file in the scratchpad using this shape, then attach it:

```markdown
# Acceptance Test Plan — {IDENTIFIER}: {title}

**Ticket:** {url} · **Date:** {YYYY-MM-DD} · **Approach:** {in-place|worktree} · **Env:** {branch / base URL}

## Objective

{1–2 lines}

## Acceptance criteria

From the description's `## Acceptance criteria` (linear-log), plus comments and any linked spec.

- [ ] AC1 …
- [ ] AC2 …

## Verification strategy

| #   | Criterion | Surface   | How to verify | Evidence to capture |
| --- | --------- | --------- | ------------- | ------------------- |
| 1   | …         | Webapp    | …             | screenshot          |
| 2   | …         | API/Agent | …             | transcript          |

## Results

_(filled in during execution)_
| # | Criterion | Result | Evidence | Notes |
|---|-----------|--------|----------|-------|

## Verdict

_(Pass → <REVIEWED_STATE> · Needs work → <REOPENED_STATE> · Unsure → unchanged)_
```

**Attaching a file** — three steps, and do them one file at a time (don't batch the
`prepare` calls; each signed URL expires in ~60s):

1. `prepare_attachment_upload` with `{ issue, filename, contentType: "text/markdown", size }`
   — `size` is the exact byte count (`wc -c <file>`). It returns `uploadRequest.url`,
   `uploadRequest.headers`, and an `assetUrl`.
2. PUT the raw bytes, sending **every** header from `uploadRequest.headers` verbatim (casing
   matters — a missing or edited header returns 403):
   `curl -X PUT --data-binary @<file> -H '<header>' … "<uploadRequest.url>"`.
3. `create_attachment_from_upload` with `{ issue, assetUrl, title: "Acceptance Test Plan" }`.

Then **delete the local temp file** — the ticket is the durable home for the plan, not disk.

## Step 4 — Execute the plan and capture evidence

Work the plan criterion by criterion, exercising the real surfaces. As you go, capture proof
of what you observed — evidence is what separates a verdict from an opinion:

- **Webapp** — after signing in via the repo's login mechanism, drive with Playwright;
  `browser_take_screenshot` at each meaningful state (before/after, the assertion moment). Save
  PNGs to the scratchpad.
- **API / agent surface** — record the request and response for each check (a short transcript:
  method, URL, key inputs, status, salient response fields). Agent-surface writes may require
  specific context/permissions; a write without it should be rejected (e.g. 422) — verifying
  that _rejection_ is itself often a valid acceptance check.
- **Logs** — keep the server log (`/tmp/webapp-start.log` or the API log) for anything that
  fails, so a failure carries a diagnostic, not just "didn't work".

A failure that's really infrastructure — a 500 on an unrelated write, a missing-migration or
missing-table error, connection-refused — is the environment, not the ticket: fix it (migrate,
reseed) or escalate, and never fail a criterion on it.

Fill in the plan's **Results** table as you land each check (✅ pass / ❌ fail / ❓ unclear).

**Embed screenshots _inline_ in the findings comment — don't file them in the attachments rail.**
A reviewer scanning the ticket should see the proof sitting right next to the claim it backs (the
before/after, the assertion moment), not have to open attachments one at a time to reconstruct what
happened. So drop each meaningful frame into the comment Markdown with
`![AC2 — record persists after reload](assetUrl)`, captioned by the criterion it proves. To get an
embeddable `assetUrl`, run only the **first two** steps of the attachment recipe below —
`prepare_attachment_upload` then the PUT (`contentType: "image/png"`) — which uploads the bytes and
hands back a hosted `assetUrl`; put that in the image tag and **skip** `create_attachment_from_upload`,
whose whole job is to file the asset in the rail you're trying to keep the eye out of. Curate hard:
the two or three frames that carry the verdict, not every frame.

Bulky or non-visual artifacts — server logs, long API/agent transcripts, the plan file itself — stay
**attachments** (full three-step recipe; `text/plain`/`text/markdown`): they're reference a reader
opens on demand, not something to scan. Give each a clear title (`AC2 — record persists after reload`).

## Step 5 — Record the verdict and set status

Resolve the exact state names with `list_issue_statuses` (don't assume), then land one of
three outcomes. Update the attached plan's Results + Verdict (re-attach the completed version;
optionally `delete_attachment` on the plan-only copy to avoid duplicates) and post a findings
comment:

- **PASS → `<REVIEWED_STATE>`.** Every acceptance criterion verified. If the test environment
  couldn't reproduce the original failing condition (e.g. a prod-only race), say so — a caveated
  pass that names what it didn't prove beats a bare one. Comment a concise summary of what was
  checked and the evidence. The reviewed state says _an agent checked this and it
  held up_ — it is **not** Done.
- **NEEDS WORK → `<REOPENED_STATE>`.** Any criterion fails. This is the outcome to capture
  _richly_, because someone will fix it cold: for each failure, what you expected vs. what
  happened, the exact repro, and — if you spotted it — where in the code / which layer. Link the
  evidence.
- **UNSURE → leave the status unchanged.** If you genuinely can't call pass/fail — ambiguous
  acceptance bar, an environment problem you couldn't rule out, behavior that might be intended
  — **don't force a verdict.** Comment what you observed, what's blocking the call, and what
  you'd need to decide. Then end your turn with a short summary of the situation and the ask.
  If the decision narrows to a few options, use `AskUserQuestion` (multi-select is fine) to get
  unstuck. A truthful "I'm not sure, here's why" beats a confident wrong verdict.

### The lines you don't cross

- **Never move the ticket to `Done`.** Done means _live in the default branch_ — a human,
  post-merge call, exactly as in linear-fix. Acceptance passing is `<REVIEWED_STATE>`, full stop.
- **Don't fix the code.** Finding a bug is a needs-work finding, not a silent patch. (If the
  user explicitly asks you to fix it after, that's a hand-off to linear-fix.)
- **Don't push or merge.** Verification is local; publishing stays a human, explicit-ask act.

Moving the ticket to `<REVIEWED_STATE>` / `<REOPENED_STATE>` and attaching the plan + evidence
_are_ the skill's deliverable — running it is the authorization for those. Everything above is
what stays off-limits.

### Verdict comment shape

```
🤖 **Acceptance testing — {PASS | NEEDS WORK | UNSURE}**

Approach: {in-place|worktree} · Env: {branch / URL}
Plan & full results attached.

**Verified**
- ✅ {criterion} — {one-line evidence}
  ![{criterion} — proof](assetUrl)     ← inline screenshot, sitting under the criterion it proves

**Needs work**            ← only when something failed
- ❌ {criterion} — expected {x}, got {y}. {repro / where, if known}
  ![{criterion} — actual](assetUrl)

**Evidence:** screenshots embedded inline above · {N} transcripts/logs attached
```

## Clean up

`browser_close` when done with Playwright (a leftover browser locks the shared profile).
Stop any dev server you started for the run. For a clean-worktree run, tear the worktree
down once evidence is attached (its branch was a disposable test carrier, not work to merge).
