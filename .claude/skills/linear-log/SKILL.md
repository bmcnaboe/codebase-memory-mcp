---
name: linear-log
description: Author a Linear ticket — create a new one or edit an existing one's fields — via the connected Linear MCP server. This is about the ticket *record* (title, description, priority, labels, assignee, project, state, estimate, due date, parent), not doing the engineering work it describes. Trigger whenever the user wants to file, open, create, log, or capture a new issue/bug/task in Linear, OR to edit, update, rename, re-prioritize, re-label, reassign, or move an existing ticket named by a LETTERS-NUMBER id (ABC-5, PROD-203) or a bare integer ("update 120's description"), shorthand for the default team pinned in `.claude/linear-workspace.md`. An id means modify that ticket; no id means create one. So "file a bug: the export button does nothing", "open a ticket to add CSV export", "log this conversation as a Linear issue", "update ABC-5's description", "bump ABC-5 to high priority", "rename PROD-203", and "reassign ABC-5 to me" all qualify. A well-formed ticket captures structured **acceptance criteria** (and, for a bug, steps to reproduce — optionally reproduced with evidence attached) so it feeds cleanly into linear-fix and linear-accept; a ticket referencing a visual design (Claude Design, Figma, a mockup) gets the design vendored in as attachments at creation time, not just linked. Defaults: the pinned project; new tickets land in Backlog. Runs on /linear-log. Don't trigger when the user wants to actually implement or fix the underlying work, or to move status as part of doing that work — that's linear-fix.
argument-hint: "[ticket-id]"
---

# Linear Log

Capture or edit a Linear ticket cleanly. The job is to turn a request — a bug someone
just hit, a feature idea, "tweak the priority on ABC-5" — into a well-formed Linear issue,
using good judgment to fill the fields and only asking the user for what you genuinely can't
infer. The ticket is a shared record the rest of the team reads, and _well-formed_ here means
**short**: a title that scans in one glance and a body carrying only what the next person
can't infer. Terse tickets get acted on; padded ones get skimmed.

This is the authoring counterpart to **linear-fix**: linear-fix _does the work_ an issue
describes (writes code, syncs status); linear-log _writes and edits the issue itself_. If the
user actually wants to start fixing/implementing, hand off to linear-fix instead.

## Tools you'll need

The Linear tools come from the connected Linear MCP server and are usually **deferred**.
Load them with `ToolSearch` before first use — search the keyword `linear`, or select by
capability. **Do not hardcode the server's hash prefix** (it looks like
`mcp__<uuid>__save_issue` and the uuid varies per session/machine). You need:

- `save_issue` — the one seam for both create and update. Pass `id` (the identifier, e.g.
  `ABC-5`) to **update**; omit `id` to **create**. On create, `title` and `team` are
  required. Fields: `title`, `description` (Markdown — use literal newlines, don't escape),
  `priority` (0=None, 1=Urgent, 2=High, 3=Medium, 4=Low), `project`, `state`, `labels`
  (array of names), `assignee` (id/name/email/`"me"`), `estimate`, `dueDate`, `parentId`.
- `get_issue` — load an existing issue before modifying it (and to render the result).
- `list_teams` — resolve which team a new issue belongs to.
- `list_projects` — resolve the project (the pinned default `<DEFAULT_PROJECT>`) to confirm it exists.
- `list_issue_statuses` — resolve the team's real state names (the default landing state for
  new tickets is the **Backlog**-type state).
- `list_issue_labels` — resolve label names before setting them (don't invent labels). If your
  workspace defines an **effort-label roster** (see the pin file), those labels are
  **team-scoped, not workspace-wide** — a bare call returns only the workspace labels
  (`Bug` / `Feature` / `Improvement`) and hides them. **Always pass `team` (the pinned
  `<TEAM_NAME>`)** to see the effort labels. A label that lives in a **group** comes back
  under its own bare name plus a `parent` field naming the group; pass the **bare child
  name** — `save_issue` has no `Group: Child` form.
- `list_users` — resolve an assignee when the user names a person.
- `save_comment` (`issueId` + `body`) — to add a comment; also the **default channel for
  changing a ticket that's already been worked**, where a comment preserves history that a
  description rewrite would erase (Step 2).

For attaching files — the optional **bug-repro capture** (Step 4) and **vendored design
assets** (Step 2) — you'll also reach for:

- `prepare_attachment_upload` + `create_attachment_from_upload` — attach repro evidence
  (screenshots, transcripts, logs) to the ticket.
- The product surfaces — the repo's login mechanism + Playwright for UI bugs, and Bash/`curl`
  (or the project's MCP server / product API) for API/agent bugs. Playwright's tools are usually
  **deferred** too; load them via `ToolSearch` (keyword `browser`).

## Workspace — read the pin

Every ticket this skill authors or edits lives in the workspace, team, and ticket prefix pinned
in **`.claude/linear-workspace.md`** — read it for the values (this doc refers to them as the
workspace slug, `<TEAM_NAME>`, and `<TEAM_KEY>`). The account may have more than one workspace,
and nothing here may touch another one.

The Linear MCP tools take **no workspace parameter** — the connected server resolves whichever
workspace its token is bound to. So the pin is a _check_, not an argument:

- **Verify before the first write.** Every entity Linear returns carries a `url`; it must start
  with the pinned `https://linear.app/<workspace-slug>/` (equivalently, `list_teams` returns
  `<TEAM_NAME>`). If the connector resolves anywhere else, **stop and tell the user** — filing a
  ticket into the wrong workspace is worse than not filing it, because nobody on this project
  will see it.
- **Always pass `team: "<TEAM_NAME>"`** on calls that accept it — `save_issue`,
  `list_issues`, `list_projects`, `list_issue_labels`, `list_users` (and
  `list_issue_statuses`, which requires it) — so a re-scoped connector can't drift silently.
- **Only `<TEAM_KEY>-` ids are ours.** Bare integers are always the pinned team
  (`120` → `<TEAM_KEY>-120`). A foreign prefix (`PROD-203`, `LIN-412`) presumably lives in the
  other workspace — confirm with the user before editing it rather than assuming it's a typo.

## Step 1 — Create or modify?

Decide from the request:

- **A ticket id is present** (passed as the argument, or named in the message like "update
  ABC-5") → this is a **modify** request against that ticket. A bare integer clearly used as
  a ticket reference (`/linear-log 120`, "update 120's priority") counts too — it's shorthand
  for the default team; normalize it to `<TEAM_KEY>-120` before any Linear call. A number
  that's just part of the content ("add 120 rows") is not an id.
- **No ticket id** → this is a **create** request for a new ticket.

If a single message asks to create _and_ references an id ambiguously, prefer the user's
explicit verb ("file a new one" vs "change it") and ask only if it's truly unclear.

## Step 2 — Assemble the ticket fields

Use judgment first, questions second. Read the request and the surrounding conversation and
fill in everything you reasonably can — a bug discussed at length above already gives you a
title, a description, repro steps, probably a priority. **Don't interrogate the user field by
field.** Draft the ticket from what you have, then ask only about the things that genuinely
change the outcome and that you can't infer.

### Write short — the house bar

Everything you write here is read by every teammate who touches the ticket and re-read by
linear-fix and linear-accept. Hold to these bars unless the user asks for more:

- **Title: aim for 50 characters, hard-cap around 70.** Name the thing, not the story around
  it. No `Bug:` / `Feature:` prefix (the label says that), no area the project already
  implies, no articles or hedges, no trailing period. `Export button does nothing after save`
  — not `Bug: clicking the export button on the reports page does not do anything once a
record has been saved`.
- **Description: 10 lines is a full ticket** — and when the title already says it, no
  description at all. One to three sentences of context, then the structured sections —
  nothing else. No restating the title, no recap of the conversation, no `Background` or
  `Notes` heading holding one sentence, no section you'd have to pad to fill.
- **Bullets over prose, one line each.** Cut a clause before you wrap a line.
- **Link, don't transcribe.** A URL, a path (`apps/web/…:42`), a commit sha, or a ticket id
  carries more than a paragraph reconstructing it.

The same bar governs **edits and comments**: an edit that grows the body without adding a
fact is a regression, so trim what you touch. Verbosity is not thoroughness — if you can't
decide whether a line earns its place, it doesn't.

How to set each field:

- **Title** — a specific noun phrase or imperative at the length bar above; the gist and
  nothing else.
- **Description** — Markdown. One to three sentences of context (what happens or what's
  wanted, plus links from the conversation), then the structured **Acceptance criteria** —
  and, for a bug, **Steps to reproduce** — described in _The definition of done_ below. Lift
  the facts from the conversation rather than making the user retype them — the facts, not
  the transcript.
- **Priority** — infer from how the user talks about it ("blocking", "urgent", "nice to
  have") and map to 0–4. Default to `None` (0) when there's no signal; don't guess Urgent.
- **Labels** — set from `list_issue_labels`; match existing labels, never invent. Skip if
  nothing fits. Two kinds can coexist: the **type** label (`Bug` / `Feature` / `Improvement`,
  matching the request) and, when your workspace defines them, the **effort labels** —
  try to set a recommended effort estimate; see _Effort labels_ below.
- **Assignee** — only if the user indicates one ("assign to me", a name). Otherwise leave
  unassigned. `"me"` is valid.
- **Project** — default to the pinned **`<DEFAULT_PROJECT>`** unless the user names another.
  Confirm it exists via `list_projects`.
- **State** — for new tickets, default to the team's **Backlog** state (resolve via
  `list_issue_statuses`; passing the name `Backlog` usually works). For modifies, only touch
  state if asked — the exception is recording rework on an already-worked ticket, where
  reopening it is part of the flow (see below).
- **Team** — required to create. Default to the pinned **`<TEAM_NAME>`** (see _Workspace_
  above) — don't auto-pick whatever single team `list_teams` happens to return, which silently
  follows a re-scoped connector into the wrong workspace. Use another team only if the user
  names one or the chosen project pins one.

For a **modify**, first `get_issue` to load the current values, show the user the standard
summary (below) of what's there now, then apply only the requested changes — pass `id` plus
just the fields that change. Removing a value (e.g. unassign) uses `null` where the field
allows it (`assignee`, `estimate`, `parentId`, etc.). But before you rewrite anything, weigh
_how_ to record the change — on a ticket that's already been worked, an in-place edit of the
body is usually the wrong move.

### Effort labels — estimate the horsepower a ticket needs (optional)

**Only if `.claude/linear-workspace.md` defines an effort-label roster.** If it doesn't (the
roster is optional), skip this section entirely — set just the type label and move on.

Beyond the type label, set the **effort labels** that estimate how much capability the work
will take. They're a recommendation for whoever — or whatever — picks the ticket up next:
linear-fix reads them to right-size the model and reasoning it brings, so a good estimate here
keeps the pipeline from over- or under-powering the work. It's a best-effort call from your
read of the ticket, not a contract, and trivially revised later. Resolve the exact names via
`list_issue_labels` **with the `team` param set** (they live on the pinned team and are hidden
from a bare, workspace-only call). The pin file's roster typically has two independent axes plus
one flag — for example:

- **A model-tier axis** — a label group (e.g. `Model`) running low → high (e.g. `Simple` / `Regular` / `Complex`) — which model tier the work warrants.
  - _Simple_ — trivial, mechanical, fully specified: a copy tweak, a config bump, an obvious one-line fix.
  - _Regular_ — ordinary bounded feature/bug work with a clear-enough path. The common case.
  - _Complex_ — hard reasoning, real design choices, subtle correctness, or wide blast radius —
    including work that spans several areas or layers, or needs delicate handling (a migration,
    an auth path, a cross-cutting refactor), where a wrong move is expensive to unwind.
- **A reasoning-effort axis** — a label group (e.g. `Thinking`) running low → high (e.g. `Low Effort` / `Med Effort` / `High Effort`) — how much reasoning effort the work needs.
  - _Low_ — the path is obvious; little deliberation.
  - _Med_ — some tradeoffs or investigation before the approach is clear.
  - _High_ — many interacting constraints, tricky edge cases, or an unclear definition of done.
- **A spec-first flag** (e.g. `Spec Kit`) — a standalone, ungrouped flag, not a level. Add it
  when the ticket is **large or ambiguous enough that implementation should follow a written
  spec rather than precede one**. `linear-fix` reads it as a strong signal for its spec path
  and `linear-plan` keeps a flagged ticket out of a shared tranche, so set it only when you'd
  genuinely want spec/plan/tasks before any code.

Pick each axis on its own merits. They usually track together — a top-tier ticket is typically
high thinking too — but not always: a task can want deep thinking on a middling model, or a
strong model for a shallow-but-fiddly change. Each axis being a label group means Linear allows
at most one value per axis, so set exactly one; add the flag only when it earns it, and when the
request is too thin to judge confidently, lean to the middle rather than guessing high. Set these
when **creating** a ticket; on a modify, only revisit them if the change genuinely shifts the
scope or effort.

Because `save_issue`'s `labels` param **replaces the whole set**, pass the type label and all
the effort labels together in one array — otherwise you'll drop the ones you didn't list.

### Modifying a ticket that's already been worked — comment, don't overwrite

A modify isn't always a blank-slate edit. Once a ticket has been picked up it carries a
**historical record**: the original description is what was asked, attached acceptance-test
plans and screenshots are the evidence of what was delivered, and the comment thread is the
account of decisions along the way — often the exact input the fix/accept pipeline already ran
against. Rewriting the description or title in place quietly destroys that: the original ask is
gone, and the attached evidence now describes a ticket that no longer exists.

So when a ticket shows signs of having been worked — status past the backlog (In Progress /
`<IN_REVIEW_STATE>` / `<REVIEWED_STATE>` / Done / `<REOPENED_STATE>`), attached plans or
screenshots, a real comment thread, an agent assignee or a branch with commits — **default to
additive changes that keep the history intact**:

- Record the new understanding, scope change, or course-correction as a **`save_comment`**,
  self-contained enough that linear-fix and linear-accept can read the current direction
  straight from it — restate the revised acceptance criteria in the comment rather than
  assuming the reader diffs an edited description. Self-contained, not long: what changed and
  the revised criteria, never a recap of the thread the reader is already in.
- Add _new_ assets (an updated plan, a fresh screenshot) instead of replacing the old ones.
- If the change genuinely reopens the work — it moves what "done" means or corrects the
  delivered approach — move **status** to the reopened state (`<REOPENED_STATE>`, resolved via
  `list_issue_statuses`) so the board matches reality. The body stays as the record of the
  original ask; a comment that only adds context leaves status alone.

This guards the **narrative** — description, title, acceptance criteria. It doesn't restrict
**metadata**: re-prioritizing, relabeling, reassigning, or moving a worked ticket is a normal
direct `save_issue` edit that harms no history — apply those straight, as always.

Two exceptions where you still edit the body in place: the ticket is **fresh** (backlog/triage,
nothing worked yet, no evidence to protect), or the user **explicitly asks to edit the record**
("fix the typo in the description", "rename it") — an explicit instruction wins, though on a
heavily-evidenced ticket add a one-line heads-up that the edit overwrites the original text. If
you can't tell whether a change is a harmless metadata tweak or a history-altering rewrite,
treat it as rework and reach for the comment.

### The definition of done — acceptance criteria (and repro steps for bugs)

These three skills are a workflow: **linear-log** writes the acceptance criteria, **linear-fix**
builds to satisfy them, **linear-accept** verifies them. So the criteria captured here are the
contract the whole pipeline runs on — worth getting right. Put them in the description as a
stable, structured section the other skills can read straight back:

```
## Acceptance criteria
- [ ] <observable, checkable condition that means "done", from the user's perspective>
- [ ] …
```

Write them as **observable outcomes, not implementation tasks**: "the list updates
without a manual reload when an item is created in another session", not "add an SSE handler".
That's what a fixer builds toward and what accept can actually test. **Two to five criteria,
one line each** — a criterion needing a paragraph is either two criteria or a bad one, and a
list running past five usually means the ticket should be split. Draft from what you already
know; ask a focused question only when a criterion genuinely can't be inferred.

This is best-effort, not a required schema. When the request is sparse — a one-line bug, a quick
idea jotted down — capture what you honestly can: one clear criterion, or even none when you
truly can't infer one, beats padding the ticket with guesses. When you're **modifying** a ticket
someone hand-wrote in their own shape, respect it — sharpen or add criteria where it clearly
helps, but don't restructure their prose into this template just to match. linear-fix and
linear-accept read these sections when present and degrade gracefully when they're not, so a
lighter ticket still flows cleanly through the pipeline.

**For a bug, also capture steps to reproduce** — they double as the fixer's reproduction and
accept's regression check (the bug must no longer repro):

```
## Steps to reproduce
1. …
2. …

**Expected:** …
**Actual:** …
```

### Design references — vendor the asset, not just the URL

When the ticket captures UI work against a referenced design (a Figma or Claude Design
URL, a mockup), vendor the design into the ticket at creation time: capture the referenced
screens as files — rendered screenshots and/or the prototype source, via the design's native
tool (Figma, Claude Design, etc.) — attach them (recipe in Step 4), and write the
acceptance criterion against the attachments ("renders per the attached design"), keeping
the URL in the description as provenance. A URL alone is not vendoring — it sits behind
auth and can drift, and downstream phases (spec authoring, autonomous implementation,
acceptance) may not be able to open it; the ticket alone should carry the visual source of
truth. If you can't fetch the design from this session, say so on the ticket rather than
silently leaving just the link.

### Capturing the right level of detail

A ticket too thin to act on wastes the next person's time; a 20-question intake wastes the
user's, and a padded ticket wastes every reader's. The bar is _enough that someone could pick
it up cold_ — and then stop. When a line is borderline, cut it. If the request is rich
(a bug you just diagnosed together), you may already have everything — assemble it and create
it (Step 3). If it's a one-liner with real ambiguity ("log a ticket about the export thing"),
ask a couple of focused questions — what's broken or wanted, how urgent, which area — bundled
together, then create. Prefer resolving ambiguity by drafting a concrete ticket over running
an open interview; reacting to something specific is faster for the user than a field-by-field
intake — and once it exists they react to the real ticket, not a preview.

## Step 3 — Write, then share

Once the fields are assembled and any genuinely blocking gap is resolved, just **create the
ticket** — don't stage a preview and wait for a go-ahead first. The user's "log / file /
create a ticket" request is itself the authorization to write, and a Linear ticket is cheap
to make and trivially edited or archived afterward, so a pre-write confirmation step almost
always ends in "yes" and mostly just adds a round-trip. It's faster and more natural for the
user to react to the **real, rendered ticket** — with its identifier and URL — than to a
draft. Bias to action here.

Call `save_issue` (with `id` for a modify, without for a create), then show the result
(Step 5) and invite edits in the same breath: if anything's off, applying the change is a
one-line `save_issue` against the id you just got back. For a modify, likewise apply the
change and show the before→after rather than previewing it and waiting for approval.

"Create first" is not "create blind." When you'd otherwise have to guess at something that
changes what the ticket fundamentally _is_ — which of two unrelated bugs they mean, a
required field you truly can't infer (the team on a create) — resolve that one thing first;
a single focused question is fine. But when you're confident enough to draft the ticket,
you're confident enough to create it.

## Step 4 — Bugs: offer to reproduce and capture evidence

**Bugs only**, and only when the ticket describes something reproducible here (a webapp
behavior, an API/agent response). A confirmed repro with evidence is what makes the
log→fix→accept handoff strong: it proves the bug is real, gives the fixer a head start, and
hands accept a "before" baseline to check the fix against.

Once the ticket is written, ask the user a single yes/no via `AskUserQuestion` —
**"Reproduce this now and attach the evidence to the ticket?"** Don't assume: reproducing boots
the app and drives real surfaces, which the user may not want at file time.

- **No** → leave the written repro steps as they are and finish; the fixer can still work from them.
- **Yes** → reproduce through the surface the bug lives on, capturing as you go:
  - **UI bug** → boot + sign in via the repo's login mechanism, drive with Playwright, and
    screenshot the broken state (`browser_take_screenshot`).
  - **API / agent bug** → drive it with `curl` / the project's MCP server or product API; save
    the request/response transcript and any relevant server-log lines.

  Then attach the evidence (recipe below) and record the outcome honestly with `save_comment`:
  **Reproduced** (bug confirmed — reference the evidence) or **Could not reproduce** (say what
  you tried — the ticket may need more detail, or the bug may be environment-specific). A failed
  repro is useful signal, not a dead end.

### Attaching a file

One file at a time — each signed URL expires in ~60s:

1. `prepare_attachment_upload` with `{ issue, filename, contentType, size }` (`size` = exact
   bytes, `wc -c <file>`). It returns `uploadRequest.url` + `uploadRequest.headers` and an
   `assetUrl`.
2. PUT the raw bytes with **every** header from `uploadRequest.headers` verbatim (casing
   matters; a missing/edited header → 403):
   `curl -X PUT --data-binary @<file> -H '<header>' … "<uploadRequest.url>"`.
3. `create_attachment_from_upload` with `{ issue, assetUrl, title }`.

Delete the local temp file once it's attached.

## Step 5 — Show the result

After the write, render the saved issue in the **house style** linear-fix uses, so the two
skills' output reads the same — fetch it back with `get_issue` if you need the url/fields:

```
**[{IDENTIFIER}: {title}]({url})**

- **Status:** {status} · **Priority:** {priority.name} · **Label:** {labels}
- **Team:** {team} · **Project:** {project}
- **Branch:** `{gitBranchName}`
- **Created:** {createdAt:YYYY-MM-DD} by {createdBy}

**Description:** {description}
```

Field notes:

- **Label** — join multiple with `, `; if none, drop the ` · **Label:** …` segment.
- **Project** — if absent, show `—`.
- **Created** — date only; `createdBy` as returned.
- **Priority** — use `priority.name` (e.g. `Medium`, `None`).

For a create, lead with a short confirmation line ("Created **ABC-42**.") above the block. For
a modify, note what changed ("Bumped priority to High; added label `frontend`.") so the
edit is legible at a glance.
