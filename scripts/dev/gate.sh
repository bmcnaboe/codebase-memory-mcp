#!/usr/bin/env bash
# Ralph gate tiers for this fork's linear runs. Run infrastructure only —
# lives on ralph-base/linear branches, never merged to main or any PR branch.
# basic = compile smoke; full = ASan test suite + linters; final = full + the
# 8-layer security audit (required whenever install.sh changes).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

case "${1:-basic}" in
  basic) scripts/build.sh ;;
  full)  scripts/test.sh && scripts/lint.sh --ci && scripts/ci/lint-mem.sh ;;
  final) scripts/test.sh && scripts/lint.sh --ci && scripts/ci/lint-mem.sh && make -f Makefile.cbm security ;;
  *) echo "usage: gate.sh [basic|full|final]" >&2; exit 2 ;;
esac
