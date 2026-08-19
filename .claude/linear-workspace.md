# Linear workspace pin

Per-repo Linear configuration that the `linear-*` skills read. Every Linear skill
(`linear-log`, `linear-fix`, `linear-accept`, `linear-plan`, `linear-verify-loop`) treats
this file as the single source of truth for which workspace, team, project, states, and
labels it targets. The Linear MCP tools take **no workspace parameter** — these pins are a
**check**: the skills verify a fetched entity's `url` matches the pinned workspace before
any write, and stop rather than write to the wrong tracker (a `linear.app/dmatrix/…` url
means the session is carrying another repo's connector).

## Workspace

- **Workspace slug:** `agent-layer`
- **Workspace URL prefix:** `https://linear.app/agent-layer/`

## Team

- **Team name:** `agent-layer` — the workspace's only team.
- **Team key / issue-id prefix:** `AGL` — bare integers normalize to this team
  (`12` → `AGL-12`). Only `AGL-` ids are ours; confirm foreign prefixes with the user.

## Default project

- **Default project (new tickets):** `cbm adoption` — the codebase-memory-mcp fork-adoption
  initiative (AGL-5–AGL-8 plus its process tickets). Re-pin when the initiative wraps.

## Workflow states

- **In-review ceiling:** `In Review` — the highest status work may reach while unmerged.
- **Passed / agent-reviewed:** `Agent Reviewed` — where `linear-accept` lands a ticket whose
  acceptance criteria all verified (not `Done`; Done means live in `main`, a human call).
- **Needs-work / reopened:** `Re-Opened` — where failed acceptance lands, and where
  `linear-log` reopens a worked ticket when the definition of done moves.

## Merge workflow (house rule)

- **Routes through pull requests?** `no` — work lands by committing to the working branch
  and merging directly (e.g. `wt merge`). `In Review` is the ceiling until a human merges.

## Effort labels

Team-scoped labels estimating how much capability a ticket needs: `linear-log` tags a
recommendation, and `linear-fix` / `linear-plan` read it to right-size the model and
reasoning effort they bring. Resolve them with `list_issue_labels` **with the `team` param
set** — a bare, workspace-only call hides them.

Both axes are Linear **label groups**, so Linear itself enforces at most one value per
axis. A child comes back under its bare name with a `parent` field naming its group, and
`save_issue` takes that **bare child name** — never `Model: Simple`.

- **Model tier** — group `Model`: `Simple` (mechanical or well-bounded) / `Regular` (the
  default) / `Complex` (subtle, cross-cutting, or high blast radius).
- **Reasoning effort** — group `Thinking`: `Low Effort` (the approach is obvious) /
  `Med Effort` (the default) / `High Effort` (trade-offs, unknowns, or many interacting
  parts).
- **Spec-first flag** — `Spec Kit`, ungrouped: work large or cross-cutting enough to earn a
  full spec pass before implementation. `linear-fix` reads it as a strong signal for its
  spec path; `linear-plan` keeps a flagged ticket out of a shared tranche.

**Graceful fallback.** If a pinned state or label doesn't resolve at runtime, the skills
degrade rather than error: acceptance verdicts land as comments without a state move, and
effort rollups are skipped rather than invented.
