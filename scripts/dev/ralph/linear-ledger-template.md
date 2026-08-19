# Ticket Ledger

- [ ] All target tickets terminal (`<REVIEWED_STATE>` or FAILED)

**Status:** UNVERIFIED
**Ground truth:** {{GROUND_TRUTH_PATH}}
**Final gate:** _(orchestrator records the last fresh `final`-tier run here: commit SHA it covered + green/red)_
**Last loop:** _(filled by orchestrator)_
**Last mode:** _(filled by orchestrator)_

## Tickets

_Initialized by the orchestrator on the first loop — one row per target
ticket from the run plan's Tickets section, exactly this shape:_

_`- [ ] <TEAM>-N — <title> · status: <Linear status> · reworks: 0/2`_

_A row is checked `[x]` only when terminal: status `<REVIEWED_STATE>`, or
`FAILED (capped)` after a re-open with no rework budget left, or
`UNSURE (needs human)` after two unresolvable unsure verdicts. No other
checkboxes may be added anywhere in this file — the loop counts every
`- [ ]` line as unfinished work._

## Findings

_Verify sub-agents append short per-ticket findings here as plain bullets
(`<TEAM>-N: ✅ …` / `<TEAM>-N: ❌ …` — never checkbox syntax). Pointers only; the
rich evidence (plans, screenshots, transcripts) lives on the Linear tickets._

## History

_Append-only. One line per loop: `loop N - MODE(tickets) - summary`._
