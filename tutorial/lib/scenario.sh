# PDSF Tutorial — scenario helpers (POSIX sh, sourced — never executed).
#
# The few shell helpers the tutorial app (app/tuto.mjs, through `sh`), the step checks and the
# maintainers' recorder share: frontmatter reading, step ids, running a step's check or action.
# The scenario itself is scenario/scenario.json (format: tutorial/README.md § Scenario format).
#
# Needs PDSF_TUTO_ROOT (the tutorial/ folder of the resolved PDSF source); the step actions and
# checks also get PDSF_TUTO_SRC and PDSF_TUTO_WORKSPACE from the environment.

: "${PDSF_TUTO_ROOT:?PDSF_TUTO_ROOT must point at the tutorial/ folder}"
PDSF_TUTO_SCENARIO="$PDSF_TUTO_ROOT/scenario"

tuto_die() { printf '%s\n' "PDSF tutorial: error: $*" >&2; exit 1; }

# tuto_meta FILE KEY -> the value of `KEY:` in FILE's frontmatter (empty if absent).
tuto_meta() {
  awk -v k="$2" '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm && index($0, k ":") == 1 { v = substr($0, length(k) + 2); sub(/^[ \t]+/, "", v); print v; exit }
  ' "$1"
}

# tuto_step_id STEP_DIR -> "<chapter>/<step>" (e.g. 01-build-the-factory/02-scaffold).
tuto_step_id() {
  _ti_c=${1%/*}
  printf '%s/%s' "${_ti_c##*/}" "${1##*/}"
}

tuto_has_action()    { [ -f "$1/action.sh" ]; }
tuto_has_recording() { [ -f "$1/recording/transcript.md" ]; }

# tuto_recorded_steps -> every step directory holding a recording, in scenario order.
tuto_recorded_steps() {
  for _ts in "$PDSF_TUTO_SCENARIO"/[0-9]*/[0-9]*/; do
    tuto_has_recording "$_ts" && printf '%s\n' "${_ts%/}"
  done
}

# tuto_run_action STEP_DIR — run the step's deterministic action, for real, in the workspace.
tuto_run_action() {
  tuto_has_action "$1" || return 0
  ( cd "$PDSF_TUTO_WORKSPACE" && sh "$1/action.sh" )
}

# tuto_run_check STEP_DIR — run the step's check in the workspace; its status is the verdict.
tuto_run_check() {
  ( cd "$PDSF_TUTO_WORKSPACE" && sh "$1/check.sh" )
}
