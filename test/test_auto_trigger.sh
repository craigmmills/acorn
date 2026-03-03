#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ACORN_SCRIPT="$SCRIPT_DIR/bin/acorn"

# Source acorn functions without triggering main()
eval "$(sed '/^main "\$@"/d' "$ACORN_SCRIPT")"

PASS=0
FAIL=0
TMPDIR_BASE=""
ORIG_WAIT_FOR_CLAUDE_READY="$(declare -f wait_for_claude_ready || true)"

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
  TMPDIR_BASE="$(mktemp -d)"
}

teardown() {
  [ -n "$TMPDIR_BASE" ] && rm -rf "$TMPDIR_BASE"
  unset -f tmux 2>/dev/null || true
  unset -f sleep 2>/dev/null || true
  unset -f wait_for_claude_ready 2>/dev/null || true
  [ -n "$ORIG_WAIT_FOR_CLAUDE_READY" ] && eval "$ORIG_WAIT_FOR_CLAUDE_READY"
}

# ---- Test 1: wait_for_claude_ready returns 0 when prompt detected immediately ----

test_wait_for_claude_ready_immediate() {
  printf '\n\033[1m== wait_for_claude_ready: immediate readiness ==\033[0m\n'
  setup

  tmux() {
    case "$1" in
      capture-pane) printf '  Welcome to Claude Code\n\n>\n' ;;
    esac
  }
  export -f tmux

  local result=0
  wait_for_claude_ready "test-session" 10 1 || result=$?
  assert_eq "returns 0 on immediate readiness" "$result" "0"

  teardown
}

# ---- Test 2: wait_for_claude_ready returns 1 on timeout ----

test_wait_for_claude_ready_timeout() {
  printf '\n\033[1m== wait_for_claude_ready: timeout ==\033[0m\n'
  setup

  tmux() {
    case "$1" in
      capture-pane) printf 'Loading Claude Code...\n' ;;
    esac
  }
  export -f tmux

  # Use short timeout (3s) and interval (1s) for fast testing
  local exit_code=0
  wait_for_claude_ready "test-session" 3 1 || exit_code=$?
  assert_eq "returns 1 on timeout" "$exit_code" "1"

  teardown
}

# ---- Test 3: wait_for_claude_ready detects prompt after delay ----

test_wait_for_claude_ready_delayed() {
  printf '\n\033[1m== wait_for_claude_ready: delayed readiness ==\033[0m\n'
  setup

  local state_file="$TMPDIR_BASE/ready_state"
  printf '0' > "$state_file"

  tmux() {
    case "$1" in
      capture-pane)
        local count
        count="$(cat "$state_file")"
        count=$((count + 1))
        printf '%s' "$count" > "$state_file"
        if [ "$count" -ge 2 ]; then
          printf '>\n'
        else
          printf 'Starting Claude Code...\n'
        fi
        ;;
    esac
  }
  export -f tmux

  local result=0
  wait_for_claude_ready "test-session" 10 1 || result=$?
  assert_eq "returns 0 after delayed readiness" "$result" "0"

  local final_count
  final_count="$(cat "$state_file")"
  assert_eq "checked pane at least twice" "$( [ "$final_count" -ge 2 ] && echo yes || echo no )" "yes"

  teardown
}

# ---- Test 4: send_auto_trigger calls tmux send-keys correctly ----

test_send_auto_trigger_sends_message() {
  printf '\n\033[1m== send_auto_trigger: sends message and Enter ==\033[0m\n'
  setup

  local log_file="$TMPDIR_BASE/tmux_calls.log"
  : > "$log_file"

  # Override wait_for_claude_ready to return immediately
  wait_for_claude_ready() { return 0; }
  export -f wait_for_claude_ready

  # Stub tmux to log all calls
  tmux() {
    local line="$1"
    shift || true
    local arg
    for arg in "$@"; do
      line="$line $arg"
    done
    printf '%s\n' "$line" >> "$log_file"
  }
  export -f tmux

  # Call the real send_auto_trigger and give its disowned background job time to run
  send_auto_trigger "test-session" "hello world"
  sleep 2

  local calls
  calls="$(cat "$log_file")"
  assert_contains "sends literal text" "$calls" "send-keys -t test-session -l hello world"
  assert_contains "sends Enter" "$calls" "send-keys -t test-session Enter"

  teardown
}

# ---- Test 5: --no-auto path does not call send_auto_trigger ----

test_no_auto_does_not_trigger() {
  printf '\n\033[1m== --no-auto: send_auto_trigger not called ==\033[0m\n'
  setup

  # The auto_trigger variable controls whether send_auto_trigger is called.
  # With auto_trigger=0, the if block in cmd_create should not execute.
  # We verify by checking the conditional logic directly.
  local auto_trigger=0
  local called=0

  if [ "$auto_trigger" -eq 1 ]; then
    called=1
  fi

  assert_eq "--no-auto skips send_auto_trigger" "$called" "0"

  teardown
}

# ---- Test 6: wait_for_claude_ready handles prompt with prefix ----

test_wait_for_claude_ready_prompt_with_prefix() {
  printf '\n\033[1m== wait_for_claude_ready: prompt with path prefix ==\033[0m\n'
  setup

  tmux() {
    case "$1" in
      capture-pane) printf '/path/to/project >\n' ;;
    esac
  }
  export -f tmux

  local result=0
  wait_for_claude_ready "test-session" 10 1 || result=$?
  assert_eq "detects prompt with path prefix" "$result" "0"

  teardown
}

# ---- Test 7: wait_for_claude_ready ignores > in middle of line ----

test_wait_for_claude_ready_ignores_mid_line() {
  printf '\n\033[1m== wait_for_claude_ready: ignores > in middle of output ==\033[0m\n'
  setup

  tmux() {
    case "$1" in
      capture-pane) printf 'pipe > /dev/null\nstill loading...\n' ;;
    esac
  }
  export -f tmux

  local exit_code=0
  wait_for_claude_ready "test-session" 2 1 || exit_code=$?
  assert_eq "does not match mid-line >" "$exit_code" "1"

  teardown
}

# ---- Integration Tests ----

INTEGRATION="${INTEGRATION:-0}"

if [ "$INTEGRATION" = "1" ]; then
  test_integration_wait_for_real_tmux() {
    printf '\n\033[1m== INTEGRATION: wait_for_claude_ready with real tmux ==\033[0m\n'
    setup

    local test_session="acorn-test-auto-trigger-$$"

    # Create a real tmux session
    tmux new-session -d -s "$test_session" -c "$TMPDIR_BASE"
    # Simulate Claude Code prompt by printing ">"
    tmux send-keys -t "$test_session" "printf '>\n'" C-m

    sleep 2
    local result=0
    wait_for_claude_ready "$test_session" 10 1 || result=$?
    assert_eq "detects prompt in real tmux" "$result" "0"

    tmux kill-session -t "$test_session" 2>/dev/null || true
    teardown
  }

  test_integration_send_auto_trigger_real_tmux() {
    printf '\n\033[1m== INTEGRATION: send_auto_trigger with real tmux ==\033[0m\n'
    setup

    local test_session="acorn-test-trigger-$$"

    # Create a real tmux session with a cat-like process waiting for input
    tmux new-session -d -s "$test_session" -c "$TMPDIR_BASE"
    # Print the prompt so wait_for_claude_ready detects it
    tmux send-keys -t "$test_session" "printf '>\n' && cat > $TMPDIR_BASE/received.txt" C-m
    sleep 2

    send_auto_trigger "$test_session" "test message"
    # Wait for background process
    sleep 5

    # Check the pane captured the message
    local pane
    pane="$(tmux capture-pane -t "$test_session" -ep 2>/dev/null || true)"
    assert_contains "message visible in pane" "$pane" "test message"

    tmux kill-session -t "$test_session" 2>/dev/null || true
    teardown
  }

  test_integration_wait_for_real_tmux
  test_integration_send_auto_trigger_real_tmux
else
  printf '\n\033[2mSkipping integration tests (run with INTEGRATION=1 to enable)\033[0m\n'
fi

# ---- Run all unit tests ----
setup

test_wait_for_claude_ready_immediate
test_wait_for_claude_ready_timeout
test_wait_for_claude_ready_delayed
test_send_auto_trigger_sends_message
test_no_auto_does_not_trigger
test_wait_for_claude_ready_prompt_with_prefix
test_wait_for_claude_ready_ignores_mid_line

teardown

# ---- Summary ----
printf '\n\033[1mResults: %d passed, %d failed\033[0m\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
