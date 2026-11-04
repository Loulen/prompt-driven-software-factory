// PDSF Tutorial — unit tests of the tutorial app's building blocks: display widths and wrapping
// (no line wider than the terminal), key parsing, scripted input, the scenario and its linter.
//
//   node --test tutorial/test/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import * as ui from '../app/ui.mjs';
import { parseKeys, parseScript } from '../app/keys.mjs';
import { loadScenario, lint, accepts, sub, transcriptTurns, stepDir, TUTORIAL_ROOT, COACH_MAX } from '../app/scenario.mjs';

const W = (lines) => Math.max(...lines.map((l) => ui.width(l)));

test('display width: wide emoji count 2, combining marks 0, escapes ignored', () => {
  assert.equal(ui.strWidth('abc'), 3);
  assert.equal(ui.strWidth('🎉 done'), 7);
  assert.equal(ui.strWidth('✅'), 2);
  assert.equal(ui.strWidth('é'), 1);
  assert.equal(ui.strWidth('\x1b[1mbold\x1b[0m'), 4);
  assert.equal(ui.strWidth('⏺ ❯ ✓ ● ◉ ○ ─ │'), 15);
});

test('fit cuts to the width with …, never inside a wide character', () => {
  assert.deepEqual(ui.plain(ui.fit('hello world', 8)), 'hello w…');
  assert.equal(ui.width(ui.fit('🎉🎉🎉🎉', 5)), 5);
  assert.equal(ui.plain(ui.fit('short', 10)), 'short');
  assert.equal(ui.width(ui.fit([['ab', 'cyan'], ['cdef', 'orange']], 4)), 4);
});

test('wrap keeps every line within the width, breaks at spaces, hangs under the indent', () => {
  const text = '  this is a long line of text that must wrap nicely at the spaces it has';
  const lines = ui.wrap(text, 20);
  assert.ok(W(lines) <= 20);
  assert.ok(lines.length > 2);
  for (const l of lines.slice(1)) assert.match(ui.plain(l), /^ {4}\S/);
  assert.equal(lines.map((l) => ui.plain(l).trim()).join(' '), text.trim());
});

test('wrap cuts a word longer than the line (code, URLs) and loses nothing', () => {
  const url = 'https://raw.githubusercontent.com/Loulen/prompt-driven-software-factory/main/install.sh';
  const lines = ui.wrap(`$ curl -fsSL ${url} | sh`, 30);
  assert.ok(W(lines) <= 30);
  assert.equal(lines.map((l) => ui.plain(l)).join('').replace(/ /g, ''), `$ curl -fsSL ${url} | sh`.replace(/ /g, ''));
});

test('wrap keeps the styles of the segments it splits', () => {
  const lines = ui.wrap([['aaaa bbbb ', 'cyan'], ['cccc dddd', 'orange']], 10);
  assert.ok(lines.flat().some(([, st]) => st === 'orange'));
  assert.ok(W(lines) <= 10);
});

test('components never exceed their width', () => {
  for (const w of [40, 60, 80, 120]) {
    const band = ui.coachBand({ state: 'ok', lines: ['x'.repeat(200), 'y'], action: 'Enter ↵ next', progress: ui.dots(3, 9), w });
    assert.equal(band.length, 4, 'the coach band is 4 rows: rule, 2 lines, call to action');
    for (const { line } of band) assert.ok(ui.width(line) <= w);
    const box = ui.box(['a long line '.repeat(20), '🎉 emoji line'], { w, color: 'orange' });
    for (const l of box) assert.equal(ui.width(l), w);
    assert.ok(ui.width(ui.rule('coach', w, ui.dots(1, 9))) <= w);
  }
});

test('progress dots: done, current, to do', () => {
  assert.equal(ui.plain(ui.dots(2, 5)), '●●◉○○');
  assert.equal(ui.plain(ui.dots(0, 3, true)), '●●●');
});

test('rich text paints slash commands', () => {
  const l = ui.rich('Now run /build-factory again (or /verify-factory).');
  assert.deepEqual(l.filter(([, st]) => st === 'orange').map(([t]) => t), ['/build-factory', '/verify-factory']);
  assert.equal(ui.plain(l), 'Now run /build-factory again (or /verify-factory).');
});

test('parseKeys: arrows, enter, tab, backspace, ctrl-c, pasted text', () => {
  assert.deepEqual(parseKeys(Buffer.from('\x1b[A\x1b[B\r\t\x7f\x03')), ['up', 'down', 'enter', 'tab', 'backspace', 'ctrl-c']);
  assert.deepEqual(parseKeys(Buffer.from('\x1b[200~ls\x1b[201~')), ['l', 's']);
  assert.deepEqual(parseKeys(Buffer.from('é🎉')), ['é', '🎉']);
  assert.deepEqual(parseKeys(Buffer.from('\x1b')), ['esc']);
});

test('parseScript: typed lines end with Enter, {key} is one key, {auto} switches to the recorded path', () => {
  const keys = parseScript('# comment\nls\n{down}\n{?}\n\n{auto}\n');
  assert.deepEqual(keys.slice(0, 5), ['l', 's', 'enter', 'down', '?']);
  assert.deepEqual(keys[5], { auto: true });
});

test('the scenario is valid: kinds, coach ≤ 2 short lines, expected inputs, recordings', () => {
  const sc = loadScenario();
  assert.deepEqual(lint(sc), []);
  assert.equal(sc.format, 2);
  assert.ok(sc.steps.length >= 9);
  for (const s of sc.steps) assert.ok(['do', 'read'].includes(s.kind));
});

test('chapter one: install, code ., claude, /help, /build-factory ×2 around /clear, /verify-factory', () => {
  const sc = loadScenario();
  const ch = sc.chapters[0];
  assert.deepEqual(ch.steps.map((s) => s.expect || `(${s.kind})`),
    [ch.steps[0].expect, 'code .', 'claude', '/help', '/build-factory', '(read)', '/clear', '/build-factory', '/verify-factory']);
  assert.match(ch.steps[0].expect, /^curl -fsSL https:\/\/raw\.githubusercontent\.com\/.*\/install\.sh \| sh$/);
  const why = ch.steps.find((s) => s.id === 'why-twice');
  assert.ok(why.coach.join(' ').match(/context/i) && why.coach.join(' ').match(/hallucination/i));
  for (const s of ch.steps.filter((x) => x.expect?.startsWith('/') && x.expect !== '/help' && x.expect !== '/clear')) {
    assert.ok(fs.existsSync(path.join(TUTORIAL_ROOT, '..', 'skills', s.expect.slice(1), 'SKILL.md')), `${s.expect} is a real PDSF skill`);
  }
});

test('every played step replays the recording of its own command, and its questions are recorded answers', () => {
  const sc = loadScenario();
  for (const s of sc.steps.filter((x) => x.play)) {
    const dir = stepDir(sc, s);
    const transcript = fs.readFileSync(path.join(dir, 'recording', 'transcript.md'), 'utf8');
    assert.match(transcript, new RegExp(`^command: ${s.expect.replace(/[/]/g, '\\/')}$`, 'm'));
    const turns = transcriptTurns(dir);
    for (const q of s.play.filter((i) => 'ask' in i)) assert.equal(turns[q.turn - 1].role, 'learner');
  }
});

test('accepts: the expected input, its accepted variants, nothing else', () => {
  const sc = loadScenario();
  const install = sc.steps.find((s) => s.id === 'install');
  assert.ok(accepts(install, install.expect));
  assert.ok(accepts(install, 'curl -fsSL https://example.org/pdsf/install.sh | sh'));
  assert.ok(!accepts(install, 'curl https://example.org/other.sh'));
  const ide = sc.steps.find((s) => s.id === 'ide');
  assert.ok(accepts(ide, 'code .') && accepts(ide, 'cursor  .') && !accepts(ide, 'vim'));
  assert.equal(sub('{a} and {b}', { a: 1 }), '1 and {b}');
});

// A broken copy of the scenario, to see the linter refuse it.
function brokenScenario(mutate) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pdsf-lint-'));
  fs.cpSync(path.join(TUTORIAL_ROOT, 'scenario'), path.join(dir, 'scenario'), { recursive: true });
  const file = path.join(dir, 'scenario', 'scenario.json');
  const json = JSON.parse(fs.readFileSync(file, 'utf8'));
  mutate(json);
  fs.writeFileSync(file, JSON.stringify(json));
  const problems = lint(loadScenario(dir));
  fs.rmSync(dir, { recursive: true, force: true });
  return problems.join('\n');
}

test('the linter refuses: 3 coach lines, a too long line, a bad kind, a do step without input', () => {
  assert.match(brokenScenario((j) => { j.chapters[0].steps[0].coach.push('three'); }), /install\.coach: must be 1 to 2 lines/);
  assert.match(brokenScenario((j) => { j.chapters[0].steps[1].coach[0] = 'x'.repeat(COACH_MAX + 1); }), /ide\.coach: line longer/);
  assert.match(brokenScenario((j) => { j.chapters[0].steps[2].kind = 'agent'; }), /claude: kind must be/);
  assert.match(brokenScenario((j) => { delete j.chapters[0].steps[3].expect; }), /help: a do step needs its expected input/);
  assert.match(brokenScenario((j) => { delete j.chapters[0].steps[5].cta; }), /why-twice: a call to action/);
  assert.match(brokenScenario((j) => { j.chapters[0].steps[4].done = ['a', 'b', 'c']; }), /scaffold\.done: must be 1 to 2 lines/);
  assert.match(brokenScenario((j) => { j.texts.asking.push('more'); }), /texts\.asking: must be 1 to 2 lines/);
});

test('the linter refuses: a missing recording or check, a question that is not a recorded answer', () => {
  assert.match(brokenScenario((j) => { j.chapters[0].steps[4].dir = '01-build-the-factory/99-nope'; }), /no check\.sh|no recording/);
  assert.match(brokenScenario((j) => { j.chapters[0].steps[4].play.find((i) => i.ask).turn = 2; }), /turn 2 is not a recorded learner answer/);
  assert.match(brokenScenario((j) => { j.chapters[0].steps[4].play.find((i) => i.ask).pick = 9; }), /pick is not one of its choices/);
  assert.match(brokenScenario((j) => { j.chapters[0].steps[0].accept = '^nope$'; }), /expect does not match accept/);
});
