#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
FOCUS="$ROOT_DIR/focus"
TEST_DIR=$(mktemp -d)
HOSTS_FILE="$TEST_DIR/hosts"
SITES_FILE="$TEST_DIR/sites"

cleanup() {
  rm -rf -- "$TEST_DIR"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

run_focus() {
  OMARCHY_FOCUS_TESTING=1 \
    OMARCHY_FOCUS_HOSTS_FILE="$HOSTS_FILE" \
    OMARCHY_FOCUS_SITES_FILE="$SITES_FILE" \
    "$FOCUS" "$@"
}

assert_count() {
  local expected="$1"
  local pattern="$2"
  local count=""
  count=$(grep -Fxc "$pattern" "$HOSTS_FILE" || true)
  [[ $count == "$expected" ]] || fail "expected $expected copies of '$pattern', found $count"
}

printf '127.0.0.1 localhost\n192.0.2.1 keep.example\n' >"$HOSTS_FILE"
cat >"$SITES_FILE" <<'SITES'
# Comments and whitespace are accepted.
  Example.com
www.example.com
example.com
SITES

if run_focus status >/dev/null; then
  fail "focus mode should start inactive"
fi

run_focus on >/dev/null
run_focus status >/dev/null || fail "focus mode should be active"
assert_count 1 "# >>> omarchy-focus >>>"
assert_count 1 "# <<< omarchy-focus <<<"
assert_count 1 "127.0.0.1 example.com"
assert_count 1 "::1 example.com"
grep -Fxq '192.0.2.1 keep.example' "$HOSTS_FILE" || fail "unmanaged hosts entry was removed"

run_focus on >/dev/null
assert_count 1 "# >>> omarchy-focus >>>"
assert_count 1 "127.0.0.1 example.com"

run_focus toggle >/dev/null
if run_focus status >/dev/null; then
  fail "toggle should turn focus mode off"
fi
grep -Fq 'omarchy-focus' "$HOSTS_FILE" && fail "managed markers remain after toggle off"
grep -Fxq '192.0.2.1 keep.example' "$HOSTS_FILE" || fail "unmanaged hosts entry was removed"

printf '127.0.0.1 localhost\n127.0.0.1 legacy.example # focus-block\n' >"$HOSTS_FILE"
run_focus on >/dev/null
grep -Fq '# focus-block' "$HOSTS_FILE" && fail "legacy entries were not removed"

printf 'bad domain\n' >"$SITES_FILE"
before=$(sha256sum "$HOSTS_FILE" | cut -d' ' -f1)
if run_focus on >/dev/null 2>&1; then
  fail "invalid domain should fail"
fi
after=$(sha256sum "$HOSTS_FILE" | cut -d' ' -f1)
[[ $before == "$after" ]] || fail "invalid configuration changed the hosts file"

printf 'example.com\n' >"$SITES_FILE"
printf '127.0.0.1 localhost\n# >>> omarchy-focus >>>\n127.0.0.1 broken.example\n' >"$HOSTS_FILE"
before=$(sha256sum "$HOSTS_FILE" | cut -d' ' -f1)
if run_focus off >/dev/null 2>&1; then
  fail "malformed markers should fail"
fi
after=$(sha256sum "$HOSTS_FILE" | cut -d' ' -f1)
[[ $before == "$after" ]] || fail "malformed markers changed the hosts file"

echo "focus tests passed"
