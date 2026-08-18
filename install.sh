#!/bin/sh
# PDSF installer — Prompt Driven Software Factory.
#
# Two entry points, ONE script body:
#   * install.sh              — the `curl … | sh` bootstrap (installs skills into a target repo).
#   * .factory/pdsf-install.sh — the resident monorepo tool (a byte copy of this file, written
#                                 during a monorepo install; never hand-maintained separately).
#
# Zero dependency: POSIX sh only (no bash-isms, no jq). Generic emitter: regular skills under
# .agents/skills/ + a wired AGENTS.md (read by most harnesses, Copilot included); Claude is a thin
# symlink overlay on top. See docs/INSTALL.md, ADR-0002, ADR-0003.
#
# Everything a prompt asks can also be supplied via a PDSF_* env var (see --help), so the installer
# is drivable non-interactively (agentic tests) AND interactively (tmux). PDSF_SRC=<local checkout>
# makes it run fully offline.

# Not using `set -e`: the ask/grep control flow relies on non-zero returns. Critical steps die
# explicitly instead.
set -u

PDSF_REPO_URL="${PDSF_REPO:-https://github.com/Loulen/prompt-driven-software-factory.git}"
PDSF_TARBALL_URL="${PDSF_TARBALL:-https://codeload.github.com/Loulen/prompt-driven-software-factory/tar.gz/refs/heads/main}"

BEGIN_MARK="<!-- PDSF:BEGIN -->"
END_MARK="<!-- PDSF:END -->"

# ---------------------------------------------------------------------------- helpers

log()  { printf '%s\n' "PDSF: $*"; }
warn() { printf '%s\n' "PDSF: warning: $*" >&2; }
die()  { printf '%s\n' "PDSF: error: $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
PDSF installer — installs every PDSF skill into a target repo and wires the agent file.

USAGE
  sh install.sh [TARGET_DIR]         # bootstrap: install into TARGET_DIR (default: current dir)
  .factory/pdsf-install.sh           # resident: create/extend a factory in a monorepo

  Eventually (once a bootstrap URL is published):
  curl -fsSL <URL> | sh

OPTIONS
  -h, --help        Show this help and exit.

ENVIRONMENT (each also asked interactively when unset; set it to skip the prompt)
  PDSF_SRC       Local PDSF checkout to install FROM (its skills/, CONTEXT.md, docs/).
                 When set, the installer runs fully OFFLINE — no clone, no download.
                 When unset, the repo is fetched (git --depth 1 clone, else curl tarball).
  PDSF_HARNESS   Target harness: `generic` (default) or `claude`.
                 generic = regular skills under .agents/skills/ + a wired AGENTS.md — read by
                 most harnesses, Copilot included. claude = the generic install plus a symlink
                 overlay (.claude/skills -> .agents/skills, CLAUDE.md -> AGENTS.md).
  PDSF_MONOREPO  `y`/`n` — install a self-contained factory per context (.factory/<ctx>/)?
                 Default: n (single-project install).
  PDSF_CONTEXT   Monorepo only: the factory/context name (e.g. billing).
  PDSF_MEMBERS   Monorepo only: member sub-folders to wire, space- or comma-separated
                 (e.g. "apps/web apps/api"). Empty = create the factory, wire nothing yet.
  PDSF_ACTION    Resident tool only: `create` (or 1) / `wire` (or 2).
  PDSF_REPO      Override the git clone URL used when PDSF_SRC is unset.
  PDSF_TARBALL   Override the tarball URL used when neither PDSF_SRC nor git is available.

NOTES
  * Never installs into the PDSF source repo itself — always operates on TARGET_DIR / cwd.
  * Skills are generic (regular SKILL.md folders) under .agents/skills/; Claude is a symlink
    overlay on top. Copilot & other harnesses read the wired AGENTS.md.
  * Monorepo wiring uses RELATIVE symlinks (survive a re-clone). Keep .factory/ out of any
    sparse-checkout. Windows without symlink support is a known limitation.
EOF
}

# ask VAR "prompt" "default" -> prints the resolved value.
# If $VAR is SET (even to an empty string), use it verbatim and do NOT prompt — setting a var is
# how a non-interactive run opts out of that question. Only a fully UNSET var triggers the prompt.
ask() {
  _var=$1; _prompt=$2; _default=$3
  eval "_isset=\${$_var+x}"
  if [ "$_isset" = x ]; then
    eval "_cur=\${$_var}"
    printf '%s' "$_cur"
    return 0
  fi
  _ans=""
  if { true >/dev/tty; } 2>/dev/null; then
    printf '%s' "$_prompt" > /dev/tty
    IFS= read -r _ans < /dev/tty 2>/dev/null || _ans=""
  fi
  [ -z "$_ans" ] && _ans=$_default
  printf '%s' "$_ans"
}

is_yes() {
  case "$1" in
    y|Y|yes|Yes|YES|o|O|oui|Oui|1|true) return 0 ;;
    *) return 1 ;;
  esac
}

# abspath DIR -> absolute physical path (dir must exist).
abspath() {
  ( cd "$1" 2>/dev/null && pwd -P ) || die "path not found: $1"
}

# relpath TARGET BASE -> path of TARGET relative to directory BASE (both absolute, normalized).
relpath() {
  _t=$1; _b=$2; _up=""
  while :; do
    case "$_t/" in
      "$_b"/*) break ;;
    esac
    [ "$_b" = "/" ] && break
    _b=$(dirname "$_b")
    _up="../$_up"
  done
  _suffix=${_t#"$_b"}
  _suffix=${_suffix#/}
  _rel="${_up}${_suffix}"
  _rel=${_rel%/}
  [ -z "$_rel" ] && _rel="."
  printf '%s' "$_rel"
}

# A directory looks like the PDSF source repo (never a valid install target).
is_pdsf_repo() {
  [ -d "$1/skills" ] && [ -f "$1/CONTEXT.md" ] && [ -d "$1/.claude-plugin" ]
}

# Enumerate skill names from a source checkout (data-driven: never hardcode the set).
list_skills() {
  _src=$1
  for _d in "$_src"/skills/*/; do
    [ -d "$_d" ] || continue
    _name=${_d%/}; _name=${_name##*/}
    printf '%s\n' "$_name"
  done
}

# Replace (or append) the marked PDSF block in a file. $2 is the block body.
write_block() {
  _file=$1; _body=$2
  if [ -f "$_file" ] && grep -qF "$BEGIN_MARK" "$_file"; then
    _tmp=$(mktemp) || die "mktemp failed"
    # Strip only the LAST well-formed BEGIN..END pair (the block we manage), then drop the trailing
    # blank lines the strip leaves behind so a re-run is byte-idempotent. A stray BEGIN with no END
    # after it (a hand-corrupted half-block) is left untouched — never eat the user's content.
    awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
      { lines[NR]=$0 }
      END {
        lastb=0; for (i=1;i<=NR;i++) if (lines[i]==b) lastb=i
        ende=0; if (lastb>0) for (i=lastb;i<=NR;i++) if (lines[i]==e) { ende=i; break }
        for (i=1;i<=NR;i++) { if (lastb>0 && ende>0 && i>=lastb && i<=ende) continue; out[++n]=lines[i] }
        while (n>0 && out[n] ~ /^[[:space:]]*$/) n--
        for (i=1;i<=n;i++) print out[i]
      }
    ' "$_file" > "$_tmp" && mv "$_tmp" "$_file"
  fi
  {
    if [ -f "$_file" ] && [ -s "$_file" ]; then printf '\n'; fi
    printf '%s\n%s\n%s\n' "$BEGIN_MARK" "$_body" "$END_MARK"
  } >> "$_file"
}

# ---------------------------------------------------------------------------- source resolution

# resolve_src -> prints a local PDSF checkout dir (PDSF_SRC, else a freshly fetched temp dir).
resolve_src() {
  if [ -n "${PDSF_SRC:-}" ]; then
    [ -d "$PDSF_SRC/skills" ] || die "PDSF_SRC=$PDSF_SRC has no skills/ — not a PDSF checkout."
    abspath "$PDSF_SRC"
    return 0
  fi
  _tmp=$(mktemp -d) || die "mktemp -d failed"
  if command -v git >/dev/null 2>&1; then
    log "fetching PDSF (git clone --depth 1 $PDSF_REPO_URL)…" >&2
    if git clone --depth 1 "$PDSF_REPO_URL" "$_tmp/pdsf" >/dev/null 2>&1; then
      printf '%s' "$_tmp/pdsf"; return 0
    fi
    warn "git clone failed; trying tarball…"
  fi
  if command -v curl >/dev/null 2>&1; then
    log "fetching PDSF (curl tarball)…" >&2
    if curl -fsSL "$PDSF_TARBALL_URL" | ( cd "$_tmp" && tar xzf - ) 2>/dev/null; then
      for _d in "$_tmp"/*/; do
        [ -d "$_d/skills" ] && { printf '%s' "${_d%/}"; return 0; }
      done
    fi
  fi
  die "could not fetch PDSF. Set PDSF_SRC=<local checkout> to run offline."
}

# ---------------------------------------------------------------------------- emitter

# The generic, harness-neutral skills location. AGENTS.md (the cross-harness standard that Copilot,
# Cursor, Codex… all read) points every harness at it. Claude gets a thin symlink overlay on top.
SKILLS_DIR=".agents/skills"

# emit_generic SRC ROOT — copy every skill (as regular skill folders) into ROOT/.agents/skills/.
emit_generic() {
  _src=$1; _root=$2
  _dest="$_root/$SKILLS_DIR"
  mkdir -p "$_dest"
  _n=0
  for _s in $(list_skills "$_src"); do
    rm -rf "$_dest/$_s"
    cp -R "$_src/skills/$_s" "$_dest/$_s"
    _n=$((_n + 1))
  done
  # Prune skills dropped from the source set (this dir is fully PDSF-managed).
  for _d in "$_dest"/*/; do
    [ -d "$_d" ] || continue
    _old=${_d%/}; _old=${_old##*/}
    list_skills "$_src" | grep -qxF "$_old" || rm -rf "$_d"
  done
  log "emitted $_n skills into $SKILLS_DIR under $_root"
}

# link_claude DIR — the Claude overlay. "Claude support is just a symlink on top of the generic
# default": alias .agents/skills into .claude/skills, and point CLAUDE.md at AGENTS.md. Both relative.
link_claude() {
  _dir=$1
  mkdir -p "$_dir/.claude"
  rm -rf "$_dir/.claude/skills"
  ln -s "../$SKILLS_DIR" "$_dir/.claude/skills" \
    || warn "symlink .claude/skills failed (Windows without symlinks?)"
  if [ -e "$_dir/CLAUDE.md" ] && [ ! -L "$_dir/CLAUDE.md" ]; then
    # a real CLAUDE.md already holds user content — point to AGENTS.md, don't clobber it
    write_block "$_dir/CLAUDE.md" "@AGENTS.md"
  else
    rm -f "$_dir/CLAUDE.md"
    ln -s "AGENTS.md" "$_dir/CLAUDE.md" || warn "symlink CLAUDE.md failed"
  fi
  log "linked .claude/skills -> $SKILLS_DIR and CLAUDE.md -> AGENTS.md (Claude overlay)"
}

# ---------------------------------------------------------------------------- single-project

install_single() {
  _root=$1; _src=$2; _harness=$3
  emit_generic "$_src" "$_root"
  write_block "$_root/AGENTS.md" "## PDSF skills

The PDSF skills are installed under \`$SKILLS_DIR/\`. Invoke any of them as \`/<skill>\` (e.g.
\`/build-factory\`) — your harness loads the skill's markdown into context on demand. This block is
managed by the installer; \`/build-factory\` refines it with the method constants and the workflow map.

Git flow — every instance must know it:

@$SKILLS_DIR/git-flow/SKILL.md

**Next step: run \`/build-factory\`** to wire this project's backlogs, triage, and domain."
  log "wired AGENTS.md"
  if [ "$_harness" = claude ]; then link_claude "$_root"; fi
  printf '\n'
  log "done. Next step: run  /build-factory"
}

# ---------------------------------------------------------------------------- monorepo

# create_factory ROOT TEMPLATE CONTEXT — build a self-contained .factory/<ctx>/.
create_factory() {
  _root=$1; _tmpl=$2; _ctx=$3
  _fac="$_root/.factory/$_ctx"
  mkdir -p "$_fac/skills" "$_fac/docs/adr" "$_fac/docs/agents"

  for _s in $(list_skills "$_tmpl"); do
    rm -rf "$_fac/skills/$_s"
    cp -R "$_tmpl/skills/$_s" "$_fac/skills/$_s"
  done

  # Prune factory skills that are no longer in the source set (a factory's skills/ is fully
  # PDSF-managed) — the set adapts downward too, not only upward (ADR-0003 anti-silent-absence).
  for _d in "$_fac"/skills/*/; do
    [ -d "$_d" ] || continue
    _old=${_d%/}; _old=${_old##*/}
    list_skills "$_tmpl" | grep -qxF "$_old" || { rm -rf "$_d"; log "pruned stale skill '$_old' from factory $_ctx"; }
  done

  # Seed domain-doc format templates (safe to copy); leave CONTEXT.md/ADRs for /build-factory.
  if [ -d "$_tmpl/docs/agents" ]; then
    cp -R "$_tmpl/docs/agents/." "$_fac/docs/agents/" 2>/dev/null || true
  fi
  if [ ! -f "$_fac/CONTEXT.md" ]; then
    cat > "$_fac/CONTEXT.md" <<EOF
# $_ctx — CONTEXT

Domain glossary for the **$_ctx** context. Empty on purpose: run \`/build-factory\` (context mode)
inside this factory to fill it — grilling sessions are the only writers of CONTEXT.md and ADRs.
EOF
  fi

  # Method constants + skills pointer for this factory's members to import.
  write_block "$_fac/AGENTS.md" "## PDSF factory — $_ctx

Self-contained PDSF factory for the **$_ctx** context. Skills live in \`./skills/\`; domain docs in
\`./CONTEXT.md\`, \`./docs/adr/\`, \`./docs/agents/\`. Member sub-projects import this file.

Git flow — every instance must know it:

@skills/git-flow/SKILL.md

**Next step: run \`/build-factory\`** inside a member to fill CONTEXT.md and the foundational ADRs."

  log "created factory .factory/$_ctx/ ($(list_skills "$_tmpl" | wc -l | tr -d ' ') skills)"
}

# wire_member ROOT CONTEXT MEMBER HARNESS — relative symlinks + agent pointers into a member.
wire_member() {
  _root=$1; _ctx=$2; _member=$3; _harness=$4
  _member=${_member#./}; _member=${_member%/}
  _mdir="$_root/$_member"
  [ -d "$_mdir" ] || { warn "member '$_member' does not exist under the repo root — skipped."; return 1; }
  _mabs=$(abspath "$_mdir")
  _facabs=$(abspath "$_root/.factory/$_ctx")

  # Generic wiring: per-skill relative symlinks into the factory, under the member's .agents/skills/.
  _linkbase="$_mabs/$SKILLS_DIR"
  mkdir -p "$_linkbase"
  # Clear existing PDSF-managed links (they point into this factory) before recreating the current
  # set, so a skill dropped from the factory leaves no dangling symlink (ADR-0003). Any user-added
  # entry (not a link into this factory) is left untouched.
  for _l in "$_linkbase"/*; do
    [ -L "$_l" ] || continue
    case "$(readlink "$_l")" in *".factory/$_ctx/skills"*) rm -f "$_l" ;; esac
  done
  for _s in $(list_skills "$_root/.factory/$_ctx"); do
    _tgt="$_facabs/skills/$_s"
    _rel=$(relpath "$_tgt" "$_linkbase")
    rm -rf "$_linkbase/$_s"
    ln -s "$_rel" "$_linkbase/$_s" || warn "symlink failed for $_s in $_member (Windows without symlinks?)"
  done

  # Member AGENTS.md points at the factory's method constants + domain docs.
  _relagents=$(relpath "$_facabs/AGENTS.md" "$_mabs")
  write_block "$_mdir/AGENTS.md" "## PDSF factory pointer

This sub-project is wired to the **$_ctx** factory. Method constants and domain docs:

@$_relagents

Skills are symlinked into \`$SKILLS_DIR/\` (relative links into the factory)."
  log "wired member '$_member' -> .factory/$_ctx (skills in $SKILLS_DIR)"

  # Claude overlay: alias .agents/skills into .claude/skills + CLAUDE.md -> AGENTS.md.
  if [ "$_harness" = claude ]; then link_claude "$_mdir"; fi
}

# copy_self ROOT SRC SELF — write .factory/pdsf-install.sh from the single source (install.sh).
copy_self() {
  _root=$1; _src=$2; _self=$3
  _dest="$_root/.factory/pdsf-install.sh"
  if [ -f "$_src/install.sh" ]; then
    cp "$_src/install.sh" "$_dest"
  elif [ -n "$_self" ] && [ -f "$_self" ]; then
    cp "$_self" "$_dest"
  else
    die "cannot locate install.sh to copy as .factory/pdsf-install.sh (set PDSF_SRC)."
  fi
  chmod +x "$_dest" 2>/dev/null || true
  log "installed resident tool .factory/pdsf-install.sh"
}

# Parse a space/comma-separated member list into words (prints one per line).
split_members() {
  printf '%s' "$1" | tr ',' ' '
}

print_monorepo_notes() {
  cat <<'EOF'

PDSF: reminders —
  * .factory/ must NEVER be sparse-excluded (its relative symlinks would dangle).
  * Symlinks are relative and survive a re-clone.
  * Windows without symlink support is a known limitation (links won't resolve).
  * Nothing was wired at the monorepo root — opening the root loads no factory.
PDSF: done. Next step: run  /build-factory  inside a wired member.
EOF
}

# ---------------------------------------------------------------------------- flows

bootstrap_flow() {
  _target=$1; _self=$2

  if is_pdsf_repo "$_target"; then
    die "$_target looks like the PDSF source repo — refusing to install into itself.
Pass a target dir:  sh install.sh /path/to/your/project"
  fi
  mkdir -p "$_target"
  _target=$(abspath "$_target")
  _src=$(resolve_src)
  if [ "$_src" = "$_target" ]; then
    die "source and target are the same directory ($_target) — pass a different target."
  fi

  _harness=$(ask PDSF_HARNESS "Target harness? [claude/generic] (generic): " "generic")
  case "$_harness" in
    claude|generic) ;;
    copilot) _harness=generic; log "Copilot is covered by the generic install (AGENTS.md)." ;;
    *) die "unknown harness '$_harness' (claude|generic)";;
  esac

  _mono=$(ask PDSF_MONOREPO "Monorepo (a self-contained factory per context)? [y/N]: " "n")
  if is_yes "$_mono"; then
    _ctx=$(ask PDSF_CONTEXT "Context (factory) name: " "")
    [ -n "$_ctx" ] || die "a context name is required for a monorepo install (PDSF_CONTEXT)."
    _members=$(ask PDSF_MEMBERS "Member sub-folders to wire (space-separated, empty = none): " "")
    create_factory "$_target" "$_src" "$_ctx"
    copy_self "$_target" "$_src" "$_self"
    for _m in $(split_members "$_members"); do
      wire_member "$_target" "$_ctx" "$_m" "$_harness"
    done
    print_monorepo_notes
  else
    install_single "$_target" "$_src" "$_harness"
  fi
}

# resident_flow ROOT SELF — the .factory/pdsf-install.sh tool (create or wire).
resident_flow() {
  _root=$1; _self=$2
  _root=$(abspath "$_root")
  log "resident tool — monorepo root: $_root"

  _action=$(ask PDSF_ACTION "Action? [1] create a factory  [2] wire sub-folders  (1): " "1")
  _harness=$(ask PDSF_HARNESS "Target harness? [claude/generic] (generic): " "generic")
  case "$_harness" in
    claude|generic) ;;
    copilot) _harness=generic; log "Copilot is covered by the generic install (AGENTS.md)." ;;
    *) die "unknown harness '$_harness' (claude|generic)";;
  esac

  case "$_action" in
    2|wire)
      _existing=$(ls -1d "$_root"/.factory/*/ 2>/dev/null | sed 's#/$##;s#.*/##' || true)
      [ -n "$_existing" ] || die "no factory found under .factory/ — create one first."
      if [ -z "${PDSF_CONTEXT+x}" ] && { true >/dev/tty; } 2>/dev/null; then
        printf 'Existing factories:\n' > /dev/tty
        printf '%s\n' "$_existing" | sed 's/^/  - /' > /dev/tty
      fi
      _ctx=$(ask PDSF_CONTEXT "Target factory: " "")
      [ -n "$_ctx" ] || die "a factory name is required (PDSF_CONTEXT)."
      [ -d "$_root/.factory/$_ctx" ] || die "factory '.factory/$_ctx' not found."
      _members=$(ask PDSF_MEMBERS "Member sub-folders to wire (space-separated): " "")
      [ -n "$_members" ] || die "at least one member is required to wire (PDSF_MEMBERS)."
      for _m in $(split_members "$_members"); do
        wire_member "$_root" "$_ctx" "$_m" "$_harness"
      done
      print_monorepo_notes
      ;;
    *)
      _ctx=$(ask PDSF_CONTEXT "New context (factory) name: " "")
      [ -n "$_ctx" ] || die "a context name is required (PDSF_CONTEXT)."
      _members=$(ask PDSF_MEMBERS "Member sub-folders to wire (space-separated, empty = none): " "")
      # Template for the new factory: PDSF_SRC, else an existing factory, else fetch.
      if [ -n "${PDSF_SRC:-}" ]; then
        _tmpl=$(resolve_src)
      else
        _tmpl=""
        for _d in "$_root"/.factory/*/; do
          [ -d "$_d/skills" ] && { _tmpl=$(abspath "$_d"); break; }
        done
        [ -n "$_tmpl" ] || _tmpl=$(resolve_src)
      fi
      create_factory "$_root" "$_tmpl" "$_ctx"
      for _m in $(split_members "$_members"); do
        wire_member "$_root" "$_ctx" "$_m" "$_harness"
      done
      print_monorepo_notes
      ;;
  esac
}

# ---------------------------------------------------------------------------- main

main() {
  _target_arg=""
  for _a in "$@"; do
    case "$_a" in
      -h|--help) usage; exit 0 ;;
      --src=*)   PDSF_SRC=${_a#--src=} ;;
      -*)        die "unknown option: $_a (see --help)" ;;
      *)         _target_arg=$_a ;;
    esac
  done

  # Locate this script on disk (for copy_self / resident detection).
  case "$0" in
    /*) SELF=$0 ;;
    *)  SELF="$(pwd)/$0" ;;
  esac
  [ -f "$SELF" ] || SELF=""

  # Resident detection: this file lives inside a .factory/ directory.
  if [ -n "$SELF" ]; then
    _selfdir=$(dirname "$SELF")
    if [ "$(basename "$_selfdir")" = ".factory" ]; then
      resident_flow "$(dirname "$_selfdir")" "$SELF"
      exit 0
    fi
  fi

  bootstrap_flow "${_target_arg:-$(pwd)}" "$SELF"
}

main "$@"
