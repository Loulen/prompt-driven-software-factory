#!/bin/sh
# PDSF Tutorial — discover PDSF and build your first factory, step by step.
#
#   curl -fsSL https://raw.githubusercontent.com/Loulen/prompt-driven-software-factory/main/tutorial/tutorial.sh | sh
#   PDSF_SRC=<local checkout> sh tutorial/tutorial.sh        # offline
#
# Modelled on install.sh: POSIX sh, zero dependency (git + node for the fixture), fetches PDSF into a
# temp dir (no clone needed), talks through /dev/tty so `curl … | sh` stays interactive, and every
# prompt is answered by a PDSF_TUTO_* env var when it is set (see --help, tutorial/README.md).
#
# It creates a fresh tutorial workspace from the blackbelt-lite fixture, installs PDSF into it for
# real, then hands over to a tutorial mode (tutorial/modes/<id>/). It never writes into the PDSF
# source. See ADR-0006.

# Not using `set -e`: the ask control flow relies on non-zero returns. Critical steps die explicitly.
set -u

PDSF_REPO_URL="${PDSF_REPO:-https://github.com/Loulen/prompt-driven-software-factory.git}"
PDSF_TARBALL_URL="${PDSF_TARBALL:-https://codeload.github.com/Loulen/prompt-driven-software-factory/tar.gz/refs/heads/main}"
TUTO_README_URL="https://github.com/Loulen/prompt-driven-software-factory/tree/main/tutorial"
DEFAULT_WORKSPACE="./pdsf-tutorial-workspace"

# Used before the scenario library is loaded (it comes with the resolved source).
log() { printf '%s\n' "PDSF tutorial: $*"; }
die() { printf '%s\n' "PDSF tutorial: error: $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
PDSF Tutorial — discover PDSF and build your first factory, step by step.

USAGE
  curl -fsSL https://raw.githubusercontent.com/Loulen/prompt-driven-software-factory/main/tutorial/tutorial.sh | sh
  PDSF_SRC=<local PDSF checkout> sh tutorial/tutorial.sh      # offline, from a checkout

  Creates a throwaway workspace seeded with the blackbelt-lite fixture, installs PDSF into it for
  real, then offers the tutorial modes. Needs sh, git, and node 18+ (for the fixture's tests).

OPTIONS
  -h, --help          Show this help and exit.

ENVIRONMENT (each also asked interactively when unset; set it — even empty — to skip the prompt)
  PDSF_TUTO_DIR       Workspace directory. Default: ./pdsf-tutorial-workspace. Must be absent or
                      empty, and outside the PDSF source.
  PDSF_TUTO_HARNESS   Harness layout: `claude` (or 2, default) = .agents + .claude symlinks;
                      `generic` (or 1) = .agents only. Passed to install.sh as PDSF_HARNESS.
  PDSF_TUTO_MODE      Tutorial mode: its number in the menu, its id (e.g. a1) or its folder name.
                      Default: the first shipped mode. Empty: stop after the setup.
  PDSF_TUTO_SKIP_CH2  `y` to skip chapter 2 (Use the factory). Default: n.
  PDSF_TUTO_SKIP_CH3  `y` to skip chapter 3 (Go further). Default: n.
  PDSF_TUTO_PAUSE     `n` to never wait for Enter between steps. Default: y.
  PDSF_SRC            Local PDSF checkout to play the tutorial FROM — fully offline.
  PDSF_REPO, PDSF_TARBALL
                      Override the git clone / tarball URLs used when PDSF_SRC is unset.

  Modes may read more PDSF_TUTO_* variables: see tutorial/README.md.
EOF
}

# abspath DIR -> absolute physical path (dir must exist).
abspath() {
  ( cd "$1" 2>/dev/null && pwd -P ) || die "path not found: $1"
}

# ---------------------------------------------------------------------------- source

FETCHED_DIR=""
cleanup() { [ -n "$FETCHED_DIR" ] && rm -rf "$FETCHED_DIR"; return 0; }

# resolve_src -> sets SRC: PDSF_SRC, else a fresh temp clone, else a tarball.
resolve_src() {
  if [ -n "${PDSF_SRC:-}" ]; then
    SRC=$(abspath "$PDSF_SRC")
  else
    FETCHED_DIR=$(mktemp -d) || die "mktemp -d failed"
    SRC=""
    if command -v git >/dev/null 2>&1; then
      log "fetching PDSF (git clone --depth 1 $PDSF_REPO_URL)…"
      if git clone -q --depth 1 "$PDSF_REPO_URL" "$FETCHED_DIR/pdsf" </dev/null >/dev/null 2>&1; then
        SRC="$FETCHED_DIR/pdsf"
      else
        log "git clone failed; trying the tarball…"
      fi
    fi
    if [ -z "$SRC" ] && command -v curl >/dev/null 2>&1; then
      log "fetching PDSF (curl tarball)…"
      if curl -fsSL "$PDSF_TARBALL_URL" </dev/null | ( cd "$FETCHED_DIR" && tar xzf - ) 2>/dev/null; then
        for _d in "$FETCHED_DIR"/*/; do
          [ -d "$_d/skills" ] && { SRC=${_d%/}; break; }
        done
      fi
    fi
    [ -n "$SRC" ] || die "could not fetch PDSF. Set PDSF_SRC=<local checkout> to run offline."
  fi
  [ -f "$SRC/install.sh" ] && [ -d "$SRC/skills" ] || die "$SRC is not a PDSF checkout (no install.sh / skills/)."
  [ -f "$SRC/tutorial/lib/scenario.sh" ] || die "this PDSF source ($SRC) has no tutorial/."
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

create_workspace() {
  _dir=$(tuto_ask PDSF_TUTO_DIR "Workspace directory ($DEFAULT_WORKSPACE): " "$DEFAULT_WORKSPACE")
  [ -n "$_dir" ] || _dir=$DEFAULT_WORKSPACE
  if [ -e "$_dir" ] && [ ! -d "$_dir" ]; then
    die "$_dir exists and is not a directory — pick another workspace (PDSF_TUTO_DIR)."
  fi
  if [ -d "$_dir" ] && [ -n "$(ls -A "$_dir" 2>/dev/null)" ]; then
    die "$_dir is not empty — the tutorial needs a fresh directory. Remove it, or pick another one (PDSF_TUTO_DIR)."
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

  cp -R "$PDSF_TUTO_ROOT/fixture/blackbelt-lite/." "$WS/" || die "cannot copy the fixture into $WS"
  rm -rf "$WS/.blackbelt-state.json" "$WS/node_modules"
  git init -q "$WS" </dev/null || die "git init failed in $WS"
  git -C "$WS" symbolic-ref HEAD refs/heads/main
  ws_git add -A && ws_git commit -q -m "Blackbelt (lite): initial commit" || die "initial commit failed in $WS"

  tuto_rule "Your tutorial workspace"
  tuto_say "$WS"
  tuto_say "A fresh git repo holding Blackbelt (lite): consultants climb belts, WHITE → BLACK, in a"
  tuto_say "discipline, coached by a mentor. Its README pitches it; its tests run with plain node:"
  tuto_say ""
  if command -v node >/dev/null 2>&1; then
    if ( cd "$WS" && node --test </dev/null >/dev/null 2>&1 ); then
      tuto_say "  ✓ node --test — the fixture's tests pass (no npm install needed)"
    else
      tuto_say "  ✗ node --test failed in the workspace — check your node version (18+)."
    fi
  else
    tuto_say "  ! node not found — install Node 18+ to run Blackbelt and its tests."
  fi
  tuto_say ""
}

# ---------------------------------------------------------------------------- harness + install

choose_harness() {
  tuto_rule "Installing PDSF: the harness layout"
  cat <<'EOF'
PDSF's skills are plain markdown folders. The installer puts them in ONE place and tells your
agent ("harness": Claude Code, Copilot, Cursor, Codex…) where to find them. It asks one question,
the layout:

  [1] .agents                     generic: skills in .agents/skills/ + a wired AGENTS.md.
                                  AGENTS.md is the cross-harness standard most agents read.
  [2] .agents + .claude symlinks  the same, plus a thin overlay so Claude Code finds its own
                                  paths: .claude/skills -> .agents/skills, CLAUDE.md -> AGENTS.md.
                                  Still one copy of the skills: only symlinks are added.

On your project: pick [2] if anyone uses Claude Code, [1] otherwise. Here, [2] is the default.
EOF
  tuto_say ""
  _h=$(tuto_ask PDSF_TUTO_HARNESS "Harness layout [1/2] (2): " "2")
  case "$_h" in
    ""|2|claude) HARNESS=claude ;;
    1|generic|.agents) HARNESS=generic ;;
    *) die "unknown harness layout '$_h' (1|generic, 2|claude)" ;;
  esac
  export PDSF_TUTO_HARNESS="$HARNESS"
}

install_pdsf() {
  _step="$PDSF_TUTO_SCENARIO/01-build-the-factory/01-install"
  tuto_dim "\$ PDSF_HARNESS=$HARNESS sh install.sh $WS"
  tuto_dim "  (the real installer, from the resolved PDSF source; on your project: curl … install.sh | sh)"
  tuto_run_action "$_step" || die "install.sh failed in $WS"
  ws_git add -A && ws_git commit -q -m "Install PDSF (install.sh, harness: $HARNESS)" || die "committing the install failed"
  ws_git branch develop && ws_git checkout -q develop || die "creating the develop branch failed"
  tuto_say ""
  tuto_say "Check:"
  tuto_run_check "$_step" || die "the install did not produce the expected layout (see the ✗ lines above)."
  tuto_say ""
  tuto_say "The install is committed on main, and you are now on develop: in PDSF's git flow, every"
  tuto_say "piece of work starts from develop."
  tuto_say ""
}

# ---------------------------------------------------------------------------- modes

where_next() {
  tuto_rule "Where to look next"
  tuto_md "$(tuto_width)" <<EOF
  * Your workspace: $WS. Open AGENTS.md and .agents/skills/<skill>/SKILL.md: that is exactly what
    your agent reads.
  * The tutorial (scenario, modes, how it works): $TUTO_README_URL
  * PDSF: the README (the method, every skill) and docs/INSTALL.md (every install option).
  * On your project: run install.sh, then /build-factory. Run /verify-factory any time to see
    where a factory stands and what to do next.
EOF
}

# resolve_mode CHOICE MODES -> prints the mode directory for a number, a short id or a folder name.
resolve_mode() {
  _choice=$1; _modes=$2; _i=0
  for _m in $_modes; do
    _i=$((_i + 1))
    if [ "$_choice" = "$_i" ] || [ "$_choice" = "$(tuto_mode_id "$_m")" ] || [ "$_choice" = "${_m##*/}" ]; then
      printf '%s' "$_m"; return 0
    fi
  done
  return 1
}

choose_and_play_mode() {
  tuto_rule "Tutorial modes"
  _modes=$(tuto_modes)
  if [ -z "$_modes" ]; then
    tuto_say "No tutorial mode is shipped yet in this version of PDSF, so the tutorial stops here,"
    tuto_say "after the setup. Your workspace is ready: Blackbelt, with PDSF installed."
    tuto_say ""
    where_next
    return 0
  fi

  _i=0
  for _m in $_modes; do
    _i=$((_i + 1))
    tuto_say "  [$_i] $(tuto_meta "$_m/mode.md" title)  ($(tuto_mode_id "$_m"))"
    tuto_meta "$_m/mode.md" summary | tuto_md "$(tuto_width)" "      "
  done
  tuto_say ""
  _choice=$(tuto_ask PDSF_TUTO_MODE "Mode [1-$_i] (1): " "1")
  if [ -z "$_choice" ]; then
    tuto_say "No mode chosen: the tutorial stops after the setup."
    tuto_say ""
    where_next
    return 0
  fi
  _mode=$(resolve_mode "$_choice" "$_modes") || die "unknown tutorial mode '$_choice' (pick a number, an id or a folder name from the menu)."

  for _c in $(tuto_chapters); do
    [ "$(tuto_meta "$_c/chapter.md" skippable)" = true ] || continue
    _n=$(tuto_chapter_number "$_c")
    _skip=$(tuto_ask "PDSF_TUTO_SKIP_CH$_n" "Skip $(tuto_meta "$_c/chapter.md" title)? [y/N]: " "n")
    if tuto_is_yes "$_skip"; then _skip=y; else _skip=n; fi
    eval "PDSF_TUTO_SKIP_CH$_n=\$_skip; export PDSF_TUTO_SKIP_CH$_n"
  done

  PDSF_TUTO_MODE=$(tuto_mode_id "$_mode")
  PDSF_TUTO_PAUSE=${PDSF_TUTO_PAUSE:-y}
  export PDSF_TUTO_MODE PDSF_TUTO_PAUSE
  tuto_say ""
  if tuto_has_tty; then
    ( cd "$WS" && sh "$_mode/play.sh" </dev/tty )
  else
    ( cd "$WS" && sh "$_mode/play.sh" </dev/null )
  fi
  _rc=$?
  tuto_say ""
  where_next
  return "$_rc"
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

  trap cleanup EXIT
  trap 'exit 130' INT TERM
  resolve_src
  PDSF_TUTO_SRC=$SRC
  PDSF_TUTO_ROOT="$SRC/tutorial"
  export PDSF_TUTO_SRC PDSF_TUTO_ROOT
  # shellcheck source=lib/scenario.sh
  . "$PDSF_TUTO_ROOT/lib/scenario.sh"

  tuto_rule "PDSF Tutorial"
  cat <<'EOF'
Learn PDSF by building a factory on a small, realistic project: Blackbelt (lite).
  1. Build the factory   install PDSF, /build-factory (scaffold, then context), /verify-factory
  2. Use the factory     one business story, from /grill-with-docs to /implement
  3. Go further          where to look next, PDO (optional)
Nothing is written outside the workspace this script creates.

EOF
  create_workspace
  export PDSF_TUTO_WORKSPACE="$WS"
  choose_harness
  install_pdsf
  choose_and_play_mode
}

main "$@"
