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

# tuto_width -> the width to render text at: $COLUMNS, else the terminal's, else 100; within 60–110.
tuto_width() {
  _tw=${COLUMNS:-}
  case "$_tw" in ''|*[!0-9]*) _tw=$( (stty size </dev/tty | cut -d' ' -f2) 2>/dev/null) ;; esac
  case "$_tw" in ''|*[!0-9]*) _tw=100 ;; esac
  [ "$_tw" -gt 110 ] && _tw=110
  [ "$_tw" -lt 60 ] && _tw=60
  printf '%s' "$_tw"
}

# tuto_md WIDTH [PREFIX] — markdown on stdin, rendered for the terminal, every line prefixed with
# PREFIX and kept within WIDTH display columns (wide emoji count 2, so nothing hard-wraps outside
# the prefix):
#   - paragraphs and list items re-flowed and wrapped (hanging indent for list items);
#   - headings and **bold** in bold; `code` spans highlighted (backticks dropped) when colours are on,
#     kept as typed otherwise;
#   - code fences: the ``` lines dropped, the content indented and kept as typed; a line too wide
#     breaks at its last space that fits (a word longer than a line is cut), on hanging lines;
#   - tables aligned in columns (│), cells wrapped when the table is too wide; when even that does
#     not fit, each row is shown as a list of `header: value` fields;
#   - `⏺ Tool(…)` lines dimmed.
# awk runs in the C locale, so every awk (mawk, gawk, busybox) counts bytes the same way and the
# display width is computed here from UTF-8.
tuto_md() {
  LC_ALL=C awk -v width="$1" -v prefix="${2:-}" -v raw="${_tuto_md_raw:-}" -v B="$_TUTO_B" -v D="$_TUTO_D" -v R="$_TUTO_R" '
    # ---------------------------------------------------------------- widths
    # dlen(s) -> display columns of s: escape sequences ignored, one per UTF-8 character, two for
    # 4-byte characters (emoji) and for the wide BMP emoji the recordings use.
    function dlen(s,   t, n) {
      gsub(/\033\[[0-9;]*m/, "", s)
      t = s; gsub(/[\200-\277]/, "", t); n = length(t)
      t = s; n += gsub(/[\360-\367]/, "", t)
      t = s; n += gsub(WIDE, "", t)
      return n
    }
    # cwidth(s, i) -> display columns of the character starting at byte i (0 for a continuation byte).
    function cwidth(s, i,   c) {
      c = substr(s, i, 1)
      if (c ~ /[\200-\277]/) return 0
      if (c ~ /[\360-\367]/) return 2
      if (c ~ /[\340-\357]/ && substr(s, i, 3) ~ ("^(" WIDE ")")) return 2
      return 1
    }
    # cut(s, n) -> the longest head of s that fits in n columns, never splitting a character.
    function cut(s, n,   i, k, cw, L) {
      L = length(s); k = 0
      for (i = 1; i <= L; i++) {
        cw = cwidth(s, i)
        if (cw && k + cw > n) return substr(s, 1, i - 1)
        k += cw
      }
      return s
    }
    # vis(s) -> s as it will show: without the markup the renderer turns into styles.
    function vis(s) { gsub(/\*\*/, "", s); if (color) gsub(/`/, "", s); return s }
    function vlen(s) { return dlen(vis(s)) }
    function spaces(n,   r) { r = ""; while (n-- > 0) r = r " "; return r }
    function rep(c, n,   r) { r = ""; while (n-- > 0) r = r c; return r }

    # ---------------------------------------------------------------- inline styles
    # sty(s) -> s with **bold** and `code` turned into terminal styles. The state (sb, sc) carries
    # over to the next line of the same paragraph or cell: styles are closed at the end of a line
    # and re-opened at the start of the next one. reset() starts a new block.
    function reset() { sb = 0; sc = 0 }
    function sty(s,   r, pb, pc) {
      r = (sb ? B : "") (sc ? C : "")
      while (s != "") {
        pc = color ? index(s, "`") : 0
        pb = sc ? 0 : index(s, "**")
        if (pc && (!pb || pc < pb)) {
          r = r substr(s, 1, pc - 1) (sc ? CO : C); sc = !sc; s = substr(s, pc + 1)
        } else if (pb) {
          r = r substr(s, 1, pb - 1) (sb ? BO : B); sb = !sb; s = substr(s, pb + 2)
        } else { r = r s; s = "" }
      }
      if (sc) r = r CO
      if (sb) r = r BO
      return r
    }
    function out(s) { print prefix sty(s) }

    # ---------------------------------------------------------------- paragraphs
    # wrap(text, avail) -> fills the global WL[1..n] with the lines of text wrapped to avail columns
    # (a word longer than a line is cut); returns n.
    function wrap(text, avail,   n, i, words, line, k, wd, room, piece) {
      split("", WL); k = 0; line = ""
      n = split(text, words, / +/)
      for (i = 1; i <= n; i++) {
        wd = words[i]
        if (wd == "") continue
        if (line != "" && vlen(line) + 1 + vlen(wd) > avail) { WL[++k] = line; line = "" }
        while (vlen((line == "" ? "" : line " ") wd) > avail) {
          room = avail - (line == "" ? 0 : vlen(line) + 1)
          if (room < 1) { WL[++k] = line; line = ""; continue }
          piece = cut(wd, room)
          if (piece == "") { if (line == "") break; WL[++k] = line; line = ""; continue }
          line = (line == "" ? "" : line " ") piece
          wd = substr(wd, length(piece) + 1)
          WL[++k] = line; line = ""
        }
        if (wd != "") line = (line == "" ? "" : line " ") wd
      }
      if (line != "" || k == 0) WL[++k] = line
      return k
    }
    function flush(   n, i) {
      if (para == "") return
      n = wrap(para, w - dlen(ppre))
      reset()
      for (i = 1; i <= n; i++) out((i == 1 ? ppre : phang) WL[i])
      para = ""; reset()
    }

    # ---------------------------------------------------------------- tables
    function cells(line, row,   n, i, parts) {
      sub(/^[ \t]*\|/, "", line); sub(/\|[ \t]*$/, "", line)
      n = split(line, parts, /\|/)
      for (i = 1; i <= n; i++) { sub(/^[ \t]+/, "", parts[i]); sub(/[ \t]+$/, "", parts[i]); T[row, i] = parts[i] }
      if (n > ncol) ncol = n
    }
    function table(   i, j, k, nrows, hdr, total, big, nl, ml, wrapped, line, sepline, cw, L, mn, lw, cap, nw, WS, def, extra, given, add) {
      split("", T); ncol = 0; nrows = 0; hdr = 0
      for (i = 1; i <= nt; i++) {
        if (TB[i] ~ /^[ \t|:-]+$/ && TB[i] ~ /-/) { if (!hdr) hdr = nrows; continue }
        cells(TB[i], ++nrows)
      }
      for (j = 1; j <= ncol; j++) {
        cw[j] = 1
        for (i = 1; i <= nrows; i++) {
          if (vlen(T[i, j]) > cw[j]) cw[j] = vlen(T[i, j])
        }
      }
      total = 3 * (ncol - 1)
      for (j = 1; j <= ncol; j++) total += cw[j]
      wrapped = 0
      if (total > w) {
        # Too wide: every column keeps at least its longest word (capped at 32 columns, then less
        # until it fits), and the room left goes to the columns in proportion to how much they lack.
        wrapped = 1
        for (j = 1; j <= ncol; j++) {
          lw[j] = 1
          for (i = 1; i <= nrows; i++) {
            nw = split(T[i, j], WS, / +/)
            for (k = 1; k <= nw; k++) if (vlen(WS[k]) > lw[j]) lw[j] = vlen(WS[k])
          }
        }
        for (cap = 32; cap >= 8; cap -= 4) {
          total = 3 * (ncol - 1); def = 0
          for (j = 1; j <= ncol; j++) {
            mn[j] = lw[j]; if (mn[j] > cap) mn[j] = cap
            total += mn[j]; def += cw[j] - mn[j]
          }
          if (total <= w) break
        }
        if (total <= w) {
          extra = w - total; given = 0; big = 0
          for (j = 1; j <= ncol; j++) {
            add = def ? int(extra * (cw[j] - mn[j]) / def) : 0
            if (!big || cw[j] - mn[j] > cw[big] - mn[big]) big = j
            cw[j] = mn[j] + add; given += add
          }
          cw[big] += extra - given; total = w
        }
      }
      if (total > w) { records(nrows, hdr); nt = 0; return }
      sepline = ""
      for (j = 1; j <= ncol; j++) sepline = sepline (j > 1 ? "─┼─" : "") rep("─", cw[j])
      for (i = 1; i <= nrows; i++) {
        ml = 1
        for (j = 1; j <= ncol; j++) {
          nl = wrap(T[i, j], cw[j]); reset()
          for (k = 1; k <= nl; k++) { L[j, k] = sty(WL[k]) spaces(cw[j] - vlen(WL[k])) }
          LN[j] = nl; if (nl > ml) ml = nl
        }
        for (k = 1; k <= ml; k++) {
          line = ""
          for (j = 1; j <= ncol; j++) {
            line = line (j > 1 ? D " │ " R : "") (k <= LN[j] ? L[j, k] : spaces(cw[j]))
          }
          sub(/ +$/, "", line)
          if (i <= hdr) line = B line R
          print prefix line
        }
        if (i == hdr) print prefix D sepline R
        else if (wrapped && i < nrows) print prefix D sepline R
      }
      reset(); nt = 0
    }
    # records(): the table as one list item per row, each field `header: value`.
    function records(nrows, hdr,   i, j, first) {
      for (i = hdr + 1; i <= nrows; i++) {
        first = 1
        for (j = 1; j <= ncol; j++) {
          if (T[i, j] == "") continue
          ppre = first ? "• " : "  "; phang = "    "
          para = (hdr && T[1, j] != "" ? "**" vis(T[1, j]) ":** " : "") T[i, j]
          flush(); first = 0
        }
      }
      ppre = ""; phang = ""
    }

    # ---------------------------------------------------------------- lines
    function verbatim(s) { flush(); print prefix s }
    # vline(s): a line printed as typed (no markup); when it is too wide it breaks at the last space
    # that fits (a word longer than a line is cut), and the rest goes on hanging lines indented two
    # columns past the indent of the line.
    function vline(s,   hang, piece, k, lead) {
      gsub(/\t/, "    ", s)
      match(s, /^ */); lead = RLENGTH
      hang = spaces((lead + 2 < w / 2) ? lead + 2 : 2)
      while (dlen(s) > w) {
        piece = cut(s, w)
        for (k = length(piece); k > lead && substr(piece, k, 1) != " "; k--) ;
        if (substr(s, length(piece) + 1, 1) != " " && k > lead) piece = substr(piece, 1, k - 1)
        sub(/ +$/, "", piece)
        print prefix piece
        s = substr(s, length(piece) + 1); sub(/^ +/, "", s); s = hang s; lead = length(hang)
      }
      print prefix s
    }
    BEGIN {
      color = (B != "")
      BO = color ? "\033[22m" : ""
      C = color ? "\033[36m" : ""; CO = color ? "\033[39m" : ""
      WIDE = "\342\234\205|\342\235\214|\342\236\226|\342\236\225|\342\255\220|\342\217\263|\342\234\250|\342\235\223"
      p = prefix; w = width - dlen(p); if (w < 30) w = 30
    }
    raw { vline($0); next }
    nt && !/^[ \t]*\|/ { table() }
    /^[ \t]*```/ { flush(); fence = !fence; next }
    fence { vline("  " $0); next }
    /^[ \t]*$/ { flush(); print prefix; next }
    /^[ \t]*\|/ { flush(); TB[++nt] = $0; next }
    /^[ \t]*⏺ / { flush(); s = $0; if (dlen(s) > w) s = cut(s, w - 1) "…"; print prefix D s R; next }
    /^---+[ \t]*$/ { verbatim(D rep("─", (w < 40 ? w : 40)) R); next }
    /^#+ / { flush(); h = $0; sub(/^#+ /, "", h); gsub(/\*\*/, "", h); reset(); print prefix B sty(h) R; reset(); next }
    /^[ \t]*([-*+]|[0-9]+[.)]|>) / {
      flush()
      match($0, /^[ \t]*([-*+]|[0-9]+[.)]|>) /)
      ppre = substr($0, 1, RLENGTH); para = substr($0, RLENGTH + 1)
      phang = ppre; gsub(/[^ \t]/, " ", phang)
      if (ppre ~ />/) phang = ppre
      next
    }
    {
      t = $0; sub(/^[ \t]+/, "", t)
      if (para == "") { ppre = ""; phang = ""; para = t } else para = para " " t
    }
    END { if (nt) table(); flush() }
  '
}

# tuto_wrap WIDTH [PREFIX] — plain text on stdin (command output), every line kept as typed, prefixed
# and kept within WIDTH display columns: a line too wide breaks at its last space that fits and
# goes on hanging lines (indented two past the line's own indent) — no word is lost.
tuto_wrap() { _tuto_md_raw=1 tuto_md "$@"; }

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
