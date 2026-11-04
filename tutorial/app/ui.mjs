// PDSF Tutorial — terminal UI primitives (Node 18, zero dependency, raw ANSI).
//
// A rendered line is an array of segments `[text, style]` (a bare string is an unstyled segment).
// Everything that reaches the terminal goes through `fit` or `wrap`, which count DISPLAY columns
// (wide emoji count 2, combining marks 0), so no line is ever wider than the terminal — the
// iteration-1 rendering fixes (fit / tuto_wrap in the old shell library) carried over.
//
// Styles are space-separated keys of PALETTE (`'orange bold'`). Components (rule, box, coach band,
// progress dots, choice list…) return arrays of lines; the app composes them into a frame.

// ---------------------------------------------------------------------------- widths

const WIDE_BMP = new Set([
  0x231a, 0x231b, 0x23e9, 0x23ea, 0x23eb, 0x23ec, 0x23f0, 0x23f3, 0x25fd, 0x25fe, 0x2614, 0x2615,
  0x267f, 0x2693, 0x26a1, 0x26aa, 0x26ab, 0x26bd, 0x26be, 0x26c4, 0x26c5, 0x26ce, 0x26d4, 0x26ea,
  0x26f2, 0x26f3, 0x26f5, 0x26fa, 0x26fd, 0x2705, 0x270a, 0x270b, 0x2728, 0x274c, 0x274e, 0x2753,
  0x2754, 0x2755, 0x2757, 0x2795, 0x2796, 0x2797, 0x27b0, 0x27bf, 0x2b1b, 0x2b1c, 0x2b50, 0x2b55,
]);

// charWidth(codePoint) -> display columns of one code point (0, 1 or 2).
export function charWidth(cp) {
  if (cp === 0) return 0;
  if (cp < 32 || (cp >= 0x7f && cp < 0xa0)) return 0;
  if ((cp >= 0x300 && cp <= 0x36f) || cp === 0x200b || cp === 0x200c || cp === 0x200d ||
      cp === 0xfe0e || cp === 0xfe0f || (cp >= 0x20d0 && cp <= 0x20ff)) return 0;
  if (WIDE_BMP.has(cp) || (cp >= 0x2648 && cp <= 0x2653)) return 2;
  if ((cp >= 0x1100 && cp <= 0x115f) || (cp >= 0x2e80 && cp <= 0xa4cf && cp !== 0x303f) ||
      (cp >= 0xac00 && cp <= 0xd7a3) || (cp >= 0xf900 && cp <= 0xfaff) ||
      (cp >= 0xfe30 && cp <= 0xfe4f) || (cp >= 0xff00 && cp <= 0xff60) ||
      (cp >= 0xffe0 && cp <= 0xffe6) || (cp >= 0x1f300 && cp <= 0x1f64f) ||
      (cp >= 0x1f680 && cp <= 0x1f6ff) || (cp >= 0x1f900 && cp <= 0x1f9ff) ||
      (cp >= 0x1fa70 && cp <= 0x1faff) || (cp >= 0x20000 && cp <= 0x3fffd)) return 2;
  return 1;
}

export const stripAnsi = (s) => String(s).replace(/\x1b\[[0-9;?]*[A-Za-z]/g, '');

// strWidth(text) -> display columns of a plain string (escape sequences ignored).
export function strWidth(text) {
  let n = 0;
  for (const ch of stripAnsi(text)) n += charWidth(ch.codePointAt(0));
  return n;
}

// ---------------------------------------------------------------------------- lines

// segs(x) -> a line as an array of [text, style] segments.
export function segs(x) {
  if (x == null) return [];
  if (typeof x === 'string') return x ? [[x, '']] : [];
  return x.filter((s) => s != null && s !== '').map((s) => (typeof s === 'string' ? [s, ''] : [String(s[0]), s[1] || '']));
}

export const width = (line) => segs(line).reduce((n, [t]) => n + strWidth(t), 0);
export const plain = (line) => segs(line).map(([t]) => t).join('');

// cells(line) -> one {ch, st, w} per code point.
function cells(line) {
  const out = [];
  for (const [t, st] of segs(line)) for (const ch of t) out.push({ ch, st, w: charWidth(ch.codePointAt(0)) });
  return out;
}

function fromCells(cs) {
  const out = [];
  for (const c of cs) {
    const last = out[out.length - 1];
    if (last && last[1] === c.st) last[0] += c.ch; else out.push([c.ch, c.st]);
  }
  return out;
}

// fit(line, w) -> the line cut to w columns, ending with … when it was cut.
export function fit(line, w) {
  if (w <= 0) return [];
  if (width(line) <= w) return segs(line);
  const cs = cells(line);
  const kept = [];
  let n = 0;
  for (const c of cs) {
    if (n + c.w > w - 1) break;
    kept.push(c); n += c.w;
  }
  const st = kept.length ? kept[kept.length - 1].st : '';
  kept.push({ ch: '…', st, w: 1 });
  return fromCells(kept);
}

// wrap(line, w, hang) -> the line broken into lines of at most w columns: at the last space that
// fits, else (a word longer than a line) cut; continuation lines are indented by `hang` columns
// (default: the line's own indent + 2, so nothing wraps outside its indent).
export function wrap(line, w, hang) {
  const cs = cells(line);
  if (w < 4) w = 4;
  let lead = 0;
  while (lead < cs.length && cs[lead].ch === ' ') lead++;
  if (hang == null) hang = lead + 2 < w / 2 ? lead + 2 : 2;
  const lines = [];
  let cur = cs;
  let first = true;
  while (true) {
    const total = cur.reduce((n, c) => n + c.w, 0);
    if (total <= w) { lines.push(fromCells(cur)); break; }
    let n = 0, cut = 0, lastSpace = -1;
    const minBreak = first ? lead : hang;
    for (let i = 0; i < cur.length; i++) {
      if (n + cur[i].w > w) break;
      n += cur[i].w; cut = i + 1;
      if (cur[i].ch === ' ' && i > minBreak) lastSpace = i;
    }
    if (cur[cut] && cur[cut].ch === ' ') lastSpace = cut;
    let head, rest;
    if (lastSpace > minBreak) { head = cur.slice(0, lastSpace); rest = cur.slice(lastSpace); } else { head = cur.slice(0, Math.max(cut, 1)); rest = cur.slice(Math.max(cut, 1)); }
    while (head.length && head[head.length - 1].ch === ' ') head.pop();
    lines.push(fromCells(head));
    while (rest.length && rest[0].ch === ' ') rest.shift();
    if (!rest.length) break;
    const st = rest[0].st;
    cur = [...Array.from({ length: hang }, () => ({ ch: ' ', st: '', w: 1 })), ...rest];
    void st;
    first = false;
  }
  return lines;
}

// pad(line, w, style) -> the line fitted to w columns, then filled with spaces up to w.
export function pad(line, w, style = '') {
  const l = fit(line, w);
  const n = width(l);
  return n < w ? [...l, [' '.repeat(w - n), style]] : l;
}

// center(line, w) -> the line with left padding to center it within w.
export function center(line, w) {
  const n = width(line);
  return n >= w ? fit(line, w) : [[' '.repeat(Math.floor((w - n) / 2)), ''], ...segs(line)];
}

// ---------------------------------------------------------------------------- colours

const TRUE = /truecolor|24bit/i.test(process.env.COLORTERM || '');
const rgb = (fg, r, g, b, c256) => (TRUE ? `${fg ? 38 : 48};2;${r};${g};${b}` : `${fg ? 38 : 48};5;${c256}`);

export const PALETTE = {
  bold: '1',
  under: '4',
  orange: rgb(1, 217, 119, 87, 173),
  cyan: rgb(1, 86, 182, 194, 73),
  green: rgb(1, 126, 198, 153, 114),
  yellow: rgb(1, 229, 192, 123, 179),
  red: rgb(1, 224, 108, 117, 168),
  purple: rgb(1, 198, 120, 221, 176),
  white: rgb(1, 230, 230, 230, 254),
  dim: rgb(1, 139, 143, 152, 245),
  ghost: rgb(1, 92, 99, 112, 241),
  dark: rgb(1, 24, 26, 31, 234),
  // backgrounds
  bgCoach: rgb(0, 20, 40, 45, 23),
  bgOk: rgb(0, 19, 42, 30, 22),
  bgWarn: rgb(0, 45, 40, 18, 58),
  bgError: rgb(0, 48, 20, 22, 52),
  bgCyan: rgb(0, 86, 182, 194, 73),
  bgGreen: rgb(0, 126, 198, 153, 114),
  bgYellow: rgb(0, 229, 192, 123, 179),
  bgRed: rgb(0, 224, 108, 117, 168),
  bgOrange: rgb(0, 217, 119, 87, 173),
  bgPurple: rgb(0, 198, 120, 221, 176),
  bgTab: rgb(0, 58, 63, 75, 238),
  bgTabClaude: rgb(0, 58, 40, 34, 52),
  bgHeader: rgb(0, 30, 32, 38, 235),
};

let colorOn = true;
export const setColor = (on) => { colorOn = on; };
export const colorEnabled = () => colorOn;

function sgr(style) {
  if (!style) return '';
  return style.split(/\s+/).filter(Boolean).map((k) => PALETTE[k]).filter(Boolean).join(';');
}

// ansi(line, base) -> the line as a terminal string; `base` (e.g. a band's background) stays on
// under every segment.
export function ansi(line, base = '') {
  const l = segs(line);
  if (!colorOn) return plain(l);
  const b = sgr(base);
  let out = '';
  for (const [t, st] of l) {
    const s = [b, sgr(st)].filter(Boolean).join(';');
    out += `\x1b[0${s ? `;${s}` : ''}m${t}`;
  }
  return `${out}\x1b[0m`;
}

// ---------------------------------------------------------------------------- inline markup

// rich(text, base) -> a line from coach / agent text: `code`-like slash commands (/build-factory)
// in orange; everything else in `base`.
export function rich(text, base = '') {
  const out = [];
  const re = /(^|[\s(])(\/[a-z][a-z-]*)/g;
  let last = 0, m;
  while ((m = re.exec(text))) {
    const at = m.index + m[1].length;
    if (at > last) out.push([text.slice(last, at), base]);
    out.push([m[2], 'orange']);
    last = at + m[2].length;
  }
  if (last < text.length) out.push([text.slice(last), base]);
  return out;
}

// ---------------------------------------------------------------------------- components

// rule(label, w, extra, style) -> `──── label ──── extra ──…` filled to w.
export function rule(label, w, extra = [], style = 'cyan') {
  const head = [['──── ', style], [label, style], [' ────', style]];
  const ex = segs(extra);
  const line = ex.length ? [...head, [' ', ''], ...ex, [' ──', style]] : head;
  const n = width(line);
  return n < w ? [...line, ['─'.repeat(w - n), style]] : fit(line, w);
}

// dots(done, total) -> the progress dots: ● done, ◉ current, ○ to do.
export function dots(current, total, finished = false) {
  const out = [];
  for (let i = 0; i < total; i++) {
    if (finished || i < current) out.push(['●', 'cyan']);
    else if (i === current) out.push(['◉', 'orange']);
    else out.push(['○', 'dim']);
  }
  return out;
}

// box(lines, {w, color, title, padX}) -> the lines in a rounded frame of total width w; content
// lines are wrapped to the inner width.
export function box(content, { w, color = 'dim', title = null, padX = 2 }) {
  const inner = Math.max(4, w - 2 - 2 * padX);
  const out = [];
  if (title) {
    const t = [['╭─ ', color], ...segs(title), [' ', '']];
    const n = width(t);
    out.push([...fit(t, w - 1), ['─'.repeat(Math.max(0, w - 1 - n)), color], ['╮', color]]);
  } else out.push([['╭' + '─'.repeat(w - 2) + '╮', color]]);
  for (const line of content) {
    for (const l of wrap(line, inner)) {
      out.push([['│', color], [' '.repeat(padX), ''], ...pad(l, inner), [' '.repeat(padX), ''], ['│', color]]);
    }
  }
  out.push([['╰' + '─'.repeat(w - 2) + '╯', color]]);
  return out;
}

// cta(label, state) -> the call to action: the only highlighted element of the coach band.
export function cta(label, state = 'normal') {
  const bg = { normal: 'bgCyan', ok: 'bgGreen', warn: 'bgYellow', error: 'bgRed', bonus: 'bgPurple' }[state] || 'bgCyan';
  return [[` ${label} `, `${bg} dark bold`]];
}

export const COACH_BG = { normal: 'bgCoach', asking: 'bgCoach', ok: 'bgOk', warn: 'bgWarn', error: 'bgError' };

// coachBand({state, lines, cta, progress, label, w}) -> 4 lines: the rule with the progress, up to
// 2 lines of text, the call to action. The text never wraps: a coach line is cut to the width
// (the scenario linter keeps them short enough for an 80-column terminal).
export function coachBand({ state = 'normal', lines = [], action = '', progress = [], label = 'coach', w }) {
  const bg = COACH_BG[state] || 'bgCoach';
  const mark = state === 'ok' ? ['✓ ', 'green bold'] : state === 'warn' ? ['! ', 'yellow bold'] : state === 'error' ? ['✗ ', 'red bold'] : ['▸ ', 'cyan'];
  const rows = [[' ', ''], ...rule(label, w - 2, progress, state === 'ok' ? 'green' : state === 'warn' ? 'yellow' : 'cyan')];
  const text = lines.slice(0, 2);
  const body = [0, 1].map((i) => {
    if (i >= text.length) return [];
    const base = state === 'warn' ? 'yellow' : 'white';
    return [[' ', ''], i === 0 ? mark : ['  ', ''], ...rich(text[i], base)];
  });
  const ctaLine = action ? [[' ', ''], ...cta(action, state === 'asking' ? 'normal' : state)] : [];
  return [rows, ...body, ctaLine].map((l) => ({ line: pad(l, w), base: bg }));
}

// choiceList(choices, cursor, {recorded, frozen}) -> the agent's question choices, ❯ on the cursor.
export function choiceList(choices, cursor, { recorded = -1 } = {}) {
  return choices.map((c, i) => {
    const on = i === cursor;
    const mark = on ? ['  ❯ ', 'orange bold'] : ['    ', ''];
    const tail = i === recorded && !on ? [['  (recorded)', 'ghost']] : [];
    return [mark, [`${i + 1}. ${c}`, on ? 'orange' : 'white'], ...tail];
  });
}
