# PDSF Tutorial — the guide skill's interface to its lesson plan (POSIX sh).
#
#   sh .agents/skills/pdsf-tutorial/tuto.sh plan | next | chapter N | show STEP | action STEP
#                                           | check STEP | skip N y|n
#
# Copied into the tutorial workspace by mode B (tutorial/modes/b-real-agent/play.sh), next to the
# scenario and lib/ it reads. STEP is a step id (01-build-the-factory/02-scaffold) or its short
# form (1.2). Progress lives in .progress next to this file.
set -u

GUIDE=$(cd "$(dirname "$0")" && pwd -P)
PDSF_TUTO_ROOT=$GUIDE
PDSF_TUTO_SRC=$GUIDE
PDSF_TUTO_WORKSPACE=$(cd "$GUIDE/../../.." && pwd -P)
PDSF_TUTO_HARNESS=claude
PDSF_TUTO_SKIP_CH2=n
PDSF_TUTO_SKIP_CH3=n
# shellcheck source=/dev/null
[ -f "$GUIDE/tutorial.env" ] && . "$GUIDE/tutorial.env"
PDSF_TUTO_PAUSE=n
export PDSF_TUTO_ROOT PDSF_TUTO_SRC PDSF_TUTO_WORKSPACE PDSF_TUTO_HARNESS \
  PDSF_TUTO_SKIP_CH2 PDSF_TUTO_SKIP_CH3 PDSF_TUTO_PAUSE
. "$GUIDE/lib/scenario.sh"

PROGRESS="$GUIDE/.progress"
[ -f "$PROGRESS" ] || : >"$PROGRESS"

usage() {
  cat <<'EOF'
usage: sh tuto.sh <command>
  plan          every chapter and step: done [x] or not, kind, command, title
  next          the id of the next step to play, or "done"
  chapter N     chapter N's title and introduction
  show STEP     a step's title, kind, command, What you do, Under the hood
  action STEP   run the step's deterministic action (if any)
  check STEP    run the step's check; records the step as done when it passes
  skip N y|n    skip (y) or play (n) a skippable chapter
STEP: a step id (01-build-the-factory/02-scaffold) or its short form (1.2).
EOF
}

# step_dir STEP -> the step directory, for an id or a short form N.M.
step_dir() {
  case "$1" in
    [0-9]*.[0-9]*)
      _sc=${1%%.*}; _ss=${1#*.}
      for _c in $(tuto_chapters); do
        [ "$(tuto_chapter_number "$_c")" = "$_sc" ] || continue
        for _s in $(tuto_steps "$_c"); do
          _n=${_s##*/}; _n=${_n%%-*}
          [ "$(printf '%s' "$_n" | sed 's/^0*//')" = "$_ss" ] && { printf '%s' "$_s"; return 0; }
        done
      done
      ;;
    */*)
      [ -f "$PDSF_TUTO_SCENARIO/$1/step.md" ] && { printf '%s' "$PDSF_TUTO_SCENARIO/$1"; return 0; }
      ;;
  esac
  tuto_die "unknown step '$1' (see: sh tuto.sh plan)"
}

chapter_dir() {
  for _c in $(tuto_chapters); do
    [ "$(tuto_chapter_number "$_c")" = "$1" ] && { printf '%s' "$_c"; return 0; }
  done
  tuto_die "unknown chapter '$1'"
}

is_done() { grep -qxF "$1" "$PROGRESS"; }

cmd_plan() {
  for _c in $(tuto_chapters); do
    _skip=""
    tuto_chapter_skipped "$_c" && _skip="  (skipped)"
    tuto_say "$(tuto_meta "$_c/chapter.md" title)$_skip"
    for _s in $(tuto_steps "$_c"); do
      _id=$(tuto_step_id "$_s")
      if is_done "$_id"; then _x=x; else _x=" "; fi
      _cmd=$(tuto_step_command "$_s")
      case "$_cmd" in /*) ;; *) _cmd="" ;; esac
      printf '  [%s] %-46s %-8s %-17s %s\n' "$_x" "$_id" "$(tuto_step_kind "$_s")" "$_cmd" "$(tuto_step_title "$_s")"
    done
  done
}

cmd_next() {
  for _c in $(tuto_chapters); do
    tuto_chapter_skipped "$_c" && continue
    for _s in $(tuto_steps "$_c"); do
      _id=$(tuto_step_id "$_s")
      is_done "$_id" || { tuto_say "$_id"; return 0; }
    done
  done
  tuto_say done
}

cmd_chapter() {
  _c=$(chapter_dir "$1") || exit 1
  _skip=""
  tuto_chapter_skipped "$_c" && _skip="  (skipped)"
  tuto_say "# $(tuto_meta "$_c/chapter.md" title)$_skip"
  tuto_say "Skippable: $(tuto_meta "$_c/chapter.md" skippable)"
  tuto_body "$_c/chapter.md"
}

cmd_show() {
  _s=$(step_dir "$1") || exit 1
  tuto_say "# $(tuto_step_title "$_s")"
  tuto_say "Step: $(tuto_step_id "$_s")"
  tuto_say "Kind: $(tuto_step_kind "$_s")"
  [ -n "$(tuto_step_command "$_s")" ] && tuto_say "Command: $(tuto_step_command "$_s")"
  if tuto_has_action "$_s"; then tuto_say "Action: yes (sh tuto.sh action $(tuto_step_id "$_s"))"; fi
  tuto_say ""
  tuto_say "## What you do"
  tuto_say ""
  tuto_section "$_s/step.md" "What you do"
  tuto_say ""
  tuto_say "## Under the hood"
  tuto_say ""
  tuto_section "$_s/step.md" "Under the hood"
}

cmd_action() {
  _s=$(step_dir "$1") || exit 1
  tuto_has_action "$_s" || { tuto_say "(this step has no action)"; return 0; }
  tuto_run_action "$_s"
}

cmd_check() {
  _s=$(step_dir "$1") || exit 1
  _id=$(tuto_step_id "$_s")
  if [ "$(tuto_step_kind "$_s")" = setup ]; then
    # Its check needs the PDSF source, gone by now: tutorial.sh and the mode ran it at the setup.
    tuto_say "  ✓ done and checked by the tutorial's entry script, at the setup"
  else
    tuto_run_check "$_s" || { tuto_say "→ $_id: not there yet."; return 1; }
  fi
  is_done "$_id" || printf '%s\n' "$_id" >>"$PROGRESS"
  tuto_say "→ $_id: done."
}

cmd_skip() {
  _c=$(chapter_dir "$1") || exit 1
  [ "$(tuto_meta "$_c/chapter.md" skippable)" = true ] || tuto_die "chapter $1 cannot be skipped"
  if tuto_is_yes "$2"; then _v=y; elif tuto_is_no "$2"; then _v=n; else tuto_die "skip $1: answer y or n"; fi
  _n=$(tuto_chapter_number "$_c")
  _tmp="$GUIDE/tutorial.env.tmp"
  { grep -v "^PDSF_TUTO_SKIP_CH$_n=" "$GUIDE/tutorial.env" 2>/dev/null; printf 'PDSF_TUTO_SKIP_CH%s=%s\n' "$_n" "$_v"; } >"$_tmp"
  mv "$_tmp" "$GUIDE/tutorial.env"
  if [ "$_v" = y ]; then tuto_say "Chapter $_n: skipped."; else tuto_say "Chapter $_n: to play."; fi
}

[ $# -ge 1 ] || { usage; exit 2; }
_command=$1; shift
case "$_command" in
  plan) cmd_plan ;;
  next) cmd_next ;;
  chapter|show|action|check)
    [ $# -eq 1 ] || { usage; exit 2; }
    "cmd_$_command" "$1" ;;
  skip)
    [ $# -eq 2 ] || { usage; exit 2; }
    cmd_skip "$1" "$2" ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
