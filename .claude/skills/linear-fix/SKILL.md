---
name: linear-fix
description: Trigger this whenever a message contains a tracker issue ID — the shape is LETTERS-NUMBER (ABC-5, PROD-203, LIN-412, ABC-19), or a bare integer used as a ticket reference ("fix 120", "/linear-fix 120"), which is shorthand for the default team (120 → ABC-120, where the real prefix is pinned in `.claude/linear-workspace.md`) — paired with any wish to act on that issue. The action can be small or large — look at it, pull it up, summarize, triage, pick it up, grab it, start, work, fix, tackle, sort out, knock out, walk me through it, spec it out, or open a worktree for it. The ID plus that intent is the whole signal — assume Linear; the user need not say "Linear" or name any tool, branch, or status. So "let's fix the login bug, it's ABC-5", "pick up PROD-203", "grab ABC-5 and spin up a worktree", "spec out ABC-19 first", and "take a look at LIN-412, let's knock it out" all qualify. The skill fetches the issue, prints a standard summary, and starts the work — current branch, new worktree, or full spec — keeping the issue's status and comments in sync. Runs on /linear-fix; the ticket ID and an optional approach (in-place, worktree, speckit) can both be passed inline (e.g. "/linear-fix ABC-5 worktree", "/linear-fix ticket=ABC-5 approach=speckit") — the approach defaults to in-place (the current branch) when omitted, with worktree and speckit taken by name. Don't trigger for filing a brand-new issue, bumping status with no work, plain git/branch commands, or non-issue codes like ERR-503.
argument-hint: "[ticket-id] [in-place|worktree|speckit]"
---

# Linear Fix

Turn a Linear issue into action: fetch it, show a clean summary, tackle it (on the current
branch by default, or in a worktree / via a full spec when asked), and keep the Linear issue
itself honest (status + comments) the whole way through. The Linear issue is the shared source of truth — collaborators see
its state, not your terminal — so every meaningful move here is mirrored back to it.

## Tools you'll need

The Linear tools come from the connected Linear MCP server and are usually **deferred**.
Load them with `ToolSearch` before first use — search the keyword `linear`, or select by
capability. **Do not hardcode the server's hash prefix** (it looks like
`mcp__<uuid>__get_issue` and the uuid varies per session/machine). You need:

- `get_issue` — fetch the issue
- `list_issue_statuses` — resolve the team's real workflow state names
- `save_issue` — change status (its `state` param takes a state name/type/id, plus `id` = the issue identifier)
- `save_comment` — add a comment (`issueId` + `body`)

## Workspace — read the pin

Every Linear activity in this project targets the workspace, team, and ticket prefix pinned in
**`.claude/linear-workspace.md`** — read it for the values (this doc refers to them as the
workspace slug, `<TEAM_NAME>`, and `<TEAM_KEY>`). The account may have more than one workspace,
and nothing here may touch another one. The same pin file names the workflow **state names** the
skill uses — the in-review ceiling `<IN_REVIEW_STATE>`, the passed state `<REVIEWED_STATE>`, and
the needs-work state `<REOPENED_STATE>` — resolve their real names with `list_issue_statuses`.

The Linear MCP tools take **no workspace parameter** — the connected server resolves whichever
workspace its token is bound to. So the pin is a _check_, not an argument:

- **Verify before the first write.** Every entity Linear returns carries a `url`; it must start
  with the pinned `https://linear.app/<workspace-slug>/` (equivalently, `list_teams` returns
  `<TEAM_NAME>`). If the connector resolves anywhere else, **stop and tell the user** — do not
  create, edit, or comment in the other workspace.
- **Always pass `team: "<TEAM_NAME>"`** on calls that accept it — `save_issue`,
  `list_issues`, `list_projects`, `list_issue_labels`, `list_users` (and
  `list_issue_statuses`, which requires it) — so a re-scoped connector can't drift silently.
- **Only `<TEAM_KEY>-` ids are ours.** Bare integers are always the pinned team
  (`120` → `<TEAM_KEY>-120`). A foreign prefix (`PROD-203`, `LIN-412`) presumably lives in the
  other workspace — confirm with the user before acting on it rather than assuming it's a typo.

## Reading the invocation

Two things can ride along with the invocation — both optional, in any order, named or bare:

- **The ticket ID** — the `LETTERS-NUMBER` identifier (`ABC-5`). Accept it bare
  (`/linear-fix ABC-5`) or named (`ticket=ABC-5`, `id=ABC-5`, `issue=ABC-5`). A bare
  integer (`120`, `ticket=120`) is shorthand for the default team — normalize it to
  `<TEAM_KEY>-120` before any Linear call, and use the full identifier from there on.
- **The approach** — which of the three paths to take, so the user can skip the chooser
  when they already know. Accept it bare or named (`approach=worktree`), matching loosely:
  - `in-place`, `here`, `current`, `inplace` → **Path 1 (Work it here)**
  - `worktree`, `wt`, `tree` → **Path 2 (New worktree)**
  - `speckit`, `spec`, `spec-it`, `plan` → **Path 3 (Spec it out)**

So `/linear-fix ABC-5 worktree`, `/linear-fix ticket=ABC-5 approach=speckit`, and
`/linear-fix spec it out ABC-19` all parse to an ID plus a path. Anything you can't confidently
map to a path, ignore as a path hint — fall back to asking in Step 2. A bare token that isn't
the ID and isn't a recognizable approach is not an error; just don't force it into either slot.

## Step 1 — Fetch and summarize

Take the issue ID from the invocation (see **Reading the invocation**). If none was given, ask
for it. Call `get_issue` with the identifier, then render **exactly** this format — it's
the house style and people have learned to read it at a glance:

```
**[{IDENTIFIER}: {title}]({url})**

- **Status:** {status} · **Priority:** {priority.name} · **Label:** {labels}
- **Team:** {team} · **Project:** {project}
- **Branch:** `{gitBranchName}`
- **Created:** {createdAt:YYYY-MM-DD} by {createdBy}

**Description:** {description}
```

Field notes so the summary stays clean:

- **Label** — join multiple labels with `, `. If there are none, drop the ` · **Label:** …`
  segment rather than printing an empty one.
- **Project** — if absent, show `—`.
- **Created** — date only (`2026-06-29`), and `createdBy` as returned (the email is fine;
  it matches the house style).
- **Priority** — use `priority.name` (e.g. `Medium`, `None`).

Stop here and show the summary. Summarizing is always safe and never touches Linear.

## Step 2 — Offer how to tackle it

**If the invocation already named an approach** (see **Reading the invocation**), treat that
as the user's choice and skip the chooser — naming a path up front _is_ the authorization to
start, just as picking one in the chooser would be. Print one line noting the path you're
taking (e.g. `Taking the new-worktree path (from your invocation).`) so the choice is visible,
then go straight to Step 3. The user can always interrupt to redirect.

**Otherwise, default to Path 1 (Work it here)** — don't run a chooser. When no path is named,
the current branch is the default: print one line noting it
(`Working it here on the current branch (default).`) and continue to Step 3. Reserve Path 2 and
Path 3 for when the user names them, or when the work clearly outgrows the current branch — in
which case surface that and let the user decide rather than switching silently.

**One signal outranks the default:** an issue carrying the pin file's spec-first flag (see
`.claude/linear-workspace.md`) was filed as wanting a written spec before code. Don't switch
silently either — name the flag, recommend Path 3, and let the user confirm or override.

The three paths, for reference:

1. **Work it here** _(default)_ — stay in this session, on the current branch (whatever it
   is). Best for small fixes that don't warrant their own worktree.
2. **New worktree** — isolate the work in a fresh worktree via worktrunk, then continue in
   it. Best when the change is non-trivial or you don't want to disturb the current branch.
3. **Spec it out** — run `/speckit-full-spec` to produce a full spec/plan/tasks before any
   code. Best for larger or ambiguous work that deserves planning first.

**One guard before defaulting in:** if the ask was purely to _look at / summarize / triage_ the
issue — read-only intent, no wish to start — stop after the Step 1 summary instead. Path 1 is
still real work (Step 3 claims the issue `In Progress` and starts coding), so take it only when
the user actually wants the work done, not merely to see the ticket.

## Step 3 — On authorization, claim the issue

Picking any of the three paths **is** the authorization to start — no second confirmation
needed. Before doing the path-specific work, claim the issue so its state reflects reality:

1. **Comment what's happening and resolve your Linear identity.** Call `save_comment`
   (`issueId` = the identifier) with the appropriate start message. The returned comment's
   `author.id` is the active agent's Linear user ID, whether the agent is ChatGPT, Claude, or
   another app user. Capture that ID; do not guess an agent email or name, and do not use
   `assignee: "me"` because that resolves to the human who authenticated the MCP connection.
   Use these start messages:
   - Path 1: `🤖 Starting work in the current session on branch \`<current-branch>\`.`
   - Path 2: `🤖 Starting work in a new worktree on branch \`linear/<slug>\`.`
   - Path 3: `🤖 Speccing this out with Spec Kit before implementation.`

   If the response does not include `author.id`, stop and report that the active agent identity
   could not be resolved rather than assigning the issue to a guessed user.

2. **Move to In Progress and assign it to the resolved agent.** Call `list_issue_statuses`
   for the issue's `team` to find the started-type state (usually named `In Progress`; teams
   customize names, so resolve it rather than assuming). Then call `save_issue` with `id` =
   the identifier, `state` = that state's name or id, and `assignee` = the comment author's
   captured user ID. Set the state and assignee in the same call.
3. **Verify the claim.** Re-fetch the issue with `get_issue` and confirm both that its status
   is the resolved started state and that `assigneeId` equals the captured comment-author ID.
   Treat a partial update as a failure: correct it or report the mismatch before claiming the
   issue is assigned or beginning path-specific work.

Then carry out the chosen path below.

### Build to the acceptance criteria

If the description carries an `## Acceptance criteria` section (linear-log authors these), that
is your definition of done — build to satisfy every item, and use it as the checklist for
moving to `<IN_REVIEW_STATE>`. Many tickets won't have one — hand-written ones especially — and
that's fine: infer the definition of done best-effort from the description, title, and the
conversation, and proceed; a missing section is never a blocker. For a bug with `## Steps to
reproduce`, reproduce it first (or verify your fix against those steps) so you fix the reported
thing, not an adjacent one; if the repro is missing, do your best from the description. When no
acceptance section exists and the work is more than trivial, it's worth jotting the criteria
you're building toward into the ticket as you go — linear-accept verifies against exactly this —
but that's a courtesy to the pipeline, not a gate on your work. Write them in linear-log's shape
and at its brevity bar: a handful of one-line observable outcomes, no padding.

### Right-size the response before you build

This applies to **Path 1 and Path 2**. Path 3 already plans through Spec Kit.

Before coding, classify the issue:

- **Trivial and clear**: one obvious edit, with a known acceptance bar.
- **Bounded with narrow questions**: a handful of edits, but one or two details affect
  correctness.
- **Complex or uncertain**: multiple files or layers, real design choices, unclear scope, or
  an unclear definition of done.

Default to autonomy. Escalate only as needed:

- **Trivial and clear → do it.** Implement, test, and commit.
- **Bounded with narrow questions → ask once, then run.** Ask all blocking questions
  together before creating a worktree or editing code, then implement, test, and commit.
- **Complex or uncertain → Plan Mode.** Investigate, outline files, sequence, and risks,
  get approval, then code. Use this only when a competent teammate would want the approach
  sketched before starting.

When Plan Mode changes the approach, add the worthwhile decisions back to the Linear issue
as a comment (see **Keeping Linear honest**).

### Path 1 — Work it here

Stay on the branch you're already on. Find it with `git branch --show-current` and work the
issue right here in this session.

**Do not create a new branch or a new worktree on this path unless the user explicitly asks
for one** — not `git checkout -b`, not `git switch -c`, not `wt switch`, not `EnterWorktree`.
"Work it here" means _here_: the current branch, as-is. Spinning up a fresh branch or worktree
is exactly what Path 2 exists for, and doing it silently defeats the reason the user chose this
path — a small fix, on the current branch, with no isolation wanted. If partway through the
work turns out to really want its own worktree, surface that and let the user decide; don't
switch on your own.

Nothing else special here beyond keeping Linear in sync (see **Keeping Linear honest**).

### Path 2 — New worktree

Derive a short, readable slug from the identifier + title: lowercase, hyphenate, strip
punctuation. `ABC-5 "Export button does nothing"` → `abc-5-export-button-does-nothing`.
(Linear's own `gitBranchName` uses a person prefix like `<username>/…`; we deliberately use a
`linear/` prefix instead so these branches are grouped by origin.)

Create the worktree and branch with worktrunk:

```
wt switch --create linear/<slug>
```

This creates the worktree at worktrunk's location and runs its `worktree:up` setup
(per-worktree `.env`/ports, build, DB reset+seed). If this is worktrunk's first run of this
project's hooks, it prompts for a **one-time approval** (`wt hook approvals` manages these) —
a skipped hook means an unprovisioned worktree, so approve and rerun the setup rather than
working around it. **`wt switch` runs in a subshell, so the
harness session's working directory does not follow it** — the next Bash call resets back to
the repo root. Point the session's tools at the worktree explicitly:

1. Get the worktree path from `git worktree list` (the row on branch `linear/<slug>`).
2. Call **`EnterWorktree`** with `path:` = that path (the worktree already exists — pass
   `path`, **not** `name`), then verify with `pwd` + `git branch --show-current` before
   editing any files.

Caveats (verified, so you don't chase them): the directory/branch **statusline chip** stays
on the directory Claude was _launched_ from — the harness cannot repaint it mid-session, and
`EnterWorktree(path)` only moves where your tools run, not the chip. Do **not** try to "fix"
the chip with `EnterWorktree(name=…)` — that spawns a _separate_, wrongly-named,
unprovisioned worktree under `.claude/worktrees/` (the chip won't follow that either). A
correct chip only comes from launching Claude _inside_ the worktree from the start (e.g.
`wt switch --create linear/<slug> -x claude`), which is out of scope here.

The Linear MCP connection is session-level, so it carries over unchanged. At merge time, use
**`wt merge`** (it builds the Conventional-Commit message and cleans up the worktree).

### Path 3 — Spec it out

Hand the issue to Spec Kit as the feature description. Invoke `/speckit-full-spec` with the
issue's title, description, and link woven in as the feature to spec.

(If this repo has no Spec Kit setup — no `.specify/` directory — plan-first still applies:
enter Plan Mode and produce an approved implementation plan covering affected files, sequence,
test strategy, risks, and how each acceptance criterion will be satisfied, then fold the
Linear-management tasks below into that plan instead of `tasks.md`.)

**Gather referenced assets first.** If the issue references a visual design or similar
artifact (a Figma or Claude Design URL, attached mockups), fetch it in this session — from
the ticket's own attachments if linear-log already vendored them, else via the design's native
tool (Figma, Claude Design, etc.) — so the spec can vendor it into
`specs/<feature>/design/` per the spec template. This session is the last point in the
pipeline with interactive access; an autonomous implementer cannot fetch it later, and a
ticket whose acceptance is "matches the design" must not enter Spec Kit without the design.

When the flow finishes generating `tasks.md`, **make sure Linear management is part of the
plan** — the implementation may happen later, out of this session, so the tasks themselves
must carry the responsibility of keeping the issue honest. Add (or confirm) tasks that:

- reference the issue by identifier (e.g. `<TEAM_KEY>-5`),
- keep it `In Progress` while implementation runs,
- post a comment at meaningful milestones,
- move it to `<IN_REVIEW_STATE>` once tests have passed and the work is committed to its
  working branch

## Keeping Linear honest

Across every path, the issue should always reflect where the work actually is — that's the
whole point of doing this through Linear rather than silently in a branch:

- **Start:** `In Progress` + a comment (done in Step 3).
- **Along the way:** drop a `save_comment` at genuine milestones (a blocker found, an
  approach decided, tests passing) — not noise, just the things a teammate would want to know.
  Keep each to a line or two: the fact and its consequence, not the investigation that got
  there. A long comment is a sign the milestone wasn't one.
  When a milestone is a **visually verified fix** — you reproduced a UI bug and want to show it's
  gone — a before/after screenshot says more than a paragraph. Embed it _inline_ in that comment
  (`![reload no longer flickers — after](assetUrl)`), not as an attachment, so a teammate scanning
  the ticket sees the proof without opening anything. Upload it the way linear-accept does:
  `prepare_attachment_upload` + PUT (both from the same Linear MCP server — deferred, load via
  `ToolSearch`) hand back a hosted `assetUrl`; drop that into the image tag and skip
  `create_attachment_from_upload`, which would file it in the rail you're keeping the eye out of.
  This is a courtesy when a screenshot genuinely helps — the fix is linear-fix's job; full acceptance
  evidence is linear-accept's.
- **In Review — the ceiling until merge:** whether this repo routes work through pull requests
  is a house rule pinned in `.claude/linear-workspace.md`. When it doesn't (the default —
  work lands by committing to the working branch and merging directly, e.g. `wt merge`), don't
  prompt to open a PR and don't wait on one. Once the tests have passed and the work is committed
  to its working branch, move the issue to `<IN_REVIEW_STATE>`. This is the **highest status the
  issue may reach while the work is unmerged.** Do not jump to `Done` just because the code is
  written and committed — merging into the default branch is a separate, later step.
- **Done — only after merge to the default branch + push to origin:** the issue moves to the
  team's completed state (resolve via `list_issue_statuses`; often `Done`) **only** after explicit
  go-ahead from the user, AND once the change is merged into the default branch (e.g. `main`) and
  pushed to origin. Leave a closing comment summarizing what changed and where.

Two acts always need the user's explicit go-ahead first, every time — never do them on your
own initiative: **pushing to origin** and **moving the issue to Done**. Both are outward-facing
and hard to walk back — a push publishes the branch and a Done tells the whole team the change
is live in the default branch. Committing locally and moving to `<IN_REVIEW_STATE>` stay autonomous.

Why the hard line: "Done" in Linear signals to everyone that the change is _live in the default
branch_. Marking it Done while the work still just sits on a branch, committed but unmerged, is a
lie the rest of the team acts on. When in doubt about a transition, prefer `<IN_REVIEW_STATE>` and ask.
