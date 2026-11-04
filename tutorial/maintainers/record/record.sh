#!/bin/sh
# PDSF Tutorial — the recorder: (re-)records the simulated steps from a REAL run of the PDSF skills.
#
# For maintainers only; the learner never runs it. It drives a real, non-interactive Claude Code
# session (`claude -p`, one call per learner turn, `--resume` in between) in a tutorial workspace,
# then stores the step's recording: transcript.md + files/ (format: tutorial/README.md
# § Recordings). It spends tokens.
#
#   sh tutorial/maintainers/record/record.sh prepare STEP WS
#                                                    fresh workspace WS, in the state just before STEP
#                                                    (setup + install run for real, earlier steps
#                                                    replayed)
#   sh tutorial/maintainers/record/record.sh turn WS [--continue] [--choices "A | B"] MESSAGE
#                                                    one learner turn (the first one: the command),
#                                                    sent to the real agent; prints its answer.
#                                                    --continue (first turn only): stay in the
#                                                    previous step's agent session, as a learner
#                                                    typing the next command in the same session
#   sh tutorial/maintainers/record/record.sh finish STEP WS
#                                                    writes STEP's recording from the session, commits
#                                                    what the agent left, runs the step's check
#   sh tutorial/maintainers/record/record.sh run STEP WS
#                                                    re-plays STEP's recorded learner turns against
#                                                    the real agent, then `finish` (WS prepared)
#   sh tutorial/maintainers/record/record.sh all WS  prepare + `run` of every recorded step, in order
#   sh tutorial/maintainers/record/record.sh steps   lists the recorded steps (STEP ids)
#
# STEP is a step folder id under tutorial/scenario/, e.g. 01-build-the-factory/02-scaffold (it holds
# the step's check.sh; scenario.json points at it with `dir`). After a re-recording, check that the
# condensed `play` of that step in scenario.json still says what the new transcript says (the
# scenario linter checks that each question still points at a recorded answer). Environment:
#   PDSF_RECORD_CLAUDE   the agent command (default: claude)
#   PDSF_RECORD_MODEL    passed as --model (default: the CLI's default model)
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
REPO=$(cd "$HERE/../../.." && pwd -P)
PDSF_TUTO_ROOT="$REPO/tutorial"
PDSF_TUTO_SRC=$REPO
export PDSF_TUTO_ROOT PDSF_TUTO_SRC
. "$PDSF_TUTO_ROOT/lib/scenario.sh"
. "$PDSF_TUTO_ROOT/lib/recording.sh"

CLAUDE_CMD=${PDSF_RECORD_CLAUDE:-claude}
HARNESS=claude   # the tutorial installs the .agents + .claude symlinks layout

die() { printf '%s\n' "record: error: $*" >&2; exit 1; }
log() { printf '%s\n' "record: $*" >&2; }

usage() { sed -n '2,/^set -u/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }

# step_dir STEP_ID -> the step directory (dies when it has no check.sh).
step_dir() {
  _sd="$PDSF_TUTO_SCENARIO/$1"
  [ -f "$_sd/check.sh" ] || die "no step '$1' with a check.sh under tutorial/scenario/ (see: record.sh steps)"
  printf '%s' "${_sd%/}"
}

agent_steps() { tuto_recorded_steps; }

# step_command STEP_DIR -> the command the recording starts with: the first learner turn of the
# session being recorded (as typed, arguments included), else the current recording's `command:`.
step_command() {
  _cmd=""
  [ -n "${STATE:-}" ] && [ -f "$STATE/001-learner.turn" ] && _cmd=$(head -n 1 "$STATE/001-learner.turn")
  [ -n "$_cmd" ] || { tuto_has_recording "$1" && _cmd=$(rec_meta "$1" command); }
  printf '%s' "$_cmd"
}

# step_title STEP_DIR -> the recording's title (from its heading), else the folder's slug.
step_title() {
  _t=""
  tuto_has_recording "$1" && _t=$(sed -n 's/^# Recording — \(.*\) (`.*`)$/\1/p' "$(rec_transcript "$1")" | head -n 1)
  [ -n "$_t" ] || { _t=${1##*/}; _t=${_t#*-}; }
  printf '%s' "$_t"
}

use_ws() {
  [ -d "$1/.git" ] || die "$1 is not a prepared workspace (run: record.sh prepare STEP $1)"
  PDSF_TUTO_WORKSPACE=$(cd "$1" && pwd -P)
  PDSF_TUTO_HARNESS=$HARNESS
  export PDSF_TUTO_WORKSPACE PDSF_TUTO_HARNESS
  STATE="$PDSF_TUTO_WORKSPACE/.git/pdsf-record"
  LAST_SESSION="$PDSF_TUTO_WORKSPACE/.git/pdsf-record-last-session"
}

# ---------------------------------------------------------------------------- prepare

cmd_prepare() {
  [ $# -eq 2 ] || die "usage: record.sh prepare STEP WS"
  _target=$(step_dir "$1"); _ws=$2
  [ ! -e "$_ws" ] || [ -z "$(ls -A "$_ws" 2>/dev/null)" ] || die "$_ws is not empty"
  mkdir -p "$_ws" && _ws=$(cd "$_ws" && pwd -P)
  log "setting up $_ws with tutorial.sh, then the real install…"
  ( cd "$(dirname "$_ws")" && env PDSF_SRC="$REPO" PDSF_TUTO_DIR="$_ws" PDSF_TUTO_SETUP_ONLY=y \
      sh "$PDSF_TUTO_ROOT/tutorial.sh" ) </dev/null >/dev/null 2>&1 \
    || die "tutorial.sh failed to set up $_ws"
  use_ws "$_ws"
  _install="$PDSF_TUTO_SCENARIO/01-build-the-factory/01-install"
  tuto_run_action "$_install" >/dev/null 2>&1 || die "the install failed in $_ws"
  tuto_run_check "$_install" >/dev/null || die "the install check fails in $_ws"
  for _s in $(agent_steps); do
    # Steps are replayed in folder order, up to the target (which may not be recorded yet).
    _first=$(printf '%s\n%s\n' "$_s" "$_target" | LC_ALL=C sort | head -n 1)
    [ "$_s" = "$_target" ] || [ "$_first" = "$_target" ] && break
    log "replaying $(tuto_step_id "$_s")…"
    rec_apply "$_s" || die "replaying $(tuto_step_id "$_s") failed"
    tuto_run_check "$_s" >/dev/null || die "$(tuto_step_id "$_s")'s check fails after its replay"
  done
  log "ready: $_ws is in the state just before $(tuto_step_id "$_target")."
  _next=$(step_command "$_target")
  log "next: record.sh turn $_ws \"${_next:-/<command>}\""
}

# ---------------------------------------------------------------------------- turn

# agent CLI, outside any parent Claude Code session (a nested `claude` must start its own).
run_agent() {
  (
    unset CLAUDECODE CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_SESSION_ID CLAUDE_CODE_CHILD_SESSION \
      CLAUDE_CODE_SESSION_ATTENDED CLAUDE_CODE_MESSAGING_SOCKET CLAUDE_CODE_MESSAGING_TOKEN \
      CLAUDE_CODE_EXECPATH CLAUDE_PID AI_AGENT 2>/dev/null
    cd "$PDSF_TUTO_WORKSPACE" || exit 1
    # No auto-memory: the recorded agent must not write outside the throwaway workspace, nor carry
    # what a previous recording taught it (a learner's agent starts without those memories).
    CLAUDE_CODE_DISABLE_AUTO_MEMORY=1; export CLAUDE_CODE_DISABLE_AUTO_MEMORY
    # shellcheck disable=SC2086
    $CLAUDE_CMD -p "$@" --output-format stream-json --verbose \
      --permission-mode bypassPermissions --strict-mcp-config \
      ${PDSF_RECORD_MODEL:+--model "$PDSF_RECORD_MODEL"} </dev/null
  )
}

cmd_turn() {
  [ $# -ge 2 ] || die "usage: record.sh turn WS [--continue] [--choices \"A | B\"] MESSAGE"
  use_ws "$1"; shift
  _choices=""; _continue=""
  if [ "$1" = --continue ]; then _continue=y; shift; fi
  if [ "$1" = --choices ]; then _choices=$2; shift 2; fi
  [ $# -eq 1 ] && [ -n "$1" ] || die "one non-empty MESSAGE expected"
  _msg=$1
  mkdir -p "$STATE/raw"
  if [ -n "$_continue" ]; then
    [ ! -f "$STATE/start" ] || die "--continue is for the first turn of a step only"
    [ -f "$LAST_SESSION" ] || die "no previous step's session to continue in $PDSF_TUTO_WORKSPACE"
    cp "$LAST_SESSION" "$STATE/session" && : >"$STATE/continued"
  fi
  if [ ! -f "$STATE/start" ]; then
    rec_git rev-parse HEAD >"$STATE/start"
    rec_git for-each-ref --format='%(refname:short)' refs/heads >"$STATE/branches-before"
  fi
  _n=$(ls "$STATE" | grep -c '\.turn$')
  _n=$((_n + 1))
  _id=$(printf '%03d' "$_n")
  printf '%s\n' "$_msg" >"$STATE/$_id-learner.turn"
  [ -n "$_choices" ] && printf '%s\n' "$_choices" >"$STATE/$_id-learner.choices"

  if [ -f "$STATE/session" ]; then
    run_agent "$_msg" --resume "$(cat "$STATE/session")" >"$STATE/raw/$_id.jsonl" 2>"$STATE/raw/$_id.err"
  else
    run_agent "$_msg" >"$STATE/raw/$_id.jsonl" 2>"$STATE/raw/$_id.err"
  fi
  _rc=$?
  _a=$(printf '%03d' $((_n + 1)))
  node "$HERE/stream-turn.mjs" "$PDSF_TUTO_WORKSPACE" "$STATE/meta" <"$STATE/raw/$_id.jsonl" >"$STATE/$_a-agent.turn" \
    || die "could not read the agent's output ($STATE/raw/$_id.jsonl)"
  _session=$(sed -n 's/^session=//p' "$STATE/meta")
  [ -n "$_session" ] && printf '%s\n' "$_session" >"$STATE/session"
  for _k in model version; do
    _v=$(sed -n "s/^$_k=//p" "$STATE/meta")
    [ -n "$_v" ] && printf '%s\n' "$_v" >"$STATE/$_k"
  done
  _err=$(sed -n 's/^error=//p' "$STATE/meta")
  if [ "$_rc" -ne 0 ] || [ -n "$_err" ] || [ -z "$_session" ]; then
    rm -f "$STATE/$_id-learner.turn" "$STATE/$_id-learner.choices" "$STATE/$_a-agent.turn"
    die "the agent run failed (exit $_rc${_err:+: $_err}); see $STATE/raw/$_id.err — the turn was not kept"
  fi
  cat "$STATE/$_a-agent.turn"
}

# ---------------------------------------------------------------------------- finish

cmd_finish() {
  [ $# -eq 2 ] || die "usage: record.sh finish STEP WS"
  _step=$(step_dir "$1"); use_ws "$2"
  [ -f "$STATE/start" ] || die "no recorded session in $2 (run: record.sh turn $2 \"/<command>\")"
  _start=$(cat "$STATE/start")
  _rec="$_step/recording"

  # What the agent committed itself names the replayed commit; what it left uncommitted is committed
  # here, so the next step (recorded or replayed) starts from the same state.
  _msg=$(rec_git log --no-merges -1 --format=%s "$_start..HEAD" 2>/dev/null)
  _command=$(step_command "$_step"); _title=$(step_title "$_step")
  [ -n "$_msg" ] || _msg="$_command: $_title"
  if [ -n "$(rec_git status --porcelain)" ]; then
    rec_git add -A && rec_git commit -q -m "$_msg" || die "committing what the agent left failed"
  fi
  [ "$HARNESS" != claude ] || [ -L "$PDSF_TUTO_WORKSPACE/CLAUDE.md" ] \
    || die "CLAUDE.md is no longer a symlink to AGENTS.md: the agent replaced it — fix the workspace, then finish again"

  rm -rf "$_rec"
  mkdir -p "$_rec/files"
  _removed=""
  rec_git diff --name-status --no-renames "$_start" HEAD | while IFS="$(printf '\t')" read -r _st _path; do
    case "$_path" in .claude/*|CLAUDE.md) continue ;; esac
    case "$_st" in
      D) printf '%s\n' "$_path" >>"$STATE/removed" ;;
      *) mkdir -p "$_rec/files/$(dirname "$_path")" && cp -P "$PDSF_TUTO_WORKSPACE/$_path" "$_rec/files/$_path" ;;
    esac
  done
  [ -f "$STATE/removed" ] && _removed=$(tr '\n' ' ' <"$STATE/removed" | sed 's/ $//')
  [ -n "$(ls -A "$_rec/files")" ] || rmdir "$_rec/files"

  _branch=$(rec_git symbolic-ref --short -q HEAD)
  _branches=$(rec_git for-each-ref --format='%(refname:short)' refs/heads | grep -vxF -f "$STATE/branches-before" | grep -vxF "$_branch" | tr '\n' ' ' | sed 's/ $//')
  # A new branch the run committed on, then merged into the end branch (e.g. /implement's
  # feature/* auto-merged into integration/*): the replay works on it and merges it the same way.
  _via=""; _merge=""
  for _b in $_branches; do
    if [ -n "$(rec_git rev-list "$_start..$_b")" ] && rec_git merge-base --is-ancestor "$_b" HEAD \
       && [ -n "$(rec_git rev-list --merges "$_start..HEAD")" ]; then
      _via=$_b
      _merge=$(rec_git log --merges -1 --format=%s "$_start..HEAD")
      _msg=$(rec_git log --no-merges -1 --format=%s "$_start..$_b")
      _branches=$(printf '%s\n' $_branches | grep -vxF "$_b" | tr '\n' ' ' | sed 's/ $//')
      break
    fi
  done
  _version=$(cat "$STATE/version" 2>/dev/null); _model=$(cat "$STATE/model" 2>/dev/null)
  _pdsf=$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null)

  {
    printf -- '---\n'
    printf 'step: %s\n' "$(tuto_step_id "$_step")"
    printf 'command: %s\n' "$_command"
    printf 'branch: %s\n' "$_branch"
    printf 'commit: %s\n' "$_msg"
    if [ -f "$STATE/continued" ]; then printf 'session: continued\n'; else printf 'session: new\n'; fi
    printf 'via:%s\n' "${_via:+ $_via}"
    printf 'merge:%s\n' "${_merge:+ $_merge}"
    printf 'branches:%s\n' "${_branches:+ $_branches}"
    printf 'removed:%s\n' "${_removed:+ $_removed}"
    printf 'recorded: %s\n' "$(date +%Y-%m-%d)"
    printf 'recorder: Claude Code %s, %s\n' "${_version:-?}" "${_model:-?}"
    printf 'pdsf: %s\n' "${_pdsf:-?}"
    printf 'harness: %s\n' "$HARNESS"
    printf 'format: 1\n'
    printf -- '---\n\n'
    printf '# Recording — %s (`%s`)\n\n' "$_title" "$_command"
    printf 'A real run of the PDSF skill on a fresh blackbelt-lite tutorial workspace, recorded with\n'
    printf '`tutorial/maintainers/record/record.sh`. The files it produced are in `files/`. Format and\n'
    printf 're-recording procedure: `tutorial/README.md` § Recordings.\n'
    for _t in "$STATE"/*.turn; do
      case "$_t" in
        *-learner.turn)
          printf '\n<!-- pdsf-turn: learner -->\n'
          _c="${_t%.turn}.choices"
          [ -f "$_c" ] && printf '<!-- pdsf-choices: %s -->\n' "$(cat "$_c")"
          printf '### You\n\n' ;;
        *) printf '\n<!-- pdsf-turn: agent -->\n### Agent\n\n' ;;
      esac
      cat "$_t"
    done
  } >"$_rec/transcript.md"
  cp "$STATE/session" "$LAST_SESSION" 2>/dev/null
  rm -rf "$STATE"

  log "recorded $(tuto_step_id "$_step"): $(rec_turn_count "$_step") turns, $(rec_files "$_step" | wc -l | tr -d ' ') files, branch $_branch"
  log "step check:"
  tuto_run_check "$_step" >&2 || die "$(tuto_step_id "$_step")'s check FAILS on the recorded state: re-record it (answers in its transcript.md)"
}

# ---------------------------------------------------------------------------- run / all

cmd_run() {
  [ $# -eq 2 ] || die "usage: record.sh run STEP WS"
  _rstep=$(step_dir "$1"); _rws=$2; use_ws "$_rws"
  tuto_has_recording "$_rstep" || die "$1 has no transcript to take the learner's answers from: drive it with \`turn\`"
  [ ! -f "$STATE/start" ] || die "a session is already in progress in $_rws (finish it, or rm -rf $STATE)"
  # The learner turns are the script; keep them before the recording is rewritten.
  _cont=""
  [ "$(rec_meta "$_rstep" session)" = continued ] && _cont=--continue
  _script=$(mktemp -d)
  _count=$(rec_turn_count "$_rstep"); _i=1; _k=0
  while [ "$_i" -le "$_count" ]; do
    if [ "$(rec_turn_role "$_rstep" "$_i")" = learner ]; then
      _k=$((_k + 1))
      rec_turn_text "$_rstep" "$_i" >"$_script/$_k.msg"
      rec_turn_choices "$_rstep" "$_i" | paste -sd'|' - | sed 's/|/ | /g' >"$_script/$_k.choices"
    fi
    _i=$((_i + 1))
  done
  _j=1
  while [ "$_j" -le "$_k" ]; do
    log "turn $_j/$_k: $(head -n 1 "$_script/$_j.msg")"
    _first=""; [ "$_j" -eq 1 ] && _first=$_cont
    if [ -n "$(cat "$_script/$_j.choices")" ]; then
      ( cmd_turn "$_rws" $_first --choices "$(cat "$_script/$_j.choices")" "$(cat "$_script/$_j.msg")" ) || { rm -rf "$_script"; exit 1; }
    else
      ( cmd_turn "$_rws" $_first "$(cat "$_script/$_j.msg")" ) || { rm -rf "$_script"; exit 1; }
    fi
    _j=$((_j + 1))
  done
  rm -rf "$_script"
  cmd_finish "$1" "$_rws"
}

cmd_all() {
  [ $# -eq 1 ] || die "usage: record.sh all WS"
  _first=$(agent_steps | head -n 1)
  ( cmd_prepare "$(tuto_step_id "$_first")" "$1" ) || exit 1
  for _s in $(agent_steps); do
    ( cmd_run "$(tuto_step_id "$_s")" "$1" ) || exit 1
  done
}

case "${1:-}" in
  prepare) shift; cmd_prepare "$@" ;;
  turn) shift; cmd_turn "$@" ;;
  finish) shift; cmd_finish "$@" ;;
  run) shift; cmd_run "$@" ;;
  all) shift; cmd_all "$@" ;;
  steps) for _s in $(agent_steps); do tuto_step_id "$_s"; printf '\n'; done ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
