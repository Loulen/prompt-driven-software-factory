#!/bin/sh
# PDSF Tutorial — build your first factory in ~10 minutes, zero tokens.
#
#   curl -fsSL https://raw.githubusercontent.com/Loulen/prompt-driven-software-factory/main/tutorial/tutorial.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/Loulen/prompt-driven-software-factory/<branch>/tutorial/tutorial.sh | PDSF_REF=<branch> sh
#   PDSF_SRC=<local checkout> sh tutorial/tutorial.sh        # offline
#
# Modelled on install.sh: POSIX sh, needs only sh, git and Node 18+. It fetches PDSF into a temp dir
# (no clone needed), creates the tutorial workspace from the blackbelt-lite fixture (a git repo),
# then runs the tutorial app (app/tuto.mjs) on the terminal (/dev/tty, so `curl … | sh` works).
# Re-running it resumes where the learner stopped. It never writes into the PDSF source.
# See tutorial/README.md and ADR-0006.

# Not using `set -e`: critical steps die explicitly.
set -u

PDSF_REF_NAME="${PDSF_REF:-main}"
PDSF_REPO_URL="${PDSF_REPO:-https://github.com/Loulen/prompt-driven-software-factory.git}"
PDSF_TARBALL_URL="${PDSF_TARBALL:-https://codeload.github.com/Loulen/prompt-driven-software-factory/tar.gz/refs/heads/$PDSF_REF_NAME}"
DEFAULT_WORKSPACE="${HOME:-.}/pdsf-tutorial/blackbelt"
EXIT_RESTART=75

log() { printf '%s\n' "PDSF tutorial: $*"; }
die() { printf '%s\n' "PDSF tutorial: error: $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
PDSF Tutorial — build your first factory in ~10 minutes, zero tokens.

USAGE
  curl -fsSL https://raw.githubusercontent.com/Loulen/prompt-driven-software-factory/main/tutorial/tutorial.sh | sh
  PDSF_SRC=<local PDSF checkout> sh tutorial/tutorial.sh      # offline, from a checkout

  Creates a tutorial workspace (~/pdsf-tutorial/blackbelt: the blackbelt-lite fixture in a git repo)
  and opens the tutorial in your terminal: you type the real commands, the agent is SIMULATED.
  Ctrl-C quits at any time; run the same command again to resume. Needs sh, git and Node 18+.

OPTIONS
  -h, --help          Show this help and exit.

ENVIRONMENT
  PDSF_REF            Branch of PDSF to fetch (default: main). Ignored with PDSF_SRC.
  PDSF_SRC            Local PDSF checkout to play the tutorial FROM — fully offline.
  PDSF_TUTO_DIR       Workspace directory. Default: ~/pdsf-tutorial/blackbelt. Must be absent,
                      empty, or a tutorial workspace to resume; outside the PDSF source.
  PDSF_TUTO_SCRIPT    Play without a keyboard: `auto` (the recorded path) or a file of scripted
                      input (see tutorial/README.md § Scripted input).
  PDSF_REPO, PDSF_TARBALL
                      Override the git clone / tarball URLs used when PDSF_SRC is unset.

  Maintainers: PDSF_TUTO_SETUP_ONLY=y stops after creating the workspace (the recorder uses it).
EOF
}

# abspath DIR -> absolute physical path (dir must exist).
abspath() {
  ( cd "$1" 2>/dev/null && pwd -P ) || die "path not found: $1"
}

# ---------------------------------------------------------------------------- source

FETCHED_DIR=""
cleanup() { [ -n "$FETCHED_DIR" ] && rm -rf "$FETCHED_DIR"; return 0; }

# resolve_src -> sets SRC: PDSF_SRC, else a fresh temp clone of PDSF_REF, else its tarball.
resolve_src() {
  if [ -n "${PDSF_SRC:-}" ]; then
    SRC=$(abspath "$PDSF_SRC")
  else
    FETCHED_DIR=$(mktemp -d) || die "mktemp -d failed"
    SRC=""
    log "fetching PDSF ($PDSF_REF_NAME)…"
    if git clone -q --depth 1 --branch "$PDSF_REF_NAME" "$PDSF_REPO_URL" "$FETCHED_DIR/pdsf" </dev/null >/dev/null 2>&1; then
      SRC="$FETCHED_DIR/pdsf"
    elif command -v curl >/dev/null 2>&1; then
      log "git clone failed; trying the tarball…"
      if curl -fsSL "$PDSF_TARBALL_URL" </dev/null | ( cd "$FETCHED_DIR" && tar xzf - ) 2>/dev/null; then
        for _d in "$FETCHED_DIR"/*/; do
          [ -d "$_d/skills" ] && { SRC=${_d%/}; break; }
        done
      fi
    fi
    [ -n "$SRC" ] || die "could not fetch PDSF ($PDSF_REF_NAME). Check PDSF_REF, or set PDSF_SRC=<local checkout> to run offline."
  fi
  [ -f "$SRC/install.sh" ] && [ -d "$SRC/skills" ] || die "$SRC is not a PDSF checkout (no install.sh / skills/)."
  [ -f "$SRC/tutorial/app/tuto.mjs" ] || die "this PDSF source ($SRC) has no tutorial app (tutorial/app/tuto.mjs)."
}

# ---------------------------------------------------------------------------- workspace

# git in the workspace, with a fallback identity when the learner has none configured.
ws_git() {
  if [ -n "$(git -C "$WS" config user.email 2>/dev/null)" ]; then
    git -C "$WS" "$@" </dev/null
  else
    git -C "$WS" -c user.name="PDSF Tutorial" -c user.email="tutorial@pdsf.invalid" "$@" </dev/null
  fi
}

# prepare_workspace -> sets WS: a fresh workspace (fixture + git init, on develop), or the
# tutorial workspace already there (resume).
prepare_workspace() {
  _dir=${PDSF_TUTO_DIR:-$DEFAULT_WORKSPACE}
  if [ -e "$_dir" ] && [ ! -d "$_dir" ]; then
    die "$_dir exists and is not a directory — pick another workspace (PDSF_TUTO_DIR)."
  fi
  if [ -d "$_dir" ] && [ -n "$(ls -A "$_dir" 2>/dev/null)" ]; then
    if [ -f "$_dir/.git/pdsf-tutorial" ]; then
      WS=$(abspath "$_dir")
      log "resuming in $WS"
      return 0
    fi
    die "$_dir is not empty and is not a tutorial workspace. Remove it, or pick another directory (PDSF_TUTO_DIR)."
  fi
  _created=""
  [ -d "$_dir" ] || { mkdir -p "$_dir" || die "cannot create $_dir"; _created=y; }
  WS=$(abspath "$_dir")
  case "$WS/" in
    "$SRC"/*)
      [ -n "$_created" ] && rmdir "$WS"
      die "$WS is inside the PDSF source ($SRC) — the tutorial never writes there. Pick a workspace outside it."
      ;;
  esac
  cp -R "$SRC/tutorial/fixture/blackbelt-lite/." "$WS/" || die "cannot copy the fixture into $WS"
  rm -rf "$WS/.blackbelt-state.json" "$WS/node_modules"
  git init -q "$WS" </dev/null || die "git init failed in $WS"
  git -C "$WS" symbolic-ref HEAD refs/heads/main
  ws_git add -A && ws_git commit -q -m "Blackbelt (lite): initial commit" || die "initial commit failed in $WS"
  # PDSF's git flow: every piece of work starts from develop.
  ws_git checkout -q -b develop || die "creating the develop branch failed in $WS"
  : >"$WS/.git/pdsf-tutorial"
  log "workspace ready: $WS"
}

# reset_workspace — the learner asked to start over: remove the tutorial workspace (only one this
# script created: it carries the marker) and create it again.
reset_workspace() {
  [ -f "$WS/.git/pdsf-tutorial" ] || die "$WS is not a tutorial workspace: not removing it."
  rm -rf "$WS" || die "cannot remove $WS"
  prepare_workspace
}

# ---------------------------------------------------------------------------- main

main() {
  for _a in "$@"; do
    case "$_a" in
      -h|--help) usage; exit 0 ;;
      *) die "unknown argument: $_a (see --help)" ;;
    esac
  done
  command -v git >/dev/null 2>&1 || die "git is required."
  command -v node >/dev/null 2>&1 || die "Node 18+ is required (https://nodejs.org)."
  node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 18 ? 0 : 1)' </dev/null \
    || die "Node 18+ is required (found $(node --version 2>/dev/null))."

  trap cleanup EXIT
  trap 'exit 130' INT TERM
  resolve_src
  prepare_workspace
  if [ "${PDSF_TUTO_SETUP_ONLY:-}" = y ]; then
    printf '%s\n' "$WS"
    exit 0
  fi
  if [ -z "${PDSF_TUTO_SCRIPT:-}" ] && ! { true >/dev/tty; } 2>/dev/null; then
    die "the tutorial needs a terminal. Run it from one (or set PDSF_TUTO_SCRIPT=auto to play the recorded path)."
  fi

  PDSF_TUTO_ROOT="$SRC/tutorial"
  PDSF_TUTO_SRC=$SRC
  PDSF_TUTO_WORKSPACE=$WS
  export PDSF_TUTO_ROOT PDSF_TUTO_SRC PDSF_TUTO_WORKSPACE
  while :; do
    if [ -n "${PDSF_TUTO_SCRIPT:-}" ]; then
      node "$PDSF_TUTO_ROOT/app/tuto.mjs" </dev/null
    else
      node "$PDSF_TUTO_ROOT/app/tuto.mjs" </dev/tty
    fi
    _rc=$?
    [ "$_rc" -eq "$EXIT_RESTART" ] || exit "$_rc"
    reset_workspace
  done
}

main "$@"
