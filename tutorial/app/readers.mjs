// PDSF Tutorial — readers of what the workspace really holds (Node 18, zero dependency): the
// output of a real `node --test`, a business story of the local business backlog. Pure functions:
// the app feeds them real files and real output; the unit tests feed them samples.

// parseTap(text) -> {tests: [{title, ok}], counts: {tests, pass, fail}} from `node --test` TAP
// output (its default reporter when stdout is not a terminal, Node 18 to 22). Only top-level tests
// count (a describe()'s inner tests are indented); the `# tests / pass / fail` summary wins when
// present.
export function parseTap(text) {
  const tests = [];
  const counts = {};
  for (const line of String(text).split('\n')) {
    const m = line.match(/^(not ok|ok) \d+ - (.*?)(?: # (?:SKIP|TODO)\b.*)?$/);
    if (m) {
      tests.push({ title: m[2].replace(/\\#/g, '#').replace(/\\\\/g, '\\'), ok: m[1] === 'ok' });
      continue;
    }
    const c = line.match(/^# (tests|pass|fail) (\d+)$/);
    if (c) counts[c[1]] = Number(c[2]);
  }
  const pass = tests.filter((t) => t.ok).length;
  return {
    tests,
    counts: { tests: counts.tests ?? tests.length, pass: counts.pass ?? pass, fail: counts.fail ?? tests.length - pass },
  };
}

// quoted(title) -> the ways a test title can be written in a JS source file.
const quoted = (title) => [`'${title}'`, `"${title}"`, `\`${title}\``, `'${title.replace(/'/g, "\\'")}'`];

// fileOf(title, sources) -> the name of the source (a {name: text} map) that declares this test
// title, or '' when none does.
export function fileOf(title, sources) {
  const forms = quoted(title);
  for (const [name, text] of Object.entries(sources)) if (forms.some((f) => text.includes(f))) return name;
  for (const [name, text] of Object.entries(sources)) if (text.includes(title)) return name;
  return '';
}

// summarize(tap, sources, before) -> what the tutorial shows of a test run: the tests per file
// (`sources`: the test files now, {name: text}), and the tests that are new since `before` (the
// same files at an earlier commit, {name: text}).
export function summarize(tap, sources, before) {
  const files = [];
  const byFile = new Map();
  const fresh = [];
  for (const t of tap.tests) {
    const file = fileOf(t.title, sources) || '?';
    if (!byFile.has(file)) { byFile.set(file, { name: file, count: 0, failed: 0 }); files.push(byFile.get(file)); }
    const f = byFile.get(file);
    f.count++;
    if (!t.ok) f.failed++;
    if (!fileOf(t.title, before)) fresh.push({ ...t, file });
  }
  return { files, fresh, failed: tap.tests.filter((t) => !t.ok), counts: tap.counts };
}

// storyOf(markdown, section) -> {title, items}: a business story's title (its `# ` heading) and the
// items of one of its `**SECTION**` blocks: its numbered or bulleted items (continuation lines
// joined), or its paragraphs when it has no list.
export function storyOf(markdown, section = 'BUSINESS RULES') {
  const lines = String(markdown).split('\n');
  const title = (lines.find((l) => l.startsWith('# ')) || '').slice(2).trim();
  const items = [];
  let inside = false;
  let para = false;
  for (const line of lines) {
    const h = line.match(/^\*\*([A-Z][A-Z ]*)\*\*\s*$/);
    if (h) { inside = h[1] === section; continue; }
    if (!inside) continue;
    const it = line.match(/^\s*(?:\d+\.|-)\s+(.*)$/);
    if (it) { items.push(it[1].trim()); para = false; continue; }
    if (!line.trim()) { para = false; continue; }
    if (items.length && (para || /^\s/.test(line))) items[items.length - 1] += ` ${line.trim()}`;
    else { items.push(line.trim()); para = true; }
  }
  const clean = (t) => t.replace(/\*\*(.+?)\*\*/g, '$1').replace(/`([^`]+)`/g, '$1');
  return { title: clean(title), items: items.map(clean) };
}
