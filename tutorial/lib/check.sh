# PDSF Tutorial — helpers for step checks (POSIX sh, sourced by scenario/*/*/check.sh).
#
# A check runs in the workspace. Each expectation prints a ✓ / ✗ line; `check_done` exits non-zero
# when any expectation failed, so the check's status is the step's verdict.

_check_failed=0

check_ok()   { printf '  ✓ %s\n' "$1"; }
check_fail() { printf '  ✗ %s\n' "$1"; _check_failed=1; }

# check_that "description" command [args…] — pass when the command succeeds. The command gets no
# terminal: stdin is /dev/null (a tool that sees a tty, like `node --test`, would write to it).
check_that() {
  _ct_what=$1; shift
  if "$@" </dev/null >/dev/null 2>&1; then check_ok "$_ct_what"; else check_fail "$_ct_what"; fi
}

check_file() { check_that "${2:-$1 exists}" test -f "$1"; }
check_dir()  { check_that "${2:-$1/ exists}" test -d "$1"; }

# check_grep FILE PATTERN "description" — FILE exists and matches the (extended, case-insensitive)
# PATTERN.
check_grep() { check_that "$3" grep -qiE "$2" "$1"; }

# check_link LINK TARGET — LINK is a symlink whose target is exactly TARGET.
check_link() {
  if [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ]; then
    check_ok "$1 -> $2 (symlink)"
  else
    check_fail "$1 -> $2 (symlink)"
  fi
}

# check_any "description" GLOB — at least one path matches GLOB.
check_any() {
  _ca_what=$1; shift
  for _ca in "$@"; do
    [ -e "$_ca" ] && { check_ok "$_ca_what"; return 0; }
  done
  check_fail "$_ca_what"
}

check_done() { exit "$_check_failed"; }
