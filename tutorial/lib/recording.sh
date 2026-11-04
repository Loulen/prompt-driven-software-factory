# PDSF Tutorial — recording library (POSIX sh, sourced — never executed).
#
# Reads and replays the recording of a simulated step: STEP_DIR/recording/{transcript.md,files/}.
# Shared by the tutorial app (app/tuto.mjs applies a step's recording with rec_apply, then commits)
# and the maintainers' recorder (maintainers/record/record.sh). The format is documented in
# tutorial/README.md § Recordings.
#
# Needs lib/scenario.sh sourced first (tuto_meta, PDSF_TUTO_WORKSPACE).

# rec_transcript STEP_DIR -> the transcript path.
rec_transcript() { printf '%s' "$1/recording/transcript.md"; }

# rec_meta STEP_DIR KEY -> a frontmatter value of the transcript (step, command, branch, commit,
# session, via, merge, branches, removed, recorded, recorder, pdsf, harness, format).
rec_meta() { tuto_meta "$(rec_transcript "$1")" "$2"; }

# rec_turn_count STEP_DIR -> the number of turns (learner and agent) in the transcript.
rec_turn_count() {
  awk '/^<!-- pdsf-turn: (learner|agent) -->$/ { n++ } END { print n + 0 }' "$(rec_transcript "$1")"
}

# rec_turn_role STEP_DIR N -> `learner` or `agent` (turns are numbered from 1).
rec_turn_role() {
  awk -v want="$2" '
    /^<!-- pdsf-turn: (learner|agent) -->$/ {
      n++
      if (n == want) { r = $0; sub(/^<!-- pdsf-turn: /, "", r); sub(/ -->$/, "", r); print r; exit }
    }
  ' "$(rec_transcript "$1")"
}

# rec_turn_text STEP_DIR N -> the turn's text: without its marker, its cosmetic `### You` /
# `### Agent` heading and its choices line; surrounding blank lines trimmed.
rec_turn_text() {
  awk -v want="$2" '
    /^<!-- pdsf-turn: (learner|agent) -->$/ { n++; head = 1; started = 0; next }
    n != want { next }
    head && /^<!-- pdsf-choices: .* -->$/ { next }
    head && /^### (You|Agent)$/ { head = 0; next }
    !started && /^[ \t]*$/ { next }
    { head = 0; started = 1; lines[++c] = $0 }
    END {
      while (c > 0 && lines[c] ~ /^[ \t]*$/) c--
      for (i = 1; i <= c; i++) print lines[i]
    }
  ' "$(rec_transcript "$1")"
}

# rec_turn_choices STEP_DIR N -> the alternative answers recorded for a learner turn, one per line
# (empty when the question was open). The recorded answer itself is the turn's text.
rec_turn_choices() {
  awk -v want="$2" '
    /^<!-- pdsf-turn: (learner|agent) -->$/ { n++; next }
    n == want && /^<!-- pdsf-choices: .* -->$/ {
      c = $0; sub(/^<!-- pdsf-choices: /, "", c); sub(/ -->$/, "", c)
      k = split(c, parts, / \| /)
      for (i = 1; i <= k; i++) if (parts[i] != "") print parts[i]
      exit
    }
  ' "$(rec_transcript "$1")"
}

# rec_files STEP_DIR -> the recorded files, as workspace-relative paths, one per line.
rec_files() {
  [ -d "$1/recording/files" ] || return 0
  ( cd "$1/recording/files" && find . \( -type f -o -type l \) | sed 's#^\./##' | LC_ALL=C sort )
}

# rec_git ARGS… — git in the workspace, with a fallback identity when none is configured.
rec_git() {
  if [ -n "$(git -C "$PDSF_TUTO_WORKSPACE" config user.email 2>/dev/null)" ]; then
    git -C "$PDSF_TUTO_WORKSPACE" "$@" </dev/null
  else
    git -C "$PDSF_TUTO_WORKSPACE" -c user.name="PDSF Tutorial" -c user.email="tutorial@pdsf.invalid" "$@" </dev/null
  fi
}

# rec_apply STEP_DIR — replay the recorded end state of a simulated step onto the workspace, the way
# the real run left it: switch to (or create, from HEAD) the recorded `branch`; when the run worked
# on a branch it then merged (`via`), create that branch and commit there; copy `files/` over the
# workspace, delete the `removed` paths, commit them with the recorded `commit` message; merge `via`
# back (--no-ff, message `merge`); create the other `branches` the run created.
# Status non-zero = the replay failed.
rec_apply() {
  _ra_step=$1
  _ra_branch=$(rec_meta "$_ra_step" branch)
  _ra_commit=$(rec_meta "$_ra_step" commit)
  _ra_via=$(rec_meta "$_ra_step" via)
  _ra_merge=$(rec_meta "$_ra_step" merge)
  _ra_removed=$(rec_meta "$_ra_step" removed)
  _ra_branches=$(rec_meta "$_ra_step" branches)

  for _ra_b in $_ra_branch $_ra_via; do
    [ "$(rec_git symbolic-ref --short -q HEAD)" = "$_ra_b" ] && continue
    if rec_git show-ref --verify --quiet "refs/heads/$_ra_b"; then
      rec_git checkout -q "$_ra_b" || return 1
    else
      rec_git checkout -q -b "$_ra_b" || return 1
    fi
  done
  if [ -d "$_ra_step/recording/files" ]; then
    cp -R "$_ra_step/recording/files/." "$PDSF_TUTO_WORKSPACE/" || return 1
  fi
  for _ra_p in $_ra_removed; do
    rm -rf "${PDSF_TUTO_WORKSPACE:?}/$_ra_p"
  done
  _ra_paths=$(rec_files "$_ra_step")
  # shellcheck disable=SC2086
  [ -z "$_ra_paths$_ra_removed" ] || rec_git add -A -- $_ra_paths $_ra_removed || return 1
  if ! rec_git diff --cached --quiet; then
    rec_git commit -q -m "${_ra_commit:-$(rec_meta "$_ra_step" command) (simulated)}" || return 1
  fi
  if [ -n "$_ra_via" ]; then
    rec_git checkout -q "$_ra_branch" || return 1
    rec_git merge -q --no-ff -m "${_ra_merge:-Merge $_ra_via}" "$_ra_via" || return 1
  fi
  for _ra_b in $_ra_branches; do
    rec_git show-ref --verify --quiet "refs/heads/$_ra_b" || rec_git branch "$_ra_b" || return 1
  done
  return 0
}
