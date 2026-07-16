#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ACORN_SCRIPT="$SCRIPT_DIR/bin/acorn"

# Source acorn functions without triggering main()
eval "$(sed '/^main "\$@"/d' "$ACORN_SCRIPT")"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  \033[31mFAIL\033[0m %s -- %s\n' "$1" "$2"; }

assert_contains() {
  local name="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then pass "$name"; else fail "$name" "expected to contain '$needle'"; fi
}
assert_not_contains() {
  local name="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then fail "$name" "should NOT contain '$needle'"; else pass "$name"; fi
}
assert_file_contains() {
  local name="$1" file="$2" needle="$3"
  if [ -f "$file" ] && grep -qF -- "$needle" "$file"; then pass "$name"; else fail "$name" "file '$file' missing or lacks '$needle'"; fi
}
assert_eq() {
  local name="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then pass "$name"; else fail "$name" "expected '$expected', got '$actual'"; fi
}

# ──────────────────────────────────────
# recon_prompt / quick_spec_prompt
# ──────────────────────────────────────
test_prompt_builders() {
  printf '\n\033[1m== prompt builders ==\033[0m\n'
  local arch rel conv spec
  arch="$(recon_prompt architecture /S)"
  rel="$(recon_prompt relevant_code /S)"
  conv="$(recon_prompt conventions /S)"
  assert_contains "recon reads PROMPT.md"     "$arch" "/S/PROMPT.md"
  assert_contains "architecture facet"        "$arch" "architecture and structure"
  assert_contains "relevant_code facet"       "$rel"  "files and modules most likely to change"
  assert_contains "conventions facet"         "$conv" "conventions and constraints"
  # De-prescribed: no tmux-era scaffolding
  assert_not_contains "no SUB-AGENT scaffolding"    "$arch" "SUB-AGENT"
  assert_not_contains "no 4000-token chunking"      "$arch" "4000"
  assert_not_contains "no Done-only protocol"       "$arch" "Done. Output"

  spec="$(quick_spec_prompt /S)"
  assert_contains "spec reads recon architecture" "$spec" "/S/recon/architecture.md"
  assert_contains "spec reads recon relevant"     "$spec" "/S/recon/relevant_code.md"
  assert_contains "spec asks for traceability"    "$spec" "traceability"

  # Full-mode stage prompts
  assert_contains "draft minimal lens"   "$(draft_prompt minimal /S)"      "Minimal Surgery"
  assert_contains "draft dx lens"        "$(draft_prompt dx /S)"           "Developer Experience"
  assert_not_contains "draft de-prescribed" "$(draft_prompt minimal /S)"   "SUB-AGENT"
  assert_contains "evaluate reads drafts" "$(evaluate_prompt /S)"          "/S/plans/draft_plan_4.md"
  assert_contains "synthesis reads eval" "$(synthesis_prompt /S)"          "/S/plans/evaluation.md"
  assert_contains "redteam edge angle"   "$(redteam_prompt edge /S)"       "Edge cases"
  assert_contains "redteam reads master" "$(redteam_prompt requirements /S)" "/S/plans/master_plan.md"
  assert_contains "final spec reads red team" "$(final_spec_prompt /S)"    "/S/plans/red_team_1..4.md"
  assert_contains "final spec resolution log" "$(final_spec_prompt /S)"    "red-team resolution log"
  # Lite-mode stage prompts
  assert_contains "lite draft comprehensive" "$(lite_draft_prompt /S)"     "comprehensive implementation plan"
  assert_contains "lite validate reads draft" "$(lite_validate_prompt /S)" "/S/plans/draft_plan_1.md"
  assert_contains "lite spec reads validation" "$(lite_spec_prompt /S)"    "/S/plans/validation.md"
}

# ──────────────────────────────────────
# render_prompt_md lean mode (include_methodology=0)
# ──────────────────────────────────────
test_lean_prompt_md() {
  printf '\n\033[1m== lean PROMPT.md ==\033[0m\n'
  local out; out="$(mktemp)"
  render_prompt_md "My feature" "Do the thing." '{}' "$out" quick /tmp/x "" 0
  assert_file_contains "lean has Requirements"     "$out" "## Requirements"
  if grep -q 'PLANNING METHODOLOGY' "$out"; then fail "lean omits methodology" "anchor present"; else pass "lean omits methodology"; fi
  if validate_prompt_md_lean "$out"; then pass "validate_lean accepts"; else fail "validate_lean accepts" "rejected a valid lean prompt"; fi
  if validate_prompt_md "$out" 2>/dev/null; then fail "full validator rejects lean" "accepted"; else pass "full validator rejects lean"; fi
  rm -f "$out"

  # Full mode still emits the methodology anchor
  local full; full="$(mktemp)"
  render_prompt_md "My feature" "Do the thing." '{}' "$full" quick /tmp/x "" 1
  assert_file_contains "full keeps methodology" "$full" "PLANNING METHODOLOGY"
  rm -f "$full"
}

# ──────────────────────────────────────
# run_pipeline dispatcher: unknown mode dies
# ──────────────────────────────────────
test_dispatcher() {
  printf '\n\033[1m== run_pipeline dispatcher ==\033[0m\n'
  local ec=0
  ( run_pipeline bogus /tmp/s /tmp/r >/dev/null 2>&1 ) || ec=$?
  [ "$ec" -ne 0 ] && pass "unknown mode dies" || fail "unknown mode dies" "expected die"
}

# Shared stub: record model, consume prompt, write a marker to each out file.
_stub_run_agent() {
  run_agent() {
    local model="$1" out="$2"
    cat >/dev/null
    printf 'STUB model=%s\n' "$model" > "$out"
  }
}

# ──────────────────────────────────────
# run_pipeline_lite orchestration (stubbed run_agent)
# ──────────────────────────────────────
test_lite_orchestration() {
  printf '\n\033[1m== run_pipeline_lite (stubbed run_agent) ==\033[0m\n'
  local spec repo
  spec="$(mktemp -d)"; repo="$(mktemp -d)"
  mkdir -p "$spec/recon" "$spec/plans"; printf '# Feature\n' > "$spec/PROMPT.md"
  _stub_run_agent
  run_pipeline_lite "$spec" "$repo" >/dev/null 2>&1
  assert_file_contains "lite recon architecture" "$spec/recon/architecture.md" "model=sonnet"
  assert_file_contains "lite draft written"      "$spec/plans/draft_plan_1.md" "model=opus"
  assert_file_contains "lite validation on sonnet" "$spec/plans/validation.md" "model=sonnet"
  assert_file_contains "lite SPEC on opus"       "$spec/plans/SPEC.md"         "model=opus"
  unset -f run_agent; rm -rf "$spec" "$repo"
}

# ──────────────────────────────────────
# run_pipeline_full orchestration (stubbed run_agent)
# ──────────────────────────────────────
test_full_orchestration() {
  printf '\n\033[1m== run_pipeline_full (stubbed run_agent) ==\033[0m\n'
  local spec repo
  spec="$(mktemp -d)"; repo="$(mktemp -d)"
  mkdir -p "$spec/recon" "$spec/plans"; printf '# Feature\n' > "$spec/PROMPT.md"
  _stub_run_agent
  run_pipeline_full "$spec" "$repo" >/dev/null 2>&1

  # All 14 artifacts land
  local f
  for f in recon/architecture.md recon/relevant_code.md recon/conventions.md \
           plans/draft_plan_1.md plans/draft_plan_2.md plans/draft_plan_3.md plans/draft_plan_4.md \
           plans/evaluation.md plans/master_plan.md \
           plans/red_team_1.md plans/red_team_2.md plans/red_team_3.md plans/red_team_4.md \
           plans/SPEC.md; do
    [ -s "$spec/$f" ] && pass "full artifact $f" || fail "full artifact $f" "missing/empty"
  done

  # Heterogeneous drafter panel routes for real (no --claude-only in headless):
  # draft 1 gets the codex model, draft 4 gets Fable, final spec gets Fable.
  assert_file_contains "draft 1 -> codex (gpt)" "$spec/plans/draft_plan_1.md" "model=gpt-5.6-sol"
  assert_file_contains "draft 4 -> fable"       "$spec/plans/draft_plan_4.md" "model=fable"
  assert_file_contains "red team 1 -> codex"    "$spec/plans/red_team_1.md"   "model=gpt-5.6-sol"
  assert_file_contains "final SPEC -> fable"    "$spec/plans/SPEC.md"         "model=fable"
  unset -f run_agent; rm -rf "$spec" "$repo"
}

# ──────────────────────────────────────
# run_pipeline_quick orchestration (run_agent stubbed)
# ──────────────────────────────────────
test_quick_orchestration() {
  printf '\n\033[1m== run_pipeline_quick (stubbed run_agent) ==\033[0m\n'
  local spec repo
  spec="$(mktemp -d)"; repo="$(mktemp -d)"
  mkdir -p "$spec/recon" "$spec/plans"
  printf '# Feature\n' > "$spec/PROMPT.md"

  # Stub run_agent: record model, consume prompt, write a marker to the out file.
  run_agent() {
    local model="$1" out="$2"
    cat >/dev/null
    printf 'STUB model=%s\n' "$model" > "$out"
  }

  run_pipeline_quick "$spec" "$repo" >/dev/null 2>&1

  assert_file_contains "recon architecture written" "$spec/recon/architecture.md" "model=sonnet"
  assert_file_contains "recon relevant_code written" "$spec/recon/relevant_code.md" "model=sonnet"
  assert_file_contains "recon conventions written"   "$spec/recon/conventions.md"   "model=sonnet"
  assert_file_contains "SPEC.md written on opus"      "$spec/plans/SPEC.md"          "model=opus"

  unset -f run_agent
  rm -rf "$spec" "$repo"
}

# ──────────────────────────────────────
# run_pipeline_quick fails when a recon artifact is empty
# ──────────────────────────────────────
test_quick_recon_failure() {
  printf '\n\033[1m== run_pipeline_quick recon failure ==\033[0m\n'
  local spec repo
  spec="$(mktemp -d)"; repo="$(mktemp -d)"
  mkdir -p "$spec/recon" "$spec/plans"
  printf '# Feature\n' > "$spec/PROMPT.md"

  # Stub: write nothing for the 'conventions' facet -> empty artifact -> stage fails.
  run_agent() {
    local model="$1" out="$2"
    cat >/dev/null
    case "$out" in
      *conventions.md) : ;;                       # leave empty
      *) printf 'ok\n' > "$out" ;;
    esac
  }

  local ec=0
  ( run_pipeline_quick "$spec" "$repo" >/dev/null 2>&1 ) || ec=$?
  [ "$ec" -ne 0 ] && pass "recon stage fails on empty artifact" || fail "recon stage fails on empty artifact" "expected non-zero exit"

  unset -f run_agent
  rm -rf "$spec" "$repo"
}

# ──────────────────────────────────────
# sed interpolation safety: ACORN_PANEL_* with sed metachars must not corrupt
# ──────────────────────────────────────
test_sed_escape() {
  printf '\n\033[1m== sed_rep_escape + planning-block interpolation ==\033[0m\n'
  assert_eq "escapes ampersand" "$(sed_rep_escape 'a&b')" 'a\&b'
  assert_eq "escapes pipe"      "$(sed_rep_escape 'a|b')" 'a\|b'
  assert_eq "escapes backslash" "$(sed_rep_escape 'a\b')" 'a\\b'

  # A panel override containing '&' must render literally, not expand to the token.
  local out
  out="$(ACORN_PANEL_full_recon='x&y' ACORN_CODEX=0 planning_block full /tmp/s 2>/dev/null)"
  assert_contains "ampersand override renders literally" "$out" 'Use model "x&y"'
  assert_not_contains "no residual model token" "$out" '__MODEL_RECON__'

  # A '|' (the sed delimiter) in an override must not break rendering.
  local ec=0
  ( ACORN_PANEL_full_recon='a|b' ACORN_CODEX=0 planning_block full /tmp/s >/dev/null 2>&1 ) || ec=$?
  [ "$ec" -eq 0 ] && pass "pipe override does not break sed" || fail "pipe override does not break sed" "render errored"
}

test_prompt_builders
test_lean_prompt_md
test_dispatcher
test_quick_orchestration
test_lite_orchestration
test_full_orchestration
test_quick_recon_failure
test_sed_escape

printf '\n\033[1mResults: %d passed, %d failed\033[0m\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
