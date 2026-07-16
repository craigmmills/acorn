#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ACORN_SCRIPT="$SCRIPT_DIR/bin/acorn"

eval "$(sed '/^main "\$@"/d' "$ACORN_SCRIPT")"

PASS=0
FAIL=0

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

setup() {
  unset -f gh create_issue_in_repo safe_repo_main ensure_labels set_clarification_label \
    cmd_create require_cmds get_blocking gh_repo_nwo 2>/dev/null || true
}

test_get_blocked_by_fallbacks() {
  printf '\n\033[1m== get_blocked_by fallbacks ==\033[0m\n'

  gh_repo_nwo() { echo "owner/repo"; }
  gh() { echo '[{"number":5}]'; }
  export -f gh gh_repo_nwo

  local out
  out="$(get_blocked_by "/tmp" "42")"
  assert_eq "returns array when valid" "$out" '[{"number":5}]'

  gh() { echo '{"message":"Not Found"}'; }
  export -f gh
  out="$(get_blocked_by "/tmp" "42")"
  assert_eq "non-array returns empty array" "$out" '[]'

  gh() { return 1; }
  export -f gh
  out="$(get_blocked_by "/tmp" "42")"
  assert_eq "api error returns empty array" "$out" '[]'
}

test_add_blocked_by_validation() {
  printf '\n\033[1m== add_blocked_by_dependency validation ==\033[0m\n'

  gh() { :; }
  export -f gh

  local rc=0
  set +e
  add_blocked_by_dependency "/tmp" "10" "abc" >/dev/null 2>/dev/null
  rc=$?
  set -e
  assert_eq "rejects non-numeric" "$rc" "1"

  set +e
  add_blocked_by_dependency "/tmp" "10" "0" >/dev/null 2>/dev/null
  rc=$?
  set -e
  assert_eq "rejects zero" "$rc" "1"

  set +e
  add_blocked_by_dependency "/tmp" "10" "10" >/dev/null 2>/dev/null
  rc=$?
  set -e
  assert_eq "rejects self-dependency" "$rc" "1"
}

test_detect_circular_dependency() {
  printf '\n\033[1m== detect_circular_dependency ==\033[0m\n'

  get_blocked_by() {
    local _repo_main="$1"
    local issue="$2"
    case "$issue" in
      2) echo '[{"number":3}]' ;;
      3) echo '[{"number":1}]' ;;
      *) echo '[]' ;;
    esac
  }
  gh_repo_nwo() { echo "owner/repo"; }
  export -f get_blocked_by gh_repo_nwo

  local rc=0
  set +e
  detect_circular_dependency "/tmp" "1" "2" "owner/repo" >/dev/null
  rc=$?
  set -e
  assert_eq "detects cycle" "$rc" "0"

  get_blocked_by() {
    local _repo_main="$1"
    local issue="$2"
    case "$issue" in
      2) echo '[{"number":4}]' ;;
      4) echo '[]' ;;
      *) echo '[]' ;;
    esac
  }
  export -f get_blocked_by

  set +e
  detect_circular_dependency "/tmp" "1" "2" "owner/repo" >/dev/null
  rc=$?
  set -e
  assert_eq "allows acyclic" "$rc" "1"
}

test_cmd_issue_create_blocked_by() {
  printf '\n\033[1m== cmd_issue_create --blocked-by ==\033[0m\n'

  create_issue_in_repo() { echo -e "77\nhttps://example/issues/77"; }
  safe_repo_main() { echo "/tmp/repo"; }
  ensure_labels() { :; }
  set_issue_state_label() { :; }
  set_clarification_label() { :; }

  local seen_file
  seen_file="$(mktemp)"
  add_blocked_by_bulk() {
    printf '%s|%s|%s|%s' "$1" "$2" "$3" "$4" > "$seen_file"
  }

  output="$(cmd_issue_create "repo" "Title" --blocked-by "5,12" --raw 2>/dev/null)"
  local seen
  seen="$(cat "$seen_file")"
  rm -f "$seen_file"

  assert_contains "create output includes issue" "$output" "Issue: #77"
  assert_eq "blocked-by forwarded" "$seen" "/tmp/repo|77|5|12"
}

test_cmd_issue_plan_blocked_by_and_flags() {
  printf '\n\033[1m== cmd_issue_plan --blocked-by + create flags ==\033[0m\n'

  create_issue_in_repo() { echo -e "88\nhttps://example/issues/88"; }
  safe_repo_main() { echo "/tmp/repo"; }
  ensure_labels() { :; }
  set_issue_state_label() { :; }
  set_clarification_label() { :; }
  local seen_dep=""
  add_blocked_by_bulk() { seen_dep="$1|$2|$3|$4"; }
  local seen_create=""
  cmd_create() { seen_create="$1|$2|$3|$4"; }

  cmd_issue_plan "repo" "Plan title" --blocked-by "9,10" --lite --no-run --raw >/dev/null 2>&1
  assert_eq "plan blocked-by forwarded" "$seen_dep" "/tmp/repo|88|9|10"
  assert_eq "plan create flags forwarded" "$seen_create" "repo|88|--lite|--no-run"
}

test_cmd_issue_depends_view() {
  printf '\n\033[1m== cmd_issue_depends view/add/remove ==\033[0m\n'

  require_cmds() { :; }
  safe_repo_main() { echo "/tmp/repo"; }
  gh_repo_nwo() { echo "owner/repo"; }

  local removed_file added_file
  removed_file="$(mktemp)"
  added_file="$(mktemp)"

  remove_blocked_by_dependency() { printf '%s\n' "$3" >> "$removed_file"; }
  detect_circular_dependency() { return 1; }
  add_blocked_by_dependency() { printf '%s\n' "$3" >> "$added_file"; }

  get_blocked_by() { echo '[{"number":5,"title":"A","state":"OPEN"}]'; }
  get_blocking() { echo '[{"number":11,"title":"B","state":"OPEN"}]'; }

  local output
  output="$(cmd_issue_depends "repo" "42" --remove-blocked-by "2" --blocked-by "5,6")"

  local removed added
  removed="$(tr '\n' ',' < "$removed_file" | sed 's/,$//')"
  added="$(tr '\n' ',' < "$added_file" | sed 's/,$//')"
  rm -f "$removed_file" "$added_file"

  assert_contains "shows blocked by section" "$output" "Blocked by:"
  assert_contains "shows blocks section" "$output" "Blocks:"
  assert_eq "remove called" "$removed" "2"
  assert_eq "add called" "$added" "5,6"
}

test_main_dispatch_list_deps() {
  printf '\n\033[1m== main dispatch list --deps ==\033[0m\n'

  local seen=""
  cmd_list() { seen="$1"; }

  main list --deps >/dev/null 2>&1
  assert_eq "list dispatch passes flag" "$seen" "--deps"
}

setup

test_get_blocked_by_fallbacks
setup
test_add_blocked_by_validation
setup
test_detect_circular_dependency
setup
test_cmd_issue_create_blocked_by
setup
test_cmd_issue_plan_blocked_by_and_flags
setup
test_cmd_issue_depends_view
setup
test_main_dispatch_list_deps

printf '\n\033[1mResults: %d passed, %d failed\033[0m\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
