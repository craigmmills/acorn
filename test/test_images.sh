#!/usr/bin/env bash
set -euo pipefail

# Test suite for image extraction feature (issues #10, #12)
# Usage: bash test/test_images.sh

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ACORN_SCRIPT="$SCRIPT_DIR/bin/acorn"

# Source acorn functions without triggering main()
eval "$(sed '/^main "\$@"/d' "$ACORN_SCRIPT")"

PASS=0
FAIL=0
TMPDIR_BASE=""

setup() {
  TMPDIR_BASE="$(mktemp -d)"
}

teardown() {
  [ -n "$TMPDIR_BASE" ] && rm -rf "$TMPDIR_BASE"
}

pass() {
  PASS=$((PASS + 1))
  printf '  \033[32mPASS\033[0m %s\n' "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  printf '  \033[31mFAIL\033[0m %s — %s\n' "$1" "$2"
}

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$label"
  else
    fail "$label" "expected '$expected', got '$actual'"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    pass "$label"
  else
    fail "$label" "expected to contain '$needle'"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    fail "$label" "expected NOT to contain '$needle'"
  else
    pass "$label"
  fi
}

assert_file_exists() {
  local path="$1" label="$2"
  if [ -f "$path" ]; then
    pass "$label"
  else
    fail "$label" "file not found: $path"
  fi
}

assert_file_not_empty() {
  local path="$1" label="$2"
  if [ -s "$path" ]; then
    pass "$label"
  else
    fail "$label" "file is empty or missing: $path"
  fi
}

assert_dir_empty() {
  local path="$1" label="$2"
  if [ -d "$path" ] && [ -z "$(ls -A "$path" 2>/dev/null)" ]; then
    pass "$label"
  else
    fail "$label" "directory not empty or missing: $path"
  fi
}

# ─────────────────────────────────────────────────
# Tests: bash -n syntax check
# ─────────────────────────────────────────────────

test_syntax_check() {
  printf '\n\033[1m== Syntax Check ==\033[0m\n'
  if bash -n "$ACORN_SCRIPT" 2>/dev/null; then
    pass "bash -n bin/acorn"
  else
    fail "bash -n bin/acorn" "syntax error"
  fi
}

# ─────────────────────────────────────────────────
# Tests: get_extension_from_url
# ─────────────────────────────────────────────────

test_get_extension_from_url() {
  printf '\n\033[1m== get_extension_from_url ==\033[0m\n'

  assert_eq "$(get_extension_from_url "https://example.com/img.png")" "png" \
    "basic .png"

  assert_eq "$(get_extension_from_url "https://example.com/img.jpg")" "jpg" \
    "basic .jpg"

  assert_eq "$(get_extension_from_url "https://example.com/img.jpeg")" "jpeg" \
    "basic .jpeg"

  assert_eq "$(get_extension_from_url "https://example.com/img.gif")" "gif" \
    "basic .gif"

  assert_eq "$(get_extension_from_url "https://example.com/img.webp")" "webp" \
    "basic .webp"

  assert_eq "$(get_extension_from_url "https://example.com/img.svg")" "svg" \
    "basic .svg"

  assert_eq "$(get_extension_from_url "https://example.com/img.PNG")" "png" \
    "uppercase .PNG normalized to lowercase"

  assert_eq "$(get_extension_from_url "https://example.com/img.png?raw=true")" "png" \
    "strips query params"

  assert_eq "$(get_extension_from_url "https://example.com/img.png#section")" "png" \
    "strips fragment"

  assert_eq "$(get_extension_from_url "https://example.com/img.png?raw=true#top")" "png" \
    "strips query params and fragment"

  assert_eq "$(get_extension_from_url "https://github.com/user-attachments/assets/abc-def-123")" "png" \
    "unknown extension defaults to png"

  assert_eq "$(get_extension_from_url "https://example.com/no-ext")" "png" \
    "no extension defaults to png"
}

# ─────────────────────────────────────────────────
# Tests: generate_image_filename
# ─────────────────────────────────────────────────

test_generate_image_filename() {
  printf '\n\033[1m== generate_image_filename ==\033[0m\n'

  local result
  result="$(generate_image_filename "https://example.com/test.jpg")"

  # Should end with .jpg
  assert_eq "${result##*.}" "jpg" \
    "filename ends with correct extension"

  # Should be deterministic
  local result2
  result2="$(generate_image_filename "https://example.com/test.jpg")"
  assert_eq "$result" "$result2" \
    "deterministic: same URL produces same filename"

  # Different URLs produce different filenames
  local result3
  result3="$(generate_image_filename "https://example.com/other.jpg")"
  if [ "$result" != "$result3" ]; then
    pass "different URLs produce different filenames"
  else
    fail "different URLs produce different filenames" "got same filename for different URLs"
  fi

  # UUID URL defaults to .png
  local result4
  result4="$(generate_image_filename "https://github.com/user-attachments/assets/abc-123")"
  assert_eq "${result4##*.}" "png" \
    "UUID URL defaults to .png extension"
}

# ─────────────────────────────────────────────────
# Tests: extract_image_urls
# ─────────────────────────────────────────────────

test_extract_image_urls() {
  printf '\n\033[1m== extract_image_urls ==\033[0m\n'

  # Single image in body
  local json='{"body":"![screenshot](https://example.com/img.png)","comments":[]}'
  local urls
  urls="$(extract_image_urls "$json")"
  assert_eq "$urls" "https://example.com/img.png" \
    "single image URL from body"

  # Multiple images in body
  json='{"body":"![a](https://example.com/one.png) text ![b](https://example.com/two.jpg)","comments":[]}'
  urls="$(extract_image_urls "$json")"
  local count
  count="$(printf '%s\n' "$urls" | wc -l | tr -d ' ')"
  assert_eq "$count" "2" \
    "multiple image URLs from body"

  # Image in comments
  json='{"body":"no images here","comments":[{"author":{"login":"user"},"createdAt":"2026-01-01","body":"![comment-img](https://example.com/comment.png)"}]}'
  urls="$(extract_image_urls "$json")"
  assert_eq "$urls" "https://example.com/comment.png" \
    "image URL from comment"

  # GitHub asset UUID URL (no extension)
  json='{"body":"![upload](https://github.com/user-attachments/assets/abcdef12-3456-7890-abcd-ef1234567890)","comments":[]}'
  urls="$(extract_image_urls "$json")"
  assert_contains "$urls" "github.com/user-attachments/assets/" \
    "GitHub asset UUID URL extracted"

  # No images
  json='{"body":"just text, no images","comments":[]}'
  urls="$(extract_image_urls "$json")" || true
  assert_eq "${urls:-}" "" \
    "no images returns empty"

  # Empty body
  json='{"body":"","comments":[]}'
  urls="$(extract_image_urls "$json")" || true
  assert_eq "${urls:-}" "" \
    "empty body returns empty"

  # Deduplication
  json='{"body":"![a](https://example.com/dup.png) ![b](https://example.com/dup.png)","comments":[]}'
  urls="$(extract_image_urls "$json")"
  count="$(printf '%s\n' "$urls" | wc -l | tr -d ' ')"
  assert_eq "$count" "1" \
    "duplicate URLs deduplicated"

  # Image with title attribute
  json='{"body":"![alt](https://example.com/titled.png \"my title\")","comments":[]}'
  urls="$(extract_image_urls "$json")"
  assert_eq "$urls" "https://example.com/titled.png" \
    "image with title attribute: URL extracted without title"

  # Non-image URL ignored
  json='{"body":"[link](https://example.com/page.html)","comments":[]}'
  urls="$(extract_image_urls "$json")" || true
  assert_eq "${urls:-}" "" \
    "non-image markdown link ignored"

  # Mixed: image + regular link
  json='{"body":"![img](https://example.com/pic.png) and [link](https://example.com/page)","comments":[]}'
  urls="$(extract_image_urls "$json")"
  assert_eq "$urls" "https://example.com/pic.png" \
    "only image URLs extracted, regular links ignored"
}

# ─────────────────────────────────────────────────
# Tests: rewrite_image_urls_in_text
# ─────────────────────────────────────────────────

test_rewrite_image_urls_in_text() {
  printf '\n\033[1m== rewrite_image_urls_in_text ==\033[0m\n'

  local mapping_file="$TMPDIR_BASE/mapping.tsv"

  # Basic rewrite
  printf 'https://example.com/img.png\timages/abc123.png\n' > "$mapping_file"
  local result
  result="$(rewrite_image_urls_in_text '![screenshot](https://example.com/img.png)' "$mapping_file")"
  assert_eq "$result" '![screenshot](images/abc123.png)' \
    "basic URL rewrite"

  # Preserves alt text
  result="$(rewrite_image_urls_in_text '![my alt text](https://example.com/img.png)' "$mapping_file")"
  assert_contains "$result" "![my alt text]" \
    "preserves alt text"

  # Multiple URLs in mapping
  printf 'https://example.com/one.png\timages/one.png\nhttps://example.com/two.jpg\timages/two.jpg\n' > "$mapping_file"
  result="$(rewrite_image_urls_in_text 'See ![a](https://example.com/one.png) and ![b](https://example.com/two.jpg)' "$mapping_file")"
  assert_contains "$result" "images/one.png" \
    "multiple rewrites: first URL"
  assert_contains "$result" "images/two.jpg" \
    "multiple rewrites: second URL"
  assert_not_contains "$result" "example.com" \
    "multiple rewrites: no original URLs remain"

  # Duplicate references in text
  printf 'https://example.com/dup.png\timages/dup.png\n' > "$mapping_file"
  result="$(rewrite_image_urls_in_text '![a](https://example.com/dup.png) ![b](https://example.com/dup.png)' "$mapping_file")"
  local dup_count
  dup_count="$(printf '%s' "$result" | grep -o 'images/dup.png' | wc -l | tr -d ' ')"
  assert_eq "$dup_count" "2" \
    "duplicate references both rewritten"

  # No mapping file — returns text unchanged
  result="$(rewrite_image_urls_in_text '![img](https://example.com/img.png)' "")"
  assert_eq "$result" '![img](https://example.com/img.png)' \
    "no mapping file: text unchanged"

  # Empty mapping file — returns text unchanged
  : > "$TMPDIR_BASE/empty.tsv"
  result="$(rewrite_image_urls_in_text '![img](https://example.com/img.png)' "$TMPDIR_BASE/empty.tsv")"
  assert_eq "$result" '![img](https://example.com/img.png)' \
    "empty mapping file: text unchanged"

  # Missing mapping file — returns text unchanged
  result="$(rewrite_image_urls_in_text '![img](https://example.com/img.png)' "$TMPDIR_BASE/nonexistent.tsv")"
  assert_eq "$result" '![img](https://example.com/img.png)' \
    "missing mapping file: text unchanged"

  # URLs with special chars
  printf 'https://example.com/img.png?raw=true&v=2\timages/special.png\n' > "$mapping_file"
  result="$(rewrite_image_urls_in_text '![img](https://example.com/img.png?raw=true&v=2)' "$mapping_file")"
  assert_eq "$result" '![img](images/special.png)' \
    "URLs with query params rewritten correctly"
}

# ─────────────────────────────────────────────────
# Tests: extract_and_download_images
# ─────────────────────────────────────────────────

test_extract_and_download_images() {
  printf '\n\033[1m== extract_and_download_images ==\033[0m\n'

  local images_dir="$TMPDIR_BASE/images"

  # No images — returns empty mapping, no error
  local json='{"body":"just text","comments":[]}'
  local mapping_file
  mapping_file="$(extract_and_download_images "$json" "$images_dir" 2>/dev/null)"
  assert_file_exists "$mapping_file" \
    "no images: mapping file created"
  if [ ! -s "$mapping_file" ]; then
    pass "no images: mapping file is empty"
  else
    fail "no images: mapping file is empty" "mapping file has content"
  fi
  rm -f "$mapping_file"

  # stdout only contains the mapping file path (no info contamination)
  json='{"body":"just text","comments":[]}'
  local stdout_output
  stdout_output="$(extract_and_download_images "$json" "$images_dir" 2>/dev/null)"
  # stdout should be a valid file path, no [INFO] prefix
  assert_not_contains "$stdout_output" "[INFO]" \
    "stdout not contaminated by info()"
  if [ -f "$stdout_output" ]; then
    pass "stdout is a valid file path"
  else
    fail "stdout is a valid file path" "got: $stdout_output"
  fi
  rm -f "$stdout_output"

  # Download a real public image
  json='{"body":"![bash](https://raw.githubusercontent.com/github/explore/main/topics/bash/bash.png)","comments":[]}'
  mapping_file="$(extract_and_download_images "$json" "$images_dir" 2>/dev/null)"
  assert_file_exists "$mapping_file" \
    "real download: mapping file created"
  if [ -s "$mapping_file" ]; then
    pass "real download: mapping file has content"
    local downloaded_relpath
    downloaded_relpath="$(cut -f2 "$mapping_file" | head -1)"
    # relative_path is "images/<hash>.ext", images_dir is already the images/ dir
    local downloaded_filename="${downloaded_relpath#images/}"
    assert_file_not_empty "$images_dir/$downloaded_filename" \
      "real download: image file exists and not empty"
  else
    fail "real download: mapping file has content" "mapping is empty"
  fi
  rm -f "$mapping_file"

  # Broken URL — graceful failure, empty mapping
  rm -rf "$TMPDIR_BASE/images_broken"
  json='{"body":"![broken](https://httpbin.org/status/404.png)","comments":[]}'
  mapping_file="$(extract_and_download_images "$json" "$TMPDIR_BASE/images_broken" 2>/dev/null)"
  if [ ! -s "$mapping_file" ]; then
    pass "broken URL: mapping file empty (download failed gracefully)"
  else
    fail "broken URL: mapping file empty" "mapping has content"
  fi
  rm -f "$mapping_file"

  # Idempotent — second run skips already downloaded
  rm -rf "$TMPDIR_BASE/images_idem"
  json='{"body":"![bash](https://raw.githubusercontent.com/github/explore/main/topics/bash/bash.png)","comments":[]}'
  mapping_file="$(extract_and_download_images "$json" "$TMPDIR_BASE/images_idem" 2>/dev/null)"
  rm -f "$mapping_file"
  # Run again — should see "already exists" on stderr
  local stderr_output
  stderr_output="$(extract_and_download_images "$json" "$TMPDIR_BASE/images_idem" 2>&1 1>/dev/null)" || true
  assert_contains "$stderr_output" "already exists" \
    "idempotent: second run detects existing file"
  # Clean up mapping from second run
  mapping_file="$(extract_and_download_images "$json" "$TMPDIR_BASE/images_idem" 2>/dev/null)"
  rm -f "$mapping_file"
}

# ─────────────────────────────────────────────────
# Tests: VISUAL ASSETS in planning blocks
# ─────────────────────────────────────────────────

test_visual_assets_in_planning_blocks() {
  printf '\n\033[1m== VISUAL ASSETS in planning blocks ==\033[0m\n'

  local count
  count="$(grep -c "VISUAL ASSETS" "$ACORN_SCRIPT")"
  assert_eq "$count" "3" \
    "VISUAL ASSETS appears exactly 3 times in bin/acorn"

  count="$(grep -c "If __SPEC_PATH__/images/ exists" "$ACORN_SCRIPT")"
  assert_eq "$count" "3" \
    "image examination bullet appears exactly 3 times"

  # Verify __SPEC_PATH__ gets substituted in each mode
  local output

  output="$(planning_block_full "/test/my-spec")"
  assert_contains "$output" "/test/my-spec/images/" \
    "full mode: __SPEC_PATH__ substituted in image instruction"
  assert_contains "$output" "VISUAL ASSETS" \
    "full mode: VISUAL ASSETS preamble present"

  output="$(planning_block_lite "/test/my-spec")"
  assert_contains "$output" "/test/my-spec/images/" \
    "lite mode: __SPEC_PATH__ substituted in image instruction"
  assert_contains "$output" "VISUAL ASSETS" \
    "lite mode: VISUAL ASSETS preamble present"

  output="$(planning_block_quick "/test/my-spec")"
  assert_contains "$output" "/test/my-spec/images/" \
    "quick mode: __SPEC_PATH__ substituted in image instruction"
  assert_contains "$output" "VISUAL ASSETS" \
    "quick mode: VISUAL ASSETS preamble present"
}

# ─────────────────────────────────────────────────
# Integration test: full acorn create with real issue
# ─────────────────────────────────────────────────

test_integration_acorn_create_with_image() {
  printf '\n\033[1m== Integration: acorn create with image issue ==\033[0m\n'

  local repo="acorn"
  local image_url="https://raw.githubusercontent.com/github/explore/main/topics/bash/bash.png"
  local issue_number=""
  local slug=""
  local spec_dir=""
  local cleanup_needed=0

  # Create a real GitHub issue with an image
  printf '  Creating test issue with image...\n'
  local issue_url
  issue_url="$(gh issue create -R craigmmills/acorn \
    --title "[TEST] Image extraction integration test" \
    --body "$(cat <<EOF
## Test Issue

This issue tests the image extraction pipeline.

![bash logo](${image_url})

Some text after the image.
EOF
)" 2>&1)" || {
    fail "integration: create test issue" "gh issue create failed: $issue_url"
    return
  }

  issue_number="$(printf '%s' "$issue_url" | grep -oE '[0-9]+$')"
  if [ -z "$issue_number" ]; then
    fail "integration: create test issue" "could not extract issue number from: $issue_url"
    return
  fi
  cleanup_needed=1
  pass "integration: created test issue #$issue_number"

  # Run acorn create with --no-auto to avoid launching a planning session
  printf '  Running acorn create --no-auto...\n'
  local create_output
  create_output="$("$ACORN_SCRIPT" create "$repo" "$issue_number" --no-auto --lite 2>&1)" || {
    fail "integration: acorn create" "command failed: $create_output"
    # Clean up issue
    gh issue close "$issue_number" -R craigmmills/acorn --comment "Test complete (create failed)" >/dev/null 2>&1
    gh issue delete "$issue_number" -R craigmmills/acorn --yes >/dev/null 2>&1 || true
    return
  }
  pass "integration: acorn create succeeded"

  # Determine spec slug and directory
  slug="$(ls -1 "$HOME/Projects/acorn/main/.specs/" 2>/dev/null | grep "^${issue_number}-")"
  if [ -z "$slug" ]; then
    fail "integration: find spec directory" "no .specs/${issue_number}-* directory found"
    gh issue close "$issue_number" -R craigmmills/acorn --comment "Test complete (no spec dir)" >/dev/null 2>&1
    gh issue delete "$issue_number" -R craigmmills/acorn --yes >/dev/null 2>&1 || true
    return
  fi
  spec_dir="$HOME/Projects/acorn/main/.specs/$slug"
  pass "integration: spec directory exists at .specs/$slug"

  # Check images directory has a downloaded file
  local image_count
  image_count="$(ls -1 "$spec_dir/images/" 2>/dev/null | grep -cE '\.(png|jpg|jpeg|gif|webp|svg)$' || echo 0)"
  if [ "$image_count" -gt 0 ]; then
    pass "integration: image downloaded ($image_count file(s) in images/)"
  else
    fail "integration: image downloaded" "images/ directory is empty"
  fi

  # Check that at least one image file is non-empty
  local any_nonempty=0
  for f in "$spec_dir/images/"*; do
    [ -f "$f" ] && [ -s "$f" ] && any_nonempty=1 && break
  done
  if [ "$any_nonempty" -eq 1 ]; then
    pass "integration: downloaded image file is non-empty"
  else
    fail "integration: downloaded image file is non-empty" "all files empty or missing"
  fi

  # Check PROMPT.md exists
  assert_file_exists "$spec_dir/PROMPT.md" \
    "integration: PROMPT.md generated"

  # Check PROMPT.md contains rewritten local path (images/...)
  local prompt_content
  prompt_content="$(cat "$spec_dir/PROMPT.md")"
  assert_contains "$prompt_content" "images/" \
    "integration: PROMPT.md contains local image path"

  # Check original remote URL is NOT in PROMPT.md (was rewritten)
  assert_not_contains "$prompt_content" "$image_url" \
    "integration: original URL rewritten (not in PROMPT.md)"

  # Check PROMPT.md still has the planning methodology anchor
  assert_contains "$prompt_content" "PLANNING METHODOLOGY" \
    "integration: PROMPT.md has planning methodology block"

  # Check PROMPT.md has VISUAL ASSETS instruction
  assert_contains "$prompt_content" "VISUAL ASSETS" \
    "integration: PROMPT.md has VISUAL ASSETS instruction"

  # ── Cleanup ──
  printf '  Cleaning up...\n'

  # Kill tmux session if it exists
  local session_name
  session_name="$(jq -r '.session_name // ""' "$spec_dir/meta.json" 2>/dev/null || true)"
  if [ -n "$session_name" ]; then
    tmux kill-session -t "$session_name" 2>/dev/null || true
  fi

  # Remove spec directory
  rm -rf "$spec_dir"

  # Close and delete the test issue
  gh issue close "$issue_number" -R craigmmills/acorn --comment "Automated test complete — cleaning up" >/dev/null 2>&1 || true
  gh issue delete "$issue_number" -R craigmmills/acorn --yes >/dev/null 2>&1 || true

  pass "integration: cleanup complete"
}

# ─────────────────────────────────────────────────
# Run all tests
# ─────────────────────────────────────────────────

INTEGRATION="${INTEGRATION:-0}"

printf '\033[1mRunning image feature tests...\033[0m\n'
setup

test_syntax_check
test_get_extension_from_url
test_generate_image_filename
test_extract_image_urls
test_rewrite_image_urls_in_text
test_extract_and_download_images
test_visual_assets_in_planning_blocks

if [ "$INTEGRATION" = "1" ]; then
  test_integration_acorn_create_with_image
else
  printf '\n\033[2mSkipping integration test (run with INTEGRATION=1 to enable)\033[0m\n'
fi

teardown

printf '\n\033[1m──────────────────────────────\033[0m\n'
printf '\033[32m%d passed\033[0m, \033[31m%d failed\033[0m\n' "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
