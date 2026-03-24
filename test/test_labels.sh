#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ACORN_SCRIPT="$SCRIPT_DIR/bin/acorn"

# Source acorn functions without triggering main()
eval "$(sed '/^main "\$@"/d' "$ACORN_SCRIPT")"

PASS=0
FAIL=0
TMPDIR_BASE=""

pass() { PASS=$((PASS + 1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  \033[31mFAIL\033[0m %s -- %s\n' "$1" "$2"; }

assert_eq() {
  local name="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$name"
  else
    fail "$name" "expected '$expected', got '$actual'"
  fi
}

assert_contains() {
  local name="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    pass "$name"
  else
    fail "$name" "expected to contain '$needle'"
  fi
}

assert_not_contains() {
  local name="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    fail "$name" "expected NOT to contain '$needle'"
  else
    pass "$name"
  fi
}

setup() {
  TMPDIR_BASE="$(mktemp -d)"
}

teardown() {
  [ -n "$TMPDIR_BASE" ] && rm -rf "$TMPDIR_BASE"
  unset -f gh 2>/dev/null || true
}

test_clarification_labels_constant() {
  printf '\n\033[1m== CLARIFICATION_LABELS constant ==\033[0m\n'
  assert_eq "array length" "${#CLARIFICATION_LABELS[@]}" "2"
  assert_eq "first label" "${CLARIFICATION_LABELS[0]}" "ai-drafted"
  assert_eq "second label" "${CLARIFICATION_LABELS[1]}" "human-clarified"
}

test_clarification_for_issue() {
  printf '\n\033[1m== clarification_for_issue ==\033[0m\n'

  local tmpdir
  tmpdir="$(mktemp -d)"

  gh() {
    echo '{"labels": [{"name": "spec-in-progress"}, {"name": "ai-drafted"}]}'
  }
  export -f gh

  local result
  result="$(clarification_for_issue "$tmpdir" "1")"
  assert_eq "detects ai-drafted" "$result" "ai-drafted"

  gh() {
    echo '{"labels": [{"name": "spec-in-progress"}, {"name": "human-clarified"}]}'
  }
  export -f gh

  result="$(clarification_for_issue "$tmpdir" "1")"
  assert_eq "detects human-clarified" "$result" "clarified"

  gh() {
    echo '{"labels": [{"name": "spec-in-progress"}]}'
  }
  export -f gh

  result="$(clarification_for_issue "$tmpdir" "1")"
  assert_eq "no clarification label" "$result" "--"

  gh() {
    echo '{"labels": [{"name": "ai-drafted"}, {"name": "human-clarified"}]}'
  }
  export -f gh

  result="$(clarification_for_issue "$tmpdir" "1")"
  assert_eq "both labels, clarified wins" "$result" "clarified"

  result="$(clarification_for_issue "$tmpdir" "")"
  assert_eq "empty issue number" "$result" "--"

  rm -rf "$tmpdir"
  unset -f gh
}

test_print_list_row_columns() {
  printf '\n\033[1m== print_list_row columns ==\033[0m\n'

  local output
  output="$(print_list_row "myrepo" "42" "42-my-slug" "planning" "lite" "2h" "ai-drafted" "2" "/tmp/spec")"
  assert_contains "repo in output" "$output" "myrepo"
  assert_contains "issue in output" "$output" "42"
  assert_contains "status in output" "$output" "planning"
  assert_contains "clarify in output" "$output" "ai-drafted"
  assert_contains "deps in output" "$output" "2"
  assert_contains "path in output" "$output" "/tmp/spec"

  output="$(print_list_row "myrepo" "42" "42-my-slug" "approved" "full" "1d" "clarified" "--" "/tmp/spec")"
  assert_contains "clarified in output" "$output" "clarified"

  output="$(print_list_row "myrepo" "42" "42-my-slug" "unknown" "full" "3d" "--" "--" "/tmp/spec")"
  assert_contains "dash in output" "$output" "--"
}

test_print_list_header() {
  printf '\n\033[1m== print_list_header ==\033[0m\n'

  local output
  output="$(print_list_header)"
  assert_contains "has clarify header" "$output" "clarify"
  assert_contains "has deps header" "$output" "deps"
  assert_contains "has spec_path header" "$output" "spec_path"
}

INTEGRATION="${INTEGRATION:-0}"

test_integration_clarify_flow() {
  printf '\n\033[1m== Integration: clarify flow ==\033[0m\n'

  local test_repo="acorn"
  local repo_main
  repo_main="$(safe_repo_main "$test_repo")"

  local result issue_num
  result="$(create_issue_in_repo "$test_repo" "Test clarification labels [CI]" --label "test")"
  issue_num="$(printf '%s' "$result" | sed -n '1p')"

  ensure_labels "$repo_main"
  set_clarification_label "$repo_main" "$issue_num" "ai-drafted"

  local labels
  labels="$(cd "$repo_main" && gh issue view "$issue_num" --json labels | jq -r '.labels[].name')"
  assert_contains "has ai-drafted" "$labels" "ai-drafted"
  assert_not_contains "no human-clarified yet" "$labels" "human-clarified"

  set_clarification_label "$repo_main" "$issue_num" "human-clarified"

  labels="$(cd "$repo_main" && gh issue view "$issue_num" --json labels | jq -r '.labels[].name')"
  assert_contains "has human-clarified" "$labels" "human-clarified"
  assert_not_contains "ai-drafted removed" "$labels" "ai-drafted"

  local clarify_result
  clarify_result="$(clarification_for_issue "$repo_main" "$issue_num")"
  assert_eq "clarification_for_issue returns clarified" "$clarify_result" "clarified"

  (cd "$repo_main" && gh issue close "$issue_num") >/dev/null 2>&1 || true
}

# ---- Run tests ----
setup

test_clarification_labels_constant
test_clarification_for_issue
test_print_list_row_columns
test_print_list_header

if [ "$INTEGRATION" = "1" ]; then
  test_integration_clarify_flow
else
  printf '\n\033[2mSkipping integration tests (run with INTEGRATION=1 to enable)\033[0m\n'
fi

teardown

# ---- Summary ----
printf '\n\033[1mResults: %d passed, %d failed\033[0m\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
