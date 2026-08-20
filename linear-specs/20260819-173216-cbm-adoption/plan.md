# Linear run — cbm-adoption

**Tickets:** AGL-5, AGL-6, AGL-7, AGL-8, AGL-9, AGL-10, AGL-11 · **Created:** 2026-08-19
**Branch:** linear/cbm-adoption
**Recommended:** model/effort defaults (spec-flagged batch) · RALPH_EVAL_MAX_LOOPS=22
**Verify groups:** A: AGL-9 · B: AGL-5, AGL-7 · C: AGL-6 · D: AGL-8 · E: AGL-10 · F: AGL-11 ← tranche-aligned; the verify loop uses these to batch linear-accept runs.

This repo is the fork of DeusData/codebase-memory-mcp: remote `origin` =
bmcnaboe/codebase-memory-mcp (ours), remote `upstream` = DeusData/codebase-memory-mcp
(theirs). The initiative's master plan is the Linear project **cbm adoption**
(https://linear.app/agent-layer/project/cbm-adoption-2b1172f86024).

## Execution

You are executing a batched Linear-ticket run inside the Ralph loop. Work every
remaining unchecked task in order, in a single continuous turn. Commit, read the
next task, keep going — the loop handles rotation; you handle the work.

The framing above owns the stop conditions, the after-every-commit breadcrumb
checks, the handoff contract, and the gate runner — follow it; none of that is
restated here.

Per task:

1. Read only what the task references (the Tickets section below carries each
   ticket's acceptance criteria; AGL-5/6/7 carry rich implementation notes on the
   live ticket — read those before building). Implement the minimum change that
   satisfies it.
2. Run the basic gate. Mark `[x]` only after it exits 0 — never around a red gate.
3. `git add <exact paths> && git commit -s --no-verify -m "<type>(<scope>): <desc> (AGL-N T###)"`.
   `--no-verify` is deliberate and mandatory inside this run: the repo's
   pre-commit hook re-runs lint + the security audit + the full test suite on
   every commit (~15 min each). That bar is not lowered — it is owned by the
   gate tiers instead (basic per task, full at every tranche close, final where
   a task says so) plus upstream CI on every PR. Never use `--no-verify`
   outside this run's worktree.
   The `-s` is mandatory: this repo enforces the DCO — every commit needs a
   `Signed-off-by` trailer matching the author (Brian McNaboe
   <bmcnaboe@gmail.com>). That trailer is required and is not an agent footer;
   agent footers (Co-Authored-By etc.) remain forbidden. No `--amend`. Then the
   framing's after-commit checks decide: yield or read the next task.

Tranche-close tasks (marked `[risky]`) additionally: the full gate must be green
(the final gate where the task says so), then sync Linear for that tranche's
tickets as the task describes.

Fork-specific rules:

- The first basic gate compiles ~1.2 GB of vendored grammar sources — long is
  normal, not a hang. Later builds are incremental.
- Verification cadence: commits are cheap (`--no-verify`, see above); the
  expensive checks run only where they decide something — the full gate at each
  tranche close, the final gate at T023, upstream CI on the PR branches. Do not
  re-run full/final gates per task.
- Upstream conduct: all GitHub posts go through `gh` under the user's account
  (approved). PRs are always opened `--draft` and never marked ready by the loop.
  Never push to the `upstream` remote, never edit upstream repo settings, never
  force-push `origin/main`. If `gh` is unauthenticated, log to `.ralph/errors.log`
  and continue local work.
- `install.sh` may only ever be executed against a sandbox `$HOME` — never this
  machine's real client configs. The binary's own `codebase-memory-mcp install`
  is run for real exactly once, in T029, as written there.
- Upstream CONTRIBUTING.md applies to everything that will be published: C only,
  one issue per PR, <500 lines per PR, conventional commits, tests included. A new
  `system()`/`popen()`/`fork()`/network call needs a justified entry in
  `scripts/security-allowlist.txt`.

Linear protocol: the Linear MCP tools are usually deferred — load them via
ToolSearch (keyword `linear`) on first use. Every ticket here is in the workspace
pinned in `.claude/linear-workspace.md` (workspace slug `agent-layer`, team
`agent-layer`); the tools take no workspace parameter, so before the first write
confirm a fetched issue's url starts with `https://linear.app/agent-layer/`, and
pass `team: "agent-layer"` on calls that accept it. A connector scoped to another
workspace is not a best-effort failure: skip Linear writes entirely and log it,
rather than writing to the wrong tracker. Otherwise Linear writes are
best-effort: if a Linear call fails, log it to `.ralph/errors.log` and keep
building — never block code work on the tracker. Catch up missed syncs at the
next tranche boundary.
Status ceiling during this loop is `In Review`; never touch `Agent Reviewed` or
`Done`.

When every task is `[x]` and the full gate is green, emit
`<promise>ALL_TASKS_DONE</promise>`. Genuinely stuck after honest investigation:
emit `<ralph>GUTTER</ralph>` with the root cause.

## Tasks

### Tranche A — Upstream engagement (AGL-9)

No code changes here; the T007 full gate also establishes the pristine baseline
before any code tranche.

- [x] T001 [AGL-9] Claim tranche: move AGL-9 to In Progress, assignee me, one-line start comment (Linear MCP unavailable this session — logged to .ralph/errors.log, skipped per best-effort policy)
- [x] T002 [AGL-9] Recheck upstream #1335, #1410, and the issue tracker for movement (assignment, new maintainer comments, duplicate filings); adjust the tasks below rather than duplicating anything — record findings in a comment on AGL-9 (both still OPEN/unassigned, no duplicates found; findings logged to .ralph/errors.log — Linear comment skipped, unavailable)
- [x] T003 [AGL-9] File the upstream issue for AGL-7 (hook-augment emits 0 bytes when payload cwd is a linked worktree): repro, expected/actual, and the 2×2 measurement from AGL-7; note it is distinct from #1335; record the URL on AGL-7 — filed https://github.com/DeusData/codebase-memory-mcp/issues/1752 (Linear record skipped, unavailable)
- [x] T004 [AGL-9] File the upstream issue for AGL-8 (install.sh silently drops `--clients`): repro from AGL-8; note the binary's own installer honors the flag; record the URL on AGL-8 — filed https://github.com/DeusData/codebase-memory-mcp/issues/1753 (Linear record skipped, unavailable)
- [x] T005 [AGL-9] Comment the root cause on #1335 per AGL-5's implementation notes (per-start SHA-256 of the ~295 MB executable; upstream's own `CBM_TEST_BUILD_FINGERPRINT` seam concedes it; measurements; explains the warm-daemon knife-edge; fingerprint-cache proposal; PR incoming); record the URL on AGL-5 — posted https://github.com/DeusData/codebase-memory-mcp/issues/1335#issuecomment-5350460267 (Linear record skipped, unavailable)
- [x] T006 [AGL-9] Comment the proposed approach on #1410 per AGL-6's implementation notes (generalize the embedded-import seam to the full walker set via `ts_parser_set_included_ranges`, `lang="ts"` sniff, Svelte near-free); request design feedback per CONTRIBUTING; note we carry a fork patch meanwhile; record the URL on AGL-6 — posted https://github.com/DeusData/codebase-memory-mcp/issues/1410#issuecomment-5350461744 (Linear record skipped, unavailable)
- [x] T007 [risky] Close tranche A: full gate green; move AGL-9 to In Review with a summary comment listing every URL posted — full gate green (exit 0, 1606s cold; ccache installed so the tier fits its wall-clock budget); AGL-9 → In Review with the four-URL summary comment

### Tranche B — hook-augment: deadline + worktree (AGL-5, AGL-7)

- [x] T008 [AGL-5, AGL-7] Claim tranche: move AGL-5 and AGL-7 to In Progress, assignee me, one-line start comment each
- [x] T009 [AGL-5] Fingerprint cache keyed (path, inode, mtime, size) at `runtime_process_image_reference_acquire` (src/daemon/runtime.c), covering both the self-fingerprint and the per-peer rendezvous checks; unit tests for hit/miss/key-roll — cache keyed (dev,inode,size,mtime,ctime) wraps cbm_daemon_build_fingerprint_native_file at the acquire site (all platforms); test seam + daemon_runtime_fingerprint_cache_hit_miss_key_roll asserts the hash is skipped on a hit
- [x] T010 [AGL-5] Apple hardware hash: `#ifdef __APPLE__` → CommonCrypto `CC_SHA256` in src/foundation/sha256.c; test asserts bit-identical output vs the scalar path — streaming ctx backed by CC_SHA256_Init/Update/Final on Apple (opaque aligned storage in the ctx, scalar path kept under test seams); cli_sha256_platform_path_matches_scalar compares both across sizes + chunked updates
- [x] T011 [AGL-5] Deadline-miss observability in hook-augment: a missed deadline writes the timeouts log and a stderr line — never silent 0 bytes / exit 0; `CBM_HOOK_DEADLINE_MS` override still honored; document `daemon start` in `--help` — handler now write()s the pre-formatted breadcrumb to both the log and stderr (breadcrumb formatted unconditionally so stderr fires even if the log can't open); `daemon <start|stop|status>` added to print_help; cli_hook_augment_deadline_breadcrumb_issue858 asserts both surfaces
- [x] T012 [AGL-7] Worktree resolution in the hook path: resolve the payload `cwd` through the same logic `index_status` already uses (`is_worktree`, `git_common_dir`, `canonical_root`) so an indexed linked worktree returns its own project context; unindexed worktree → logged skip/fallback; main-checkout behavior unchanged — FINDING: the v0.10.5 silent-worktree bug is already fixed in the fork's newer upstream base. Verified end-to-end with a warm daemon (sandbox): indexed linked worktree → its own project (AC1), unindexed worktree → deliberate "no project matched, run index_repository" not silent (AC2), main unchanged (AC3). The hook resolves by path-derived name/root_path (git-agnostic), so no production change is needed/warranted. Added cli_hook_worktree_cwd_resolves_own_indexed_project (real linked worktree) to pin the payload-cwd→project invariant against regression
- [x] T013 [AGL-5, AGL-7] Integration tests for hook-augment covering the payload-cwd matrix (main checkout / indexed worktree / unindexed worktree) and the deadline + logging contract — matrix covered across cli_hook_worktree_cwd_resolves_own_indexed_project (main + indexed linked worktree + worktree subdir, T012), cli_hook_unindexed_worktree_reports_no_match_not_silent (unindexed worktree → deliberate notice + main still resolves, this task), and cli_hook_augment_deadline_breadcrumb_issue858 (deadline miss → timeouts log + stderr, T011)
- [x] T014 [risky] Close tranche B: full gate green; move AGL-5 and AGL-7 to In Review, each with a comment summarizing commits + surfaces touched — full gate green (exit 0, 1125s warm); AGL-5 + AGL-7 → In Review with commit/surface summary comments

### Tranche C — Vue `<script setup>` indexing, spec-first (AGL-6)

- [x] T015 [AGL-6] Claim: move AGL-6 to In Progress, assignee me, start comment
- [x] T016 [AGL-6] Spec first (Spec Kit ticket): write `linear-specs/20260819-173216-cbm-adoption/agl-6-design.md` — walker-set generalization, `ts_parser_set_included_ranges` file-coordinate parsing, `lang="ts"` sniffing, Svelte parity, test plan, out-of-scope (template→handler edges); post a summary comment on AGL-6 — design note written (grounded in the parse_embedded_imports seam + the pp_ctx sub-context precedent); AGL-6 summary comment posted
- [x] T017 [AGL-6] Generalize the embedded-script seam in internal/cbm/extract_imports.c from imports-only to the full walker set (defs, calls, …), parsing with included ranges over the original source, per the design note — `parse_embedded_imports` → `parse_embedded_scripts`: runs cbm_extract_definitions + cbm_extract_imports + cbm_extract_unified over each `<script>` via ts_parser_set_included_ranges (file coordinates), sub-context keeps the host module_qn. Verified: Vue `<script setup>` `handleAddImage` is a node (in=1 out=1), TS export `helperUtil` referenced only from the SFC has fan-in from the .vue (not dead)
- [x] T018 [AGL-6] Sniff `lang="ts"` on `script_element` → `CBM_LANG_TYPESCRIPT`; apply the same generalization to Svelte's identical-shaped spec — `embedded_script_language()` sniffs `lang`/`type` on the script's start_tag → TS grammar per block; Svelte rides the same routine (VUE/SVELTE/ASTRO case). Verified: TS type annotations parse; Svelte `svelteHandler` indexed; helperUtil fan-in = 2 across the .vue + .svelte referrers (landed in the same parse_embedded_scripts change as T017)
- [x] T019 [AGL-6] Extraction + pipeline tests (tests/test_extraction.c, tests/test_pipeline.c): script-setup symbols get nodes/edges, a TS export referenced only from an SFC is not dead, fan-in lists the .vue referencers, non-Vue results unchanged — extract_vue_script_setup_symbols_agl6 + extract_svelte_script_symbols_agl6 (def/call/import extracted); pipeline_vue_script_setup_fan_in_agl6 (handleAddImage is a node; helperUtil has semantic fan-in from the .vue → not dead; unusedExport referenced nowhere stays dead). non-Vue unchanged is covered by the rest of the extraction/pipeline suites staying green
- [x] T020 [risky] Close tranche C: full gate green; move AGL-6 to In Review with a summary comment — full gate green (exit 0, 1111s; the grammar_labels golden caught over-broad scope → fixed to Vue/Svelte-only in b9333974); AGL-6 → In Review with a realized-approach summary

### Tranche D — install.sh --clients (AGL-8)

- [x] T021 [AGL-8] Claim: move AGL-8 to In Progress, assignee me, start comment
- [x] T022 [AGL-8] install.sh: honor `--clients=…` (pass through to the binary installer), error on unrecognized flags, keep `--skip-config` unchanged; exercise only via a sandbox `$HOME` — replaced the two lenient parse loops with one strict stateful parser (handles --dir/--dir=/--clients=/--skip-config/--help; errors exit 2 on any unknown flag); `--clients=$CLIENTS` passed through to `$DLBIN install` when not skipping config, so --skip-config is byte-identical. Verified: --help documents --clients, unknown flags → exit 2, bare --dir errors, shellcheck clean. End-to-end (exactly-two-clients) verified in T031 under a sandbox $HOME
- [x] T023 [risky] Close tranche D: final gate green (the security audit's install-audit layer covers install.sh); move AGL-8 to In Review with a summary comment — final gate green (exit 0, 1266s; all 8 security-audit layers incl. install-audit passed). First attempt hit a load-induced flake (subprocess_cancel_grace_is_hard_capped — passes in isolation 31/31, passed T020's full gate; recorded in .ralph/guardrails.md); the re-run was green. AGL-8 → In Review

### Tranche E — Publication (AGL-10)

- [x] T024 [AGL-10] Claim: move AGL-10 to In Progress, assignee me, start comment
- [x] T025 [AGL-10] For each of AGL-5, AGL-7, AGL-8: collect that ticket's commits (`git log --grep AGL-N`), cherry-pick them onto a clean `fix/<slug>` branch off `upstream/main`, confirm the branch is upstream/main + only that ticket's commits and carries no `.claude/`, `.ralph/`, `linear-specs/`, `scripts/dev/`, `.agent-layer.json`, or `.mcp.json` paths, push to origin, open a **draft** PR (conventional title, body ends with `Fixes #N` — #1335 for AGL-5; AGL-9's new issues for AGL-7/AGL-8); record each PR URL on its ticket — reconstructed clean branches in a temp worktree off upstream/main (code files only, no linear-specs; test_cli.c split so AGL-5 has no worktree tests and AGL-7 has only them); pushed to origin; draft PRs #1767 (AGL-5/#1335), #1768 (AGL-7/#1752), #1769 (AGL-8/#1753); URLs on tickets
- [x] T026 [AGL-10] Create AGL-6's clean branch the same way (no PR — design approval pending on #1410), then assemble fork `main`: `upstream/main` + merge of the four new fix branches + `codex/fix-precommit-git-environment` + `codex/fix-daemon-runtime-sanitizer-timeout-only`; `scripts/build.sh` green on the result; push `origin/main` (plain push, never force)
- [x] T027 [risky] Close tranche E: full gate green; move AGL-10 to In Review with a branch + PR summary

### Tranche F — Install + verify (AGL-11)

- [x] T028 [AGL-11] Claim: move AGL-11 to In Progress, assignee me, start comment
- [ ] T029 [AGL-11] Build and install from `origin/main`: `scripts/build.sh`; put `build/c/codebase-memory-mcp` on PATH; run `codebase-memory-mcp install --clients=claude,codex` (the one sanctioned real-config install — it edits this machine's Claude/Codex config as intended; later loop iterations may begin receiving cbm hook context, which is expected)
- [ ] T030 [AGL-11] Index the AGL-5 baseline monorepo (repo path recorded in /Users/bmcnaboe/development/context-layer-bench/micro/cbm.jsonl) and verify AGL-5 (10/10 non-empty at default deadline; forced miss logged; `daemon start` in `--help`; override honored) and AGL-7 (payload-cwd worktree matrix); evidence comments on AGL-5 and AGL-7
- [ ] T031 [AGL-11] Verify AGL-8 via a sandbox `$HOME` and AGL-6 via the dmatrix probes (`search_graph` on `%SupplementalContentPanel.vue` shows script symbols beyond Module+File; `trace_path("handleAddImage")` resolves; never via `check_index_coverage`); evidence comments on AGL-8 and AGL-6; confirm the second-machine install one-liner is documented on the cbm adoption project
- [ ] T032 [risky] Close tranche F: full gate green; move AGL-11 to In Review with an evidence summary

## Tickets

### AGL-5 — hook-augment: 2s deadline silently emits nothing on large graphs

https://linear.app/agent-layer/issue/AGL-5/hook-augment-2s-deadline-silently-emits-nothing-on-large-graphs · Priority: High · Labels: Bug, Regular, Med Effort
Acceptance criteria (from the ticket — plain bullets, NOT checkboxes):

- AC1: Default config on a ~23k-node graph: hook returns non-empty context, no env override needed
- AC2: A missed deadline is recorded (timeouts log and/or stderr) — never silent 0 bytes / exit 0
- AC3: Hook uses the warm daemon when it is running; `daemon start` documented in `--help`
- AC4: `CBM_HOOK_DEADLINE_MS` override still honored
  Steps to reproduce: index a ~400k-LOC monorepo, pipe a PreToolUse payload into `codebase-memory-mcp hook-augment` → 0 bytes, exit 0 (663 bytes with `CBM_HOOK_DEADLINE_MS=4500`).
  Notes: root cause is the per-start SHA-256 of the ~295 MB executable (~2.3 s, software path). The ticket's implementation notes carry the cache site, CommonCrypto details, eliminated causes, and a v0.10.2 timeouts-log discrepancy to re-verify — read them before building.

### AGL-6 — Index Vue `<script setup>` symbols

https://linear.app/agent-layer/issue/AGL-6/index-vue-script-setup-symbols · Priority: Medium · Labels: Improvement, Complex, High Effort, Spec Kit
Acceptance criteria (from the ticket — plain bullets, NOT checkboxes):

- AC1: Symbols declared in `<script setup>` appear as graph nodes with import/call edges
- AC2: A TS export referenced only from a `<script setup>` SFC is no longer flagged dead
- AC3: Fan-in / rename-impact for such a symbol lists the referencing .vue files
- AC4: Indexing a 212-SFC repo completes cleanly; non-Vue results unchanged
  Notes: spec-first ticket (T016 writes the design note before code). Seam, included-ranges, and probe details are in the ticket's implementation notes. Verify by node counts and `trace_path`, never `check_index_coverage`.

### AGL-7 — hook-augment returns nothing when payload cwd is a git worktree

https://linear.app/agent-layer/issue/AGL-7/hook-augment-returns-nothing-when-payload-cwd-is-a-git-worktree · Priority: High · Labels: Bug, Regular, Med Effort
Acceptance criteria (from the ticket — plain bullets, NOT checkboxes):

- AC1: Payload cwd = indexed linked worktree → hook returns that worktree's own project context
- AC2: Payload cwd = unindexed worktree → deliberate, logged behavior (fallback or logged skip), never silent 0 bytes
- AC3: Main-checkout hook behavior unchanged
  Steps to reproduce: `git worktree add ../wt -b test`, index the worktree path, pipe a payload with cwd = the worktree → 0 bytes / exit 0 (cwd = main checkout → 663 bytes).
  Notes: `index_status` already resolves worktrees correctly (`is_worktree`, `git_common_dir`, `canonical_root`) — the hook path isn't using it. Evidence: /Users/bmcnaboe/development/context-layer-bench/micro/cbm-worktree-divergence.md.

### AGL-8 — install.sh silently drops --clients and configures every client

https://linear.app/agent-layer/issue/AGL-8/installsh-silently-drops-clients-and-configures-every-client · Priority: Low · Labels: Bug, Simple, Low Effort
Acceptance criteria (from the ticket — plain bullets, NOT checkboxes):

- AC1: `install.sh -- --clients=claude,codex` configures exactly those two clients
- AC2: Unrecognized installer-script flags fail with an error instead of being silently ignored
- AC3: `--skip-config` behavior unchanged
  Steps to reproduce: `curl … install.sh | bash -s -- --clients=claude,codex` on a many-client machine → every detected client configured (43 surfaces on the eval machine).
  Notes: the binary's own `install --clients=…` (the `=` form) honors the flag. All verification under a sandbox `$HOME`.

### AGL-9 — Upstream: issues for AGL-7/AGL-8, comments on #1335/#1410

https://linear.app/agent-layer/issue/AGL-9/upstream-issues-for-agl-7agl-8-comments-on-13351410 · Priority: Medium · Labels: Regular, Med Effort
Acceptance criteria (from the ticket — plain bullets, NOT checkboxes):

- AC1: Upstream issues exist for AGL-7 and AGL-8 with steps to reproduce + expected/actual; URLs recorded on those tickets
- AC2: Root-cause comment live on #1335; URL recorded on AGL-5
- AC3: Approach comment live on #1410 asking for design feedback; URL recorded on AGL-6
- AC4: No PRs opened from this ticket (publication owns PRs)

### AGL-10 — Publication: per-ticket draft PRs, assemble fork main

https://linear.app/agent-layer/issue/AGL-10/publication-per-ticket-draft-prs-assemble-fork-main · Priority: Medium · Labels: Regular, Med Effort
Acceptance criteria (from the ticket — plain bullets, NOT checkboxes):

- AC1: Draft PRs exist for AGL-5/7/8; each branch = `upstream/main` + only that ticket's commits; DCO check green
- AC2: `origin/main` = `upstream/main` + all five fix branches; `scripts/build.sh` succeeds on it; pushed
- AC3: No `.claude/`, `.ralph/`, `linear-specs/`, `scripts/dev/`, `.agent-layer.json`, or `.mcp.json` content on `main` or any PR branch
- AC4: PR URLs recorded on their fix tickets

### AGL-11 — Install cbm from fork main and verify all four fixes

https://linear.app/agent-layer/issue/AGL-11/install-cbm-from-fork-main-and-verify-all-four-fixes · Priority: High · Labels: Regular, Med Effort
Acceptance criteria (from the ticket — plain bullets, NOT checkboxes):

- AC1: AGL-5 — default-config hook-augment non-empty on the ~23k-node graph (10/10 invocations); a forced miss is logged; `daemon start` in `--help`; `CBM_HOOK_DEADLINE_MS` still honored
- AC2: AGL-7 — payload cwd = indexed linked worktree returns that worktree's context; unindexed worktree → logged skip/fallback, not silent
- AC3: AGL-8 — fork `install.sh --clients=claude,codex` configures exactly those two, verified against a sandbox `$HOME`
- AC4: AGL-6 — dmatrix probes flip (`search_graph` shows script symbols; `trace_path("handleAddImage")` resolves), not via `check_index_coverage`
- AC5: Evidence comment on each of AGL-5/6/7/8; second-machine install one-liner confirmed documented on the project
