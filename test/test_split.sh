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
  unset -f claude 2>/dev/null || true
  unset -f create_issue_in_repo 2>/dev/null || true
  unset -f comment_issue 2>/dev/null || true
  unset -f gh_issue_json 2>/dev/null || true
  unset -f safe_repo_main 2>/dev/null || true
  unset -f require_cmds 2>/dev/null || true
  unset -f analyze_issue_for_split 2>/dev/null || true
}

# ──────────────────────────────────────
# Test: format_split_recommendation (split=true)
# ──────────────────────────────────────
test_format_recommendation_split() {
  printf '\n\033[1m== format_split_recommendation (split=true) ==\033[0m\n'

  local json='{"should_split":true,"reasoning":"Multiple independent concerns","sub_issues":[{"title":"Add logging","scope":"Add structured logging to all endpoints"},{"title":"Add metrics","scope":"Add Prometheus metrics collection"}]}'

  local output
  output="$(format_split_recommendation "$json" "42")"

  assert_contains "has SPLIT" "$output" "SPLIT"
  assert_contains "has reasoning" "$output" "Multiple independent concerns"
  assert_contains "has sub-issue 1" "$output" "Add logging"
  assert_contains "has sub-issue 2" "$output" "Add metrics"
  assert_contains "has scope 1" "$output" "structured logging"
  assert_contains "has scope 2" "$output" "Prometheus metrics"
  assert_contains "has issue number" "$output" "#42"
  assert_contains "shows count" "$output" "2"
}

# ──────────────────────────────────────
# Test: format_split_recommendation (split=false)
# ──────────────────────────────────────
test_format_recommendation_no_split() {
  printf '\n\033[1m== format_split_recommendation (split=false) ==\033[0m\n'

  local json='{"should_split":false,"reasoning":"Already focused on a single concern","sub_issues":[]}'

  local output
  output="$(format_split_recommendation "$json" "42")"

  assert_contains "has DO NOT SPLIT" "$output" "DO NOT SPLIT"
  assert_contains "has reasoning" "$output" "Already focused"
  assert_not_contains "no sub-issues heading" "$output" "Proposed sub-issues"
}

# ──────────────────────────────────────
# Test: analyze_issue_for_split with raw JSON response
# ──────────────────────────────────────
test_analyze_raw_json() {
  printf '\n\033[1m== analyze_issue_for_split (raw JSON) ==\033[0m\n'

  claude() {
    cat <<'MOCK_EOF'
{"should_split":true,"reasoning":"test reason","sub_issues":[{"title":"A","scope":"scope A"}]}
MOCK_EOF
  }
  export -f claude

  local result
  result="$(analyze_issue_for_split "Test title" "Test body" "" "mock" 2>/dev/null)"

  local should_split
  should_split="$(printf '%s' "$result" | jq -r '.should_split')"
  assert_eq "parses should_split" "$should_split" "true"

  local reasoning
  reasoning="$(printf '%s' "$result" | jq -r '.reasoning')"
  assert_eq "parses reasoning" "$reasoning" "test reason"

  unset -f claude
}

# ──────────────────────────────────────
# Test: analyze_issue_for_split with fenced JSON response
# ──────────────────────────────────────
test_analyze_fenced_json() {
  printf '\n\033[1m== analyze_issue_for_split (fenced JSON) ==\033[0m\n'

  claude() {
    cat <<'MOCK_EOF'
Here is my analysis:
```json
{"should_split":false,"reasoning":"focused issue","sub_issues":[]}
```
MOCK_EOF
  }
  export -f claude

  local result
  result="$(analyze_issue_for_split "Test" "Body" "" "mock" 2>/dev/null)"

  local should_split
  should_split="$(printf '%s' "$result" | jq -r '.should_split')"
  assert_eq "parses fenced should_split=false" "$should_split" "false"

  unset -f claude
}

# ──────────────────────────────────────
# Test: analyze_issue_for_split validates JSON structure
# ──────────────────────────────────────
test_analyze_invalid_json() {
  printf '\n\033[1m== analyze_issue_for_split (invalid JSON) ==\033[0m\n'

  claude() {
    echo "I think this issue is fine as-is."
  }
  export -f claude

  local exit_code=0
  (analyze_issue_for_split "Test" "Body" "" "mock" >/dev/null 2>/dev/null) || exit_code=$?

  if [ "$exit_code" -ne 0 ]; then
    pass "dies on invalid JSON response"
  else
    fail "dies on invalid JSON response" "expected non-zero exit, got 0"
  fi

  unset -f claude
}

# ──────────────────────────────────────
# Test: cmd_issue_split flag parsing and no-split flow
# ──────────────────────────────────────
test_cmd_split_no_split() {
  printf '\n\033[1m== cmd_issue_split (no split recommended) ==\033[0m\n'

  gh_issue_json() {
    echo '{"number":1,"title":"Simple task","body":"Do one thing","url":"https://github.com/test/repo/issues/1","comments":[],"labels":[],"assignees":[]}'
  }
  export -f gh_issue_json

  analyze_issue_for_split() {
    echo '{"should_split":false,"reasoning":"Already focused","sub_issues":[]}'
  }
  export -f analyze_issue_for_split

  safe_repo_main() { echo "/tmp/fakerepo"; }
  export -f safe_repo_main

  require_cmds() { true; }
  export -f require_cmds

  local output
  output="$(cmd_issue_split "fakerepo" "1" --yes 2>/dev/null)"

  assert_contains "shows no split" "$output" "No split recommended"
  assert_contains "shows next step" "$output" "acorn create"

  unset -f gh_issue_json analyze_issue_for_split safe_repo_main require_cmds
}

# ──────────────────────────────────────
# Test: cmd_issue_split rejects split with fewer than 2 sub-issues
# ──────────────────────────────────────
test_cmd_split_too_few_sub_issues() {
  printf '\n\033[1m== cmd_issue_split (< 2 sub-issues) ==\033[0m\n'

  gh_issue_json() {
    echo '{"number":5,"title":"Test","body":"body","url":"https://github.com/t/r/issues/5","comments":[],"labels":[],"assignees":[]}'
  }
  export -f gh_issue_json

  analyze_issue_for_split() {
    echo '{"should_split":true,"reasoning":"could split","sub_issues":[{"title":"Only one","scope":"scope"}]}'
  }
  export -f analyze_issue_for_split

  safe_repo_main() { echo "/tmp/fakerepo"; }
  export -f safe_repo_main

  require_cmds() { true; }
  export -f require_cmds

  local output
  output="$(cmd_issue_split "fakerepo" "5" --yes 2>/dev/null)"

  assert_contains "treats as no-split" "$output" "No actionable split"

  unset -f gh_issue_json analyze_issue_for_split safe_repo_main require_cmds
}

# ──────────────────────────────────────
# Test: cmd_issue_split unknown flag handling
# ──────────────────────────────────────
test_cmd_split_unknown_flag() {
  printf '\n\033[1m== cmd_issue_split (unknown flag) ==\033[0m\n'

  local exit_code=0
  (cmd_issue_split "fakerepo" "1" --bogus >/dev/null 2>/dev/null) || exit_code=$?

  if [ "$exit_code" -ne 0 ]; then
    pass "dies on unknown flag"
  else
    fail "dies on unknown flag" "expected non-zero exit"
  fi
}

# ──────────────────────────────────────
# Test: create_sub_issues creates issues and posts comment
# ──────────────────────────────────────
test_create_sub_issues() {
  printf '\n\033[1m== create_sub_issues ==\033[0m\n'

  create_issue_in_repo() {
    local repo="$1" title="$2"
    shift 2
    if [ "$title" = "Issue A" ]; then
      printf '101\nhttps://github.com/test/repo/issues/101\n'
    else
      printf '102\nhttps://github.com/test/repo/issues/102\n'
    fi
  }
  export -f create_issue_in_repo

  comment_issue() {
    return 0
  }
  export -f comment_issue

  safe_repo_main() { echo "/tmp/fakerepo"; }
  export -f safe_repo_main

  local json='{"should_split":true,"reasoning":"test","sub_issues":[{"title":"Issue A","scope":"Scope A"},{"title":"Issue B","scope":"Scope B"}]}'

  local output
  output="$(create_sub_issues "fakerepo" "42" "$json" 2>/dev/null)"

  assert_contains "created issue A" "$output" "Issue A"
  assert_contains "created issue B" "$output" "Issue B"
  assert_contains "shows URL" "$output" "https://github.com"

  unset -f create_issue_in_repo comment_issue safe_repo_main
}

# ---- Run tests ----
setup

test_format_recommendation_split
test_format_recommendation_no_split
test_analyze_raw_json
test_analyze_fenced_json
test_analyze_invalid_json
test_cmd_split_no_split
test_cmd_split_too_few_sub_issues
test_cmd_split_unknown_flag
test_create_sub_issues

INTEGRATION="${INTEGRATION:-0}"
if [ "$INTEGRATION" = "1" ]; then
  SPLIT_TEST_REPO="${SPLIT_TEST_REPO:-acorn}"

  test_integration_split_analysis() {
    printf '\n\033[1m== Integration: split analysis ==\033[0m\n'

    local repo_main
    repo_main="$(safe_repo_main "$SPLIT_TEST_REPO")"

    local result issue_num issue_url
    result="$(create_issue_in_repo "$SPLIT_TEST_REPO" \
      "Test split: Add logging AND Add metrics AND Add alerts [CI-TEST]" \
      --body "## Job Story

When monitoring the system, I want logging, metrics, and alerts.

## Scope

1. Add structured logging to all endpoints
2. Add Prometheus metrics collection
3. Add PagerDuty alert integration

These are three independent pieces of work that can be implemented separately.")"

    issue_num="$(printf '%s' "$result" | sed -n '1p')"
    issue_url="$(printf '%s' "$result" | sed -n '2p')"
    info "Created test issue #$issue_num: $issue_url"

    local issue_json
    issue_json="$(gh_issue_json "$repo_main" "$issue_num")"

    local title body
    title="$(printf '%s' "$issue_json" | jq -r '.title')"
    body="$(printf '%s' "$issue_json" | jq -r '.body')"

    local analysis
    analysis="$(analyze_issue_for_split "$title" "$body" "" "claude-sonnet-4-5")"

    local should_split
    should_split="$(printf '%s' "$analysis" | jq -r '.should_split')"
    assert_eq "multi-concern issue should split" "$should_split" "true"

    local sub_count
    sub_count="$(printf '%s' "$analysis" | jq '.sub_issues | length')"
    if [ "$sub_count" -ge 2 ]; then
      pass "at least 2 sub-issues recommended (got $sub_count)"
    else
      fail "at least 2 sub-issues recommended" "got $sub_count"
    fi

    (cd "$repo_main" && gh issue close "$issue_num" --comment "Automated test cleanup") >/dev/null 2>&1 || true
    info "Closed test issue #$issue_num"
  }

  test_integration_split_analysis
else
  printf '\n\033[2mSkipping integration tests (run with INTEGRATION=1 to enable)\033[0m\n'
  printf '\033[2mSet SPLIT_TEST_REPO to override test repository (default: acorn)\033[0m\n'
fi

teardown

printf '\n\033[1mResults: %d passed, %d failed\033[0m\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
