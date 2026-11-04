// PDSF Tutorial — keyboard and scripted input (Node 18, zero dependency).
//
// Keys are names: enter, tab, up, down, left, right, backspace, delete, esc, ctrl-c, ctrl-d, or one
// printable character. The app reads them from the terminal (raw mode) or from a scripted input
// (PDSF_TUTO_SCRIPT): `auto`, or a file (format: tutorial/README.md § Scripted input).
import fs from 'node:fs';

export class ScriptEnd extends Error {}

// parseKeys(chunk) -> key names: enter, tab, up, down, left, right, backspace, ctrl-c, ctrl-d,
// esc, or one printable character.
export function parseKeys(chunk) {
  const s = chunk.toString('utf8');
  const out = [];
  const seq = [['\x1b[200~', null], ['\x1b[201~', null], ['\x1b[A', 'up'], ['\x1b[B', 'down'], ['\x1b[C', 'right'], ['\x1b[D', 'left'],
    ['\x1bOA', 'up'], ['\x1bOB', 'down'], ['\x1bOC', 'right'], ['\x1bOD', 'left'], ['\x1b[3~', 'delete'], ['\x1b[Z', 'shift-tab']];
  let i = 0;
  outer: while (i < s.length) {
    for (const [k, name] of seq) {
      if (s.startsWith(k, i)) { if (name) out.push(name); i += k.length; continue outer; }
    }
    const c = s[i];
    if (c === '\x1b') {
      const m = s.slice(i).match(/^\x1b\[[0-9;]*[A-Za-z~]/);
      if (m) { i += m[0].length; continue; }
      out.push('esc'); i++; continue;
    }
    if (c === '\r' || c === '\n') { out.push('enter'); if (c === '\r' && s[i + 1] === '\n') i++; i++; continue; }
    if (c === '\t') { out.push('tab'); i++; continue; }
    if (c === '\x7f' || c === '\b') { out.push('backspace'); i++; continue; }
    if (c === '\x03') { out.push('ctrl-c'); i++; continue; }
    if (c === '\x04') { out.push('ctrl-d'); i++; continue; }
    if (c.charCodeAt(0) < 32) { i++; continue; }
    const cp = s.codePointAt(i);
    const ch = String.fromCodePoint(cp);
    out.push(ch); i += ch.length;
  }
  return out;
}

// parseScript(text) -> {keys, auto}: one item per line — `{name}` is one key (enter, tab, up,
// down, left, right, backspace, esc, ctrl-c, or a single character such as {?} or {q}); `{auto}`
// plays the recorded path from there on; any other line is typed, then Enter. `#` lines: comments.
export function parseScript(text) {
  const keys = [];
  for (const raw of text.split('\n')) {
    const line = raw.replace(/\r$/, '');
    if (!line.trim() || /^\s*#/.test(line)) continue;
    const m = line.trim().match(/^\{(.+)\}$/);
    if (m) { keys.push(m[1] === 'auto' ? { auto: true } : m[1]); continue; }
    for (const ch of line) keys.push(ch);
    keys.push('enter');
  }
  return keys;
}

export class Keys {
  constructor({ tty, script }) {
    this.queue = [];
    this.waiter = null;
    this.auto = false;
    this.scripted = Boolean(script);
    if (script === 'auto') this.auto = true;
    else if (script) this.queue.push(...parseScript(fs.readFileSync(script, 'utf8')));
    if (tty) {
      process.stdin.setRawMode(true);
      process.stdin.resume();
      process.stdin.on('data', (d) => { for (const k of parseKeys(d)) this.push(k); });
    }
  }

  push(k) {
    if (this.waiter) { const w = this.waiter; this.waiter = null; w(k); } else this.queue.push(k);
  }

  // take() -> the next queued key, or null; an {auto} marker switches to the recorded path.
  take() {
    while (this.queue.length) {
      const k = this.queue.shift();
      if (k && k.auto) { this.auto = true; continue; }
      return k;
    }
    return null;
  }

  pending() { return this.queue.some((k) => !(k && k.auto)); }

  // next(auto) -> a key: queued, else from `auto` (what the recorded path would press) when on
  // the recorded path, else from the keyboard.
  async next(auto) {
    const k = this.take();
    if (k != null) return k;
    if (this.auto) return typeof auto === 'function' ? auto() : auto;
    if (this.scripted) throw new ScriptEnd();
    return new Promise((resolve) => { this.waiter = resolve; });
  }
}
