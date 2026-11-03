# PDSF Tutorial — scenario library (POSIX sh, sourced — never executed).
#
# Shared by the entry script (tutorial.sh) and every tutorial mode (modes/<id>/play.sh), so they all
# read the scenario the same way. The contract it implements is documented in tutorial/README.md
# (§ Scenario contract, § Modes).
#
# Needs PDSF_TUTO_ROOT (the tutorial/ folder of the resolved PDSF source); the step actions and
# checks also get PDSF_TUTO_SRC, PDSF_TUTO_WORKSPACE and PDSF_TUTO_HARNESS from the environment.

: "${PDSF_TUTO_ROOT:?PDSF_TUTO_ROOT must point at the tutorial/ folder}"
PDSF_TUTO_SCENARIO="$PDSF_TUTO_ROOT/scenario"

# ---------------------------------------------------------------------------- terminal

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  _TUTO_B=$(printf '\033[1m'); _TUTO_D=$(printf '\033[2m'); _TUTO_R=$(printf '\033[0m')
else
  _TUTO_B=""; _TUTO_D=""; _TUTO_R=""
fi

tuto_say()  { printf '%s\n' "$*"; }
tuto_bold() { printf '%s%s%s\n' "$_TUTO_B" "$*" "$_TUTO_R"; }
tuto_dim()  { printf '%s%s%s\n' "$_TUTO_D" "$*" "$_TUTO_R"; }
tuto_rule() { tuto_bold "──── $* ────"; }
tuto_die()  { printf '%s\n' "PDSF tutorial: error: $*" >&2; exit 1; }

tuto_has_tty() { { true >/dev/tty; } 2>/dev/null; }

# tuto_ask VAR "prompt" "default" -> prints the answer.
# Same rule as install.sh: a SET variable (even empty) answers the question without prompting —
# that is how a non-interactive run drives the tutorial; an UNSET one asks on /dev/tty (so
# `curl … | sh` stays interactive); no tty → the default.
tuto_ask() {
  _tq_var=$1; _tq_prompt=$2; _tq_default=$3
  eval "_tq_isset=\${$_tq_var+x}"
  if [ "$_tq_isset" = x ]; then
    eval "printf '%s' \"\${$_tq_var}\""
    return 0
  fi
  _tq_ans=""
  if tuto_has_tty; then
    printf '%s' "$_tq_prompt" > /dev/tty
    IFS= read -r _tq_ans < /dev/tty 2>/dev/null || _tq_ans=""
  fi
  [ -z "$_tq_ans" ] && _tq_ans=$_tq_default
  printf '%s' "$_tq_ans"
}

tuto_is_yes() {
  case "$1" in
    y|Y|yes|Yes|YES|1|true) return 0 ;;
    *) return 1 ;;
  esac
}

# tuto_pause ["message"] — wait for Enter, unless PDSF_TUTO_PAUSE=n or there is no tty.
tuto_pause() {
  tuto_is_no "${PDSF_TUTO_PAUSE:-y}" && return 0
  tuto_has_tty || return 0
  printf '%s' "${1:-Press Enter to continue…} " > /dev/tty
  IFS= read -r _tp_ans < /dev/tty 2>/dev/null || true
}

tuto_is_no() {
  case "$1" in
    n|N|no|No|NO|0|false) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------- markdown files

# tuto_meta FILE KEY -> the value of `KEY:` in FILE's frontmatter (empty if absent).
tuto_meta() {
  awk -v k="$2" '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm && index($0, k ":") == 1 { v = substr($0, length(k) + 2); sub(/^[ \t]+/, "", v); print v; exit }
  ' "$1"
}

# tuto_body FILE -> FILE without its frontmatter.
tuto_body() {
  awk '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm == 1 && $0 == "---" { fm = 2; next }
    fm != 1 { print }
  ' "$1"
}

# tuto_section FILE "Heading" -> the body of the `## Heading` section (up to the next `## `).
tuto_section() {
  awk -v h="## $2" '
    $0 == h { on = 1; next }
    on && /^## / { exit }
    on { print }
  ' "$1" | awk 'NF { started = 1 } started { lines[++n] = $0 } END { while (n > 0 && lines[n] ~ /^[ \t]*$/) n--; for (i = 1; i <= n; i++) print lines[i] }'
}

# ---------------------------------------------------------------------------- scenario

# tuto_chapters -> chapter directories, in order (NN-<slug>/ holding a chapter.md).
tuto_chapters() {
  for _tc in "$PDSF_TUTO_SCENARIO"/[0-9]*/; do
    [ -f "$_tc/chapter.md" ] && printf '%s\n' "${_tc%/}"
  done
}

# tuto_steps CHAPTER_DIR -> step directories of a chapter, in order (NN-<slug>/ holding a step.md).
tuto_steps() {
  for _ts in "$1"/[0-9]*/; do
    [ -f "$_ts/step.md" ] && printf '%s\n' "${_ts%/}"
  done
}

# tuto_chapter_number CHAPTER_DIR -> its number without leading zeros (01-build… -> 1).
tuto_chapter_number() {
  _tn=${1##*/}; _tn=${_tn%%-*}
  printf '%s' "$_tn" | sed 's/^0*//'
}

# tuto_chapter_skipped CHAPTER_DIR — true when the chapter is skippable and PDSF_TUTO_SKIP_CH<n>
# says yes.
tuto_chapter_skipped() {
  [ "$(tuto_meta "$1/chapter.md" skippable)" = true ] || return 1
  eval "_tk=\${PDSF_TUTO_SKIP_CH$(tuto_chapter_number "$1"):-n}"
  tuto_is_yes "$_tk"
}

tuto_step_title()   { tuto_meta "$1/step.md" title; }
tuto_step_kind()    { tuto_meta "$1/step.md" kind; }
tuto_step_command() { tuto_meta "$1/step.md" command; }

# tuto_step_id STEP_DIR -> "<chapter>/<step>" (e.g. 01-build-the-factory/02-scaffold).
tuto_step_id() {
  _ti_c=${1%/*}
  printf '%s/%s' "${_ti_c##*/}" "${1##*/}"
}

tuto_has_action()    { [ -f "$1/action.sh" ]; }
tuto_has_recording() { [ -f "$1/recording/transcript.md" ]; }

# tuto_run_action STEP_DIR — run the step's deterministic action, for real, in the workspace.
tuto_run_action() {
  tuto_has_action "$1" || return 0
  ( cd "$PDSF_TUTO_WORKSPACE" && sh "$1/action.sh" )
}

# tuto_run_check STEP_DIR — run the step's check in the workspace; its status is the verdict.
tuto_run_check() {
  ( cd "$PDSF_TUTO_WORKSPACE" && sh "$1/check.sh" )
}

# ---------------------------------------------------------------------------- modes

# tuto_modes -> shipped mode directories, in order (modes/<id>/ holding a play.sh and a mode.md).
tuto_modes() {
  for _tm in "$PDSF_TUTO_ROOT"/modes/*/; do
    [ -f "$_tm/play.sh" ] && [ -f "$_tm/mode.md" ] && printf '%s\n' "${_tm%/}"
  done
}

# tuto_mode_id MODE_DIR -> its short id, the directory name up to the first dash (a1-… -> a1).
tuto_mode_id() {
  _tmi=${1##*/}
  printf '%s' "${_tmi%%-*}"
}
