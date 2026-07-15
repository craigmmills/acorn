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
# run_pipeline dispatcher
# ──────────────────────────────────────
test_dispatcher() {
  printf '\n\033[1m== run_pipeline dispatcher ==\033[0m\n'
  local ec=0
  ( run_pipeline lite /tmp/s /tmp/r >/dev/null 2>&1 ) || ec=$?
  [ "$ec" -ne 0 ] && pass "lite not yet implemented" || fail "lite not yet implemented" "expected die"
  ec=0
  ( run_pipeline full /tmp/s /tmp/r >/dev/null 2>&1 ) || ec=$?
  [ "$ec" -ne 0 ] && pass "full not yet implemented" || fail "full not yet implemented" "expected die"
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

test_prompt_builders
test_lean_prompt_md
test_dispatcher
test_quick_orchestration
test_quick_recon_failure

printf '\n\033[1mResults: %d passed, %d failed\033[0m\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
