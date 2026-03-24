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
  unset -f gh safe_repo_main set_issue_state_label set_clarification_label ensure_labels 2>/dev/null || true
}

test_clarification_labels_constant() {
  printf '\n\033[1m== CLARIFICATION_LABELS constant ==\033[0m\n'
  assert_eq "array length" "${#CLARIFICATION_LABELS[@]}" "2"
  assert_eq "first label" "${CLARIFICATION_LABELS[0]}" "ai-drafted"
  assert_eq "second label" "${CLARIFICATION_LABELS[1]}" "human-clarified"
}

test_lifecycle_labels_constant() {
  printf '\n\033[1m== LIFECYCLE_LABELS constant ==\033[0m\n'
  assert_eq "array length" "${#LIFECYCLE_LABELS[@]}" "8"
  assert_eq "label 0" "${LIFECYCLE_LABELS[0]}" "triage"
  assert_eq "label 1" "${LIFECYCLE_LABELS[1]}" "ready-for-spec"
  assert_eq "label 2" "${LIFECYCLE_LABELS[2]}" "spec-in-progress"
  assert_eq "label 3" "${LIFECYCLE_LABELS[3]}" "spec-review"
  assert_eq "label 4" "${LIFECYCLE_LABELS[4]}" "spec-approved"
  assert_eq "label 5" "${LIFECYCLE_LABELS[5]}" "implementing"
  assert_eq "label 6" "${LIFECYCLE_LABELS[6]}" "in-review"
  assert_eq "label 7" "${LIFECYCLE_LABELS[7]}" "done"
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

test_status_for_spec_reads_lifecycle_label() {
  printf '\n\033[1m== status_for_spec with lifecycle labels ==\033[0m\n'

  local tmpdir
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/plans"

  gh() {
    echo '{"labels": [{"name": "spec-in-progress"}, {"name": "ai-drafted"}]}'
  }
  export -f gh

  local result
  result="$(status_for_spec "$tmpdir" "1" "$tmpdir")"
  assert_eq "spec-in-progress label" "$result" "spec-in-progress"

  gh() {
    echo '{"labels": [{"name": "implementing"}]}'
  }
  export -f gh

  result="$(status_for_spec "$tmpdir" "1" "$tmpdir")"
  assert_eq "implementing label" "$result" "implementing"

  gh() {
    echo '{"labels": [{"name": "done"}]}'
  }
  export -f gh

  result="$(status_for_spec "$tmpdir" "1" "$tmpdir")"
  assert_eq "done label" "$result" "done"

  gh() {
    echo '{"labels": [{"name": "triage"}, {"name": "ai-drafted"}]}'
  }
  export -f gh

  result="$(status_for_spec "$tmpdir" "1" "$tmpdir")"
  assert_eq "triage label" "$result" "triage"

  gh() {
    echo '{"labels": []}'
  }
  export -f gh

  touch "$tmpdir/plans/SPEC.md"
  result="$(status_for_spec "$tmpdir" "1" "$tmpdir")"
  assert_eq "fallback review" "$result" "review"

  rm -f "$tmpdir/plans/SPEC.md"
  touch "$tmpdir/PROMPT.md"
  result="$(status_for_spec "$tmpdir" "1" "$tmpdir")"
  assert_eq "fallback planning" "$result" "planning"

  rm -f "$tmpdir/PROMPT.md"
  result="$(status_for_spec "$tmpdir" "1" "$tmpdir")"
  assert_eq "fallback unknown" "$result" "unknown"

  rm -rf "$tmpdir"
  unset -f gh
}

test_cmd_issue_label_validates() {
  printf '\n\033[1m== cmd_issue_label validation ==\033[0m\n'

  local tmpdir
  tmpdir="$(mktemp -d)"

  safe_repo_main() { printf '%s' "$tmpdir"; }
  export -f safe_repo_main

  gh() { return 0; }
  export -f gh

  local output
  output="$(cmd_issue_label "myrepo" "1" "implementing" 2>&1)" || true
  assert_contains "valid label accepted" "$output" "implementing"

  local err_output
  err_output="$(cmd_issue_label "myrepo" "1" "bogus" 2>&1)" || true
  assert_contains "invalid label rejected" "$err_output" "Unknown lifecycle label"

  rm -rf "$tmpdir"
  unset -f safe_repo_main gh
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

test_print_list_row_new_status_values() {
  printf '\n\033[1m== print_list_row with new status values ==\033[0m\n'

  local output
  output="$(print_list_row "myrepo" "42" "42-my-slug" "implementing" "lite" "2h" "ai-drafted" "--" "/tmp/spec")"
  assert_contains "implementing in output" "$output" "implementing"

  output="$(print_list_row "myrepo" "42" "42-my-slug" "spec-in-progress" "full" "1d" "clarified" "--" "/tmp/spec")"
  assert_contains "spec-in-progress in output" "$output" "spec-in-progress"

  output="$(print_list_row "myrepo" "42" "42-my-slug" "done" "quick" "5d" "--" "--" "/tmp/spec")"
  assert_contains "done in output" "$output" "done"

  output="$(print_list_row "myrepo" "42" "42-my-slug" "triage" "lite" "1h" "ai-drafted" "--" "/tmp/spec")"
  assert_contains "triage in output" "$output" "triage"
}

test_print_list_header() {
  printf '\n\033[1m== print_list_header ==\033[0m\n'

  local output
  output="$(print_list_header)"
  assert_contains "has clarify header" "$output" "clarify"
  assert_contains "has deps header" "$output" "deps"
  assert_contains "has spec_path header" "$output" "spec_path"
}

test_clarify_guard_prevents_regression() {
  printf '\n\033[1m== cmd_issue_clarify lifecycle guard ==\033[0m\n'

  local tmpdir
  tmpdir="$(mktemp -d)"

  safe_repo_main() { printf '%s' "$tmpdir"; }
  export -f safe_repo_main

  local set_label_calls=""
  set_issue_state_label() { set_label_calls="$set_label_calls $3"; }
  export -f set_issue_state_label

  set_clarification_label() { :; }
  export -f set_clarification_label

  ensure_labels() { :; }
  export -f ensure_labels

  gh() {
    case "$1" in
      issue) echo '{"labels": [{"name": "triage"}]}' ;;
      *) return 0 ;;
    esac
  }
  export -f gh

  set_label_calls=""
  cmd_issue_clarify "myrepo" "1" >/dev/null 2>&1
  assert_contains "triage transitions" "$set_label_calls" "ready-for-spec"

  gh() {
    case "$1" in
      issue) echo '{"labels": [{"name": "spec-in-progress"}]}' ;;
      *) return 0 ;;
    esac
  }
  export -f gh

  set_label_calls=""
  cmd_issue_clarify "myrepo" "1" >/dev/null 2>&1
  assert_not_contains "no regression" "$set_label_calls" "ready-for-spec"

  rm -rf "$tmpdir"
  unset -f safe_repo_main set_issue_state_label set_clarification_label ensure_labels gh
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
  set_issue_state_label "$repo_main" "$issue_num" "triage"
  set_clarification_label "$repo_main" "$issue_num" "ai-drafted"

  local labels
  labels="$(cd "$repo_main" && gh issue view "$issue_num" --json labels | jq -r '.labels[].name')"
  assert_contains "has triage" "$labels" "triage"
  assert_contains "has ai-drafted" "$labels" "ai-drafted"

  cmd_issue_clarify "$test_repo" "$issue_num" >/dev/null

  labels="$(cd "$repo_main" && gh issue view "$issue_num" --json labels | jq -r '.labels[].name')"
  assert_contains "transitions to ready-for-spec" "$labels" "ready-for-spec"
  assert_not_contains "triage removed" "$labels" "triage"
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
test_lifecycle_labels_constant
test_clarification_for_issue
test_status_for_spec_reads_lifecycle_label
test_cmd_issue_label_validates
test_print_list_row_columns
test_print_list_row_new_status_values
test_print_list_header
test_clarify_guard_prevents_regression

if [ "$INTEGRATION" = "1" ]; then
  test_integration_clarify_flow
else
  printf '\n\033[2mSkipping integration tests (run with INTEGRATION=1 to enable)\033[0m\n'
fi

teardown

# ---- Summary ----
printf '\n\033[1mResults: %d passed, %d failed\033[0m\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
