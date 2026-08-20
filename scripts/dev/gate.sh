#!/usr/bin/env bash
# Ralph gate tiers for this fork's linear runs. Run infrastructure only —
# lives on ralph-base/linear branches, never merged to main or any PR branch.
# basic = compile smoke; full = ASan test suite + linters; final = full + the
# 8-layer security audit (required whenever install.sh changes).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# The install/activation tests in scripts/test.sh reserve the machine-global CBM
# coordination rendezvous (its key is a fixed product-domain string; isolation
# comes only from the shared runtime-parent directory). A warm daemon left
# running by a real `install` holds that rendezvous BUSY, so every
# install-activation test fails with "active CBM sessions ... no activation was
# committed". This fork dogfoods a permanently-installed daemon, so stop it
# before the suite runs. Best-effort: a missing binary or no live daemon is a
# no-op, never a gate failure.
stop_cbm_daemon() {
  local bin
  bin=$(command -v codebase-memory-mcp || echo build/c/codebase-memory-mcp)
  [ -x "$bin" ] || return 0
  "$bin" daemon stop >/dev/null 2>&1 || true
}

case "${1:-basic}" in
  basic) scripts/build.sh ;;
  full)  stop_cbm_daemon; scripts/test.sh && scripts/lint.sh --ci && scripts/ci/lint-mem.sh ;;
  final) stop_cbm_daemon; scripts/test.sh && scripts/lint.sh --ci && scripts/ci/lint-mem.sh && make -f Makefile.cbm security ;;
  *) echo "usage: gate.sh [basic|full|final]" >&2; exit 2 ;;
esac
