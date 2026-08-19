# Linear acceptance verification loop

Invoke the `linear-verify-loop` skill and follow it — it is the single source
of truth for this loop's workflow.

Paths to pass to the skill (and to any sub-agent it spawns):

- **Run plan (ground truth)**: `{{GROUND_TRUTH_PATH}}` — the linear-specs/
  plan that drove the main run; its Tickets section lists the target tickets
  and their acceptance-criteria snapshots.
- **Ticket ledger**: `{{REPORT_PATH}}` — your working document; checkbox
  state drives loop completion.

Linear workspace: every target ticket lives in this repo's configured Linear
workspace (see `.claude/linear-workspace.md` for the pinned workspace slug,
team, and ticket prefix). The Linear MCP tools take no workspace parameter, so
any sub-agent must confirm a fetched issue's url starts with the configured
`https://linear.app/<workspace-slug>/` before writing, and must report a
mismatch rather than write to another workspace.

The skill picks one mode per loop from the ledger state — VERIFY (acceptance-
test a group of tickets via the `linear-accept` skill), REWORK (fix
tickets in `<REOPENED_STATE>`), or GATE-FIX (repair a red final gate) — and delegates the actual
work to a sub-agent via the Task tool. In the sub-agent, not inline in this
orchestrator turn, so its context stays out of yours.

Do not signal COMPLETE directly — loop completion keys on the ledger's
checkbox state, which only the workflow may advance, and the loop's
completion guard additionally requires a fresh green final-tier gate. A green
gate alone will be rejected.
