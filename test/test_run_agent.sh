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

assert_eq() {
  local name="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then pass "$name"; else fail "$name" "expected '$expected', got '$actual'"; fi
}
assert_contains() {
  local name="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then pass "$name"; else fail "$name" "expected to contain '$needle'"; fi
}

# ──────────────────────────────────────
# model_family classification
# ──────────────────────────────────────
test_model_family() {
  printf '\n\033[1m== model_family ==\033[0m\n'
  assert_eq "fable is claude"       "$(model_family fable)"        "claude"
  assert_eq "sonnet is claude"      "$(model_family sonnet)"       "claude"
  assert_eq "opus is claude"        "$(model_family opus)"         "claude"
  assert_eq "claude-fable-5 claude" "$(model_family claude-fable-5)" "claude"
  assert_eq "gpt-5.6-sol is codex"  "$(model_family gpt-5.6-sol)"  "codex"
  assert_eq "spark is codex"        "$(model_family spark)"        "codex"
  assert_eq "codex is codex"        "$(model_family codex)"        "codex"
}

# ──────────────────────────────────────
# panel_model: defaults, overrides, --claude-only
# ──────────────────────────────────────
test_panel_model() {
  printf '\n\033[1m== panel_model ==\033[0m\n'
  assert_eq "full recon default sonnet"  "$(panel_model full:recon)"     "sonnet"
  assert_eq "full synthesize opus"       "$(panel_model full:synthesize)" "opus"
  assert_eq "split sonnet"               "$(panel_model split)"          "sonnet"
  assert_eq "draft minimal raw is gpt"   "$(panel_model full:draft:minimal)" "gpt-5.6-sol"
  # --claude-only forces codex entries to the Claude fallback (default opus)
  assert_eq "draft minimal claude-only"  "$(panel_model full:draft:minimal --claude-only)" "opus"
  assert_eq "redteam1 claude-only"       "$(panel_model full:redteam:1 --claude-only)" "opus"
  # env override wins
  assert_eq "env override recon" "$(ACORN_PANEL_full_recon=haiku panel_model full:recon)" "haiku"
  # custom fallback honored by claude-only
  assert_eq "custom fallback" "$(ACORN_CODEX_FALLBACK=sonnet panel_model full:draft:minimal --claude-only)" "sonnet"
}

# ──────────────────────────────────────
# resolve_model: codex degradation
# ──────────────────────────────────────
test_resolve_model() {
  printf '\n\033[1m== resolve_model degradation ==\033[0m\n'
  # spark expands even for claude-side callers (codex available forced on)
  assert_eq "spark expands" "$(ACORN_CODEX=1 resolve_model spark)" "gpt-5.3-codex-spark"
  # codex model + codex off -> soft fallback to opus
  assert_eq "soft degrade to opus" "$(ACORN_CODEX=0 resolve_model gpt-5.6-sol 2>/dev/null)" "opus"
  assert_eq "soft degrade custom" "$(ACORN_CODEX=0 ACORN_CODEX_FALLBACK=sonnet resolve_model gpt-5.6-sol 2>/dev/null)" "sonnet"
  # claude model passes through untouched even with codex off
  assert_eq "claude passthrough" "$(ACORN_CODEX=0 resolve_model opus)" "opus"
  # strict panel -> hard error
  local ec=0
  ( ACORN_CODEX=0 ACORN_STRICT_PANEL=1 resolve_model gpt-5.6-sol >/dev/null 2>&1 ) || ec=$?
  if [ "$ec" -ne 0 ]; then pass "strict panel dies"; else fail "strict panel dies" "expected non-zero exit"; fi
}

# ──────────────────────────────────────
# extract_json: raw and fenced
# ──────────────────────────────────────
test_extract_json() {
  printf '\n\033[1m== extract_json ==\033[0m\n'
  assert_eq "raw json" "$(extract_json '{"a":1}')" '{"a":1}'
  local fenced
  fenced=$'prose\n```json\n{"a":2}\n```\nmore'
  assert_contains "fenced json" "$(extract_json "$fenced")" '"a":2'
  local ec=0
  ( extract_json "not json at all" >/dev/null 2>&1 ) || ec=$?
  if [ "$ec" -ne 0 ]; then pass "non-json fails"; else fail "non-json fails" "expected non-zero"; fi
}

# ──────────────────────────────────────
# run_agent routes Claude family to `claude -p`
# ──────────────────────────────────────
test_run_agent_claude() {
  printf '\n\033[1m== run_agent -> claude ==\033[0m\n'
  local arglog out
  arglog="$(mktemp)"; out="$(mktemp)"
  claude() {
    local IFS=' '  # acorn sets IFS=$'\n\t'; join args with spaces for matching
    printf '%s\n' "$*" >> "$ARGLOG"
    cat >/dev/null
    case "$*" in
      *"--output-format json"*) jq -cn --arg r "$CLAUDE_RESULT" '{type:"result",result:$r}' ;;
      *) printf '%s' "$CLAUDE_RESULT" ;;
    esac
  }
  export -f claude
  export ARGLOG="$arglog"

  export ACORN_CODEX=0

  # text format: raw stdout captured to out
  export CLAUDE_RESULT="hello world"
  printf 'prompt' | run_agent opus "$out" --format text
  assert_eq "text written to out" "$(cat "$out")" "hello world"
  assert_contains "claude got --model opus" "$(cat "$arglog")" "--model opus"

  # json format: envelope .result extracted to out
  : > "$arglog"
  export CLAUDE_RESULT='{"ok":true}'
  printf 'prompt' | run_agent sonnet "$out" --format json
  assert_eq "json extracted to out" "$(cat "$out")" '{"ok":true}'
  assert_contains "claude json used --output-format" "$(cat "$arglog")" "--output-format json"
  assert_contains "claude json got --model sonnet" "$(cat "$arglog")" "--model sonnet"

  unset -f claude; unset ARGLOG CLAUDE_RESULT ACORN_CODEX
  rm -f "$arglog" "$out"
}

# ──────────────────────────────────────
# run_agent routes codex family to `codex exec`, and degrades when off
# ──────────────────────────────────────
test_run_agent_codex() {
  printf '\n\033[1m== run_agent -> codex ==\033[0m\n'
  local arglog out schema
  arglog="$(mktemp)"; out="$(mktemp)"; schema="$(mktemp)"
  printf '{"type":"object"}' > "$schema"
  codex() {
    local IFS=' '  # acorn sets IFS=$'\n\t'; join args with spaces for matching
    printf '%s\n' "$*" >> "$ARGLOG"
    local prev="" o=""
    for a in "$@"; do [ "$prev" = "-o" ] && o="$a"; prev="$a"; done
    [ -n "$o" ] && printf '%s' "$CODEX_RESULT" > "$o"
  }
  export -f codex
  export ARGLOG="$arglog"

  # codex forced available -> routes to codex with -m and --output-schema and -o
  export CODEX_RESULT='{"ok":1}'
  export ACORN_CODEX=1
  printf 'p' | run_agent gpt-5.6-sol "$out" --format json --schema "$schema"
  assert_eq "codex wrote out" "$(cat "$out")" '{"ok":1}'
  assert_contains "codex got -m gpt-5.6-sol" "$(cat "$arglog")" "-m gpt-5.6-sol"
  assert_contains "codex got exec" "$(cat "$arglog")" "exec"
  assert_contains "codex got --output-schema" "$(cat "$arglog")" "--output-schema"
  assert_contains "codex non-interactive" "$(cat "$arglog")" "-a never"

  # codex OFF -> soft-degrade to Claude fallback; codex stub must NOT be called
  : > "$arglog"
  local clog; clog="$(mktemp)"
  claude() { printf 'CALLED\n' >> "$CLOG"; cat >/dev/null; printf '%s' "degraded"; }
  export -f claude; export CLOG="$clog"
  export ACORN_CODEX=0
  printf 'p' | run_agent gpt-5.6-sol "$out" --format text 2>/dev/null
  assert_eq "degraded via claude" "$(cat "$out")" "degraded"
  assert_eq "codex not called when off" "$(cat "$arglog")" ""
  assert_contains "claude fallback invoked" "$(cat "$clog")" "CALLED"

  unset -f codex claude; unset ARGLOG CODEX_RESULT CLOG ACORN_CODEX
  rm -f "$arglog" "$out" "$schema" "$clog"
}

# ──────────────────────────────────────
# Runner
# ──────────────────────────────────────
test_model_family
test_panel_model
test_resolve_model
test_extract_json
test_run_agent_claude
test_run_agent_codex

printf '\n\033[1mResults: %d passed, %d failed\033[0m\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
