#!/usr/bin/env node
// PDSF Tutorial — the tutorial app (Node 18, zero npm dependency, raw ANSI).
//
// One terminal app, two screens and a coach:
//   * the TUTORIAL SHELL — a fake prompt where the deterministic commands run FOR REAL on the
//     workspace (the install, `code .`, ls / cat / git…);
//   * the SIMULATED HARNESS — a Claude Code look-alike that replays recordings of real runs
//     (questions as arrow-key lists, file writes as diffs) and applies their files with rec_apply,
//     so typing `claude` here never launches the learner's real agent;
//   * the COACH — a band at the bottom: at most 2 lines, one call to action, progress dots.
// It plays tutorial/scenario/scenario.json (format: tutorial/README.md § Scenario format).
//
// Launched by tutorial.sh, with:
//   PDSF_TUTO_WORKSPACE  the tutorial workspace (a git repo seeded from the fixture)   — required
//   PDSF_TUTO_ROOT       the tutorial/ folder of the resolved PDSF source (default: this one)
//   PDSF_TUTO_SRC        the resolved PDSF source (default: PDSF_TUTO_ROOT/..)
//   PDSF_TUTO_SCRIPT     scripted input instead of the keyboard: `auto` (the recorded path), or a
//                        file of lines/keys (see tutorial/README.md § Scripted input)
//   PDSF_TUTO_FRAMES     a file to append every rendered screen to (tests: widths, coach lines)
//   PDSF_TUTO_FAST       `1`: no streaming animation
//   PDSF_TUTO_NO_IDE     `1`: never launch an IDE (`code .` then reports no IDE)
//
// Exit status: 0 done · 75 the learner asked to restart · 130 quit (progress saved) · 3 the
// scripted input ran out · 1 error (e.g. a failing step check).
import { spawn, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import * as ui from './ui.mjs';
import { TUTORIAL_ROOT, loadScenario, sub, accepts, stepDir } from './scenario.mjs';
import { Keys, ScriptEnd } from './keys.mjs';
import { parseTap, summarize, storyOf, testArgs } from './readers.mjs';

const ENV = process.env;
const ROOT = path.resolve(ENV.PDSF_TUTO_ROOT || TUTORIAL_ROOT);
const SRC = path.resolve(ENV.PDSF_TUTO_SRC || path.join(ROOT, '..'));
const WS = ENV.PDSF_TUTO_WORKSPACE ? path.resolve(ENV.PDSF_TUTO_WORKSPACE) : '';
const HOME = os.homedir();
const tilde = (p) => (HOME && p.startsWith(`${HOME}/`) ? `~${p.slice(HOME.length)}` : p);

const EXIT = { done: 0, error: 1, script: 3, restart: 75, quit: 130 };
// Off-script commands the tutorial shell runs for real: they only read the workspace.
const SAFE = new Set(['ls', 'cat', 'head', 'tail', 'wc', 'pwd', 'tree', 'git', 'node', 'echo', 'grep', 'find']);
const SAFE_GIT = new Set(['log', 'status', 'diff', 'show', 'branch', 'ls-files']);
const IDES = { code: 'VS Code', 'code-insiders': 'VS Code', cursor: 'Cursor', codium: 'VSCodium', windsurf: 'Windsurf', zed: 'Zed', subl: 'Sublime Text', idea: 'IntelliJ IDEA', webstorm: 'WebStorm' };

class Interrupt extends Error {}
class Fatal extends Error {}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------------------------------------------------------------------------- workspace

const shEnv = () => ({ ...ENV, PDSF_TUTO_ROOT: ROOT, PDSF_TUTO_SRC: SRC, PDSF_TUTO_WORKSPACE: WS, PDSF_TUTO_HARNESS: 'claude', GIT_PAGER: 'cat', PAGER: 'cat' });

function git(...args) {
  const r = spawnSync('git', ['-C', WS, ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
  return r.status === 0 ? r.stdout.replace(/\n$/, '') : '';
}

// run(cmd, args) -> {code, out} — async, so the screen and the keyboard stay alive meanwhile.
function run(cmd, args, { cwd = WS, timeout = 120000 } = {}) {
  return new Promise((resolve) => {
    let out = '';
    let child;
    try {
      child = spawn(cmd, args, { cwd, env: shEnv(), stdio: ['ignore', 'pipe', 'pipe'] });
    } catch (e) { resolve({ code: 127, out: String(e.message) }); return; }
    const timer = setTimeout(() => child.kill('SIGTERM'), timeout);
    child.stdout.on('data', (d) => { out += d; });
    child.stderr.on('data', (d) => { out += d; });
    child.on('error', (e) => { clearTimeout(timer); resolve({ code: 127, out: String(e.message) }); });
    child.on('close', (code) => { clearTimeout(timer); resolve({ code: code ?? 1, out }); });
  });
}
const sh = (script, ...args) => run('sh', ['-c', script, 'sh', ...args]);

// ---------------------------------------------------------------------------- the app

class App {
  constructor(scenario) {
    this.sc = scenario;
    this.texts = scenario.texts || {};
    this.tty = Boolean(process.stdout.isTTY && process.stdin.isTTY && !ENV.PDSF_TUTO_SCRIPT);
    this.keys = new Keys({ tty: this.tty, script: ENV.PDSF_TUTO_SCRIPT || '' });
    this.animate = this.tty && ENV.PDSF_TUTO_FAST !== '1';
    ui.setColor(this.tty && !ENV.NO_COLOR && ENV.TERM !== 'dumb');
    this.framesFile = ENV.PDSF_TUTO_FRAMES || '';
    this.lastFrame = '';
    this.progressFile = path.join(WS, '.git', 'pdsf-tutorial.json');
    this.vars = { ws: tilde(WS) };
    this.screen = 'shell';
    this.view = 'card'; // card | screen
    this.card = null;
    this.header = '';
    this.scroll = { shell: [], harness: [] };
    this.coach = null;
    this.mode = 'idle'; // input | ask | idle
    this.input = '';
    this.ghost = '';
    this.unlocked = false;
    this.stepIndex = -1;
    this.branch = git('symbolic-ref', '--short', '-q', 'HEAD');
    this.push('shell', [[this.t('shellBanner'), 'dim']]);
    this.push('shell', '');
  }

  t(key, vars = {}) {
    const v = this.texts[key];
    if (Array.isArray(v)) return v.map((l) => sub(l, { ...this.vars, ...vars }));
    return sub(v ?? key, { ...this.vars, ...vars });
  }

  // ------------------------------------------------------------------ output

  log(text) { if (!this.tty) process.stdout.write(`${text}\n`); }

  push(screen, entry) {
    this.scroll[screen].push(entry);
    if (!this.tty) {
      const lines = typeof entry === 'function' ? entry(80) : [entry];
      for (const l of lines) this.log(ui.plain(l));
    }
    this.render();
  }

  setCoach(state, lines, action, { progress } = {}) {
    this.coach = { state, lines, action, progress: progress ?? this.progress() };
    if (!this.tty) {
      this.log(`── coach ${ui.plain(this.coach.progress)} [${state}] ──`);
      for (const l of lines) this.log(`  ${l}`);
      if (action) this.log(`  [ ${action} ]`);
    }
    this.render();
  }

  progress() {
    const step = this.sc.steps[this.stepIndex];
    if (!step) return [];
    const n = step.chapter.steps.length;
    const label = step.chapter.label ? [[`${step.chapter.label} `, 'purple']] : [];
    return [...label, ...ui.dots(step.indexInChapter, n), [` ${step.indexInChapter + 1}/${n}`, 'cyan']];
  }

  size() {
    const cols = Math.max(40, Number(ENV.PDSF_TUTO_COLS) || process.stdout.columns || 80);
    const rows = Math.max(16, Number(ENV.PDSF_TUTO_ROWS) || process.stdout.rows || 24);
    return { cols, rows };
  }

  render() {
    if (!this.started || (!this.tty && !this.framesFile)) return;
    const { cols, rows } = this.tty ? { cols: process.stdout.columns || 80, rows: process.stdout.rows || 24 } : this.size();
    const frame = this.compose(cols, rows);
    if (this.tty) {
      const out = frame.map(({ line, base }) => ui.ansi(ui.pad(line, cols, ''), base));
      process.stdout.write(`\x1b[H${out.join('\r\n')}`);
    }
    if (this.framesFile) {
      const text = frame.map(({ line }) => ui.plain(line).replace(/\s+$/, '')).join('\n');
      if (text !== this.lastFrame) {
        fs.appendFileSync(this.framesFile, `${text}\n\f\n`);
        this.lastFrame = text;
      }
    }
  }

  // compose(cols, rows) -> exactly `rows` lines of at most `cols` columns: header, body, coach.
  compose(cols, rows) {
    const L = (line, base = '') => ({ line: ui.fit(line, cols), base });
    const header = this.headerLine(cols);
    const coach = this.coach ? ui.coachBand({ ...this.coach, w: cols }) : [];
    const bodyH = rows - 1 - coach.length;
    let body = this.view === 'card' ? this.cardBody(cols, bodyH) : this.screen === 'harness' ? this.harnessBody(cols, bodyH) : this.shellBody(cols, bodyH);
    body = body.slice(-bodyH);
    while (body.length < bodyH) body.unshift([]);
    return [L(header, 'bgHeader'), ...body.map((l) => L(l)), ...coach.map(({ line, base }) => L(line, base))];
  }

  headerLine(cols) {
    const left = [[' PDSF tutorial', 'white bold'], [' · ', 'dim'], [this.header, 'white']];
    if (this.view === 'card') return left;
    const sh = this.screen === 'shell';
    const right = [[' shell ', sh ? 'bgTab white bold' : 'dim'], [' ', ''], [' claude · simulated ', sh ? 'dim' : 'bgTabClaude orange']];
    const gap = cols - ui.width(left) - ui.width(right) - 1;
    return gap > 0 ? [...left, [' '.repeat(gap), ''], ...right] : left;
  }

  // scrollLines(screen, w) -> the screen's scrollback, rendered and wrapped to w columns.
  scrollLines(screen, w) {
    const out = [];
    for (const e of this.scroll[screen]) {
      const lines = typeof e === 'function' ? e(w) : [e];
      for (const l of lines) out.push(...(ui.width(l) > w ? ui.wrap(l, w) : [ui.segs(l)]));
    }
    return out;
  }

  inputLine(prefix) {
    const typed = [[this.input, 'white']];
    if (this.mode !== 'input') return [...prefix];
    const rest = this.ghost.startsWith(this.input) ? this.ghost.slice(this.input.length) : '';
    return [...prefix, ...typed, [' ', 'bgCyan'], [rest, 'ghost']];
  }

  shellBody(cols, h) {
    const w = cols - 2;
    const lines = this.scrollLines('shell', w).map((l) => [[' ', ''], ...l]);
    if (this.mode === 'input') {
      const prompt = this.promptSegs();
      for (const l of ui.wrap(this.inputLine(prompt), w, 2)) lines.push([[' ', ''], ...l]);
    }
    return lines.slice(-h);
  }

  promptSegs() {
    const name = path.basename(WS);
    return [[name, 'green'], [` (${this.branch || 'detached'})`, 'purple'], [' $ ', 'white bold']];
  }

  welcomeBox(cols) {
    const w = Math.min(cols - 2, 52);
    const [l1, l2] = this.t('harnessLines');
    return ui.box([
      [['✻ ', 'orange'], [this.t('harnessTitle'), 'orange'], ['  ', ''], [' SIMULATED ', 'bgOrange dark bold']],
      [['  ', ''], [l1, 'dim']],
      [['  ', ''], [l2, 'dim']],
    ], { w, color: 'orange', padX: 1 }).map((l) => [[' ', ''], ...l]);
  }

  harnessBody(cols, h) {
    const w = cols - 2;
    const inputBox = ui.box([this.inputLine([['> ', 'dim']])], { w, color: 'dim', padX: 1 }).map((l) => [[' ', ''], ...l]);
    const bottom = [[], ...inputBox, [], [['  ', ''], [this.t('harnessHint'), 'dim']]];
    const top = h >= 16 ? this.welcomeBox(cols) : [];
    const room = Math.max(0, h - bottom.length - top.length);
    const lines = this.scrollLines('harness', w).map((l) => [[' ', ''], ...l]).slice(-room || Infinity);
    return [...top, ...(room ? lines : []), ...bottom];
  }

  cardBody(cols, h) {
    if (!this.card) return [];
    const w = Math.min(cols - 4, this.card.width || 66);
    const boxed = ui.box(this.card.lines, { w, color: this.card.color, title: this.card.title, padX: 3 });
    const left = Math.max(0, Math.floor((cols - w) / 2));
    const lines = boxed.map((l) => [[' '.repeat(left), ''], ...l]);
    const foot = this.card.footer ? [[], [['  ', ''], [this.card.footer, 'dim']]] : [];
    // A short terminal drops the footer first, then the card's bottom (its top says what it is).
    const below = lines.length + foot.length + 1 <= h ? foot : [];
    const pad = Math.max(0, Math.floor((h - lines.length - below.length) / 2));
    return [...Array.from({ length: pad }, () => []), ...lines, ...below, []].slice(0, h);
  }

  // ------------------------------------------------------------------ input

  autoLine() { return this.input ? 'enter' : 'tab'; }

  // readLine(step) -> the line the learner submits ('' for an empty one); `?` asks for a hint,
  // twice for the tutorial to do the step; Tab fills the ghost text in.
  async readLine(step) {
    this.mode = 'input';
    this.input = '';
    let hints = 0;
    for (;;) {
      this.ghost = this.expectedHere(step);
      this.render();
      const k = await this.keys.next(() => this.autoLine());
      if (k === 'ctrl-c') throw new Interrupt();
      if (k === 'enter') { const line = this.input; this.input = ''; this.mode = 'idle'; return line; }
      if (k === 'tab' || k === 'right') { if (this.ghost.startsWith(this.input)) this.input = this.ghost; continue; }
      if (k === 'backspace') { this.input = Array.from(this.input).slice(0, -1).join(''); continue; }
      if (k === 'ctrl-d' && !this.input) continue;
      if (k === '?' && !this.input) {
        hints++;
        if (hints === 1) {
          if (step.screen !== this.screen) this.setCoach('normal', this.t(this.screen === 'shell' ? 'needHarness' : 'needShell'), `Type ${this.expectedHere(step)}`);
          else this.setCoach('normal', [step.hint ? sub(step.hint, this.vars) : this.t('almost', { name: this.nameOf(step) })[0]], sub(step.cta, this.vars));
          continue;
        }
        this.setCoach('normal', this.t('stuck'), this.t('stuckCta'));
        this.render();
        const k2 = await this.keys.next('enter');
        if (k2 === 'ctrl-c') throw new Interrupt();
        if (k2 === 'enter') { this.input = ''; this.mode = 'idle'; hints = 0; this.stepCoach(step); return this.expectedHere(step); }
        hints = 0;
        this.stepCoach(step);
        continue;
      }
      if (k.length === 1) this.input += k;
    }
  }

  expectedHere(step) {
    if (step.screen === this.screen) return step.expect;
    return this.screen === 'shell' ? 'claude' : '/exit';
  }

  nameOf(step) { return step.name || step.expect; }

  async waitKey(auto, accept) {
    for (;;) {
      const k = await this.keys.next(auto);
      if (k === 'ctrl-c') throw new Interrupt();
      if (!accept || accept.includes(k)) return k;
    }
  }

  stepCoach(step) { this.setCoach('normal', step.coach.map((l) => sub(l, this.vars)), sub(step.cta, this.vars)); }

  // ------------------------------------------------------------------ progress

  loadProgress() {
    try { return JSON.parse(fs.readFileSync(this.progressFile, 'utf8')); } catch { return null; }
  }

  saveProgress(step) {
    const data = { step, vars: this.vars, unlocked: this.unlocked, screen: this.screen, intro: true };
    fs.writeFileSync(this.progressFile, `${JSON.stringify(data, null, 2)}\n`);
  }

  // ------------------------------------------------------------------ the journey

  async main() {
    this.started = true;
    const saved = this.loadProgress();
    let start = 0;
    if (saved && saved.intro) {
      start = Math.min(saved.step || 0, this.sc.steps.length);
      Object.assign(this.vars, saved.vars || {}, { ws: tilde(WS) });
      this.unlocked = Boolean(saved.unlocked);
    } else {
      await this.introCard();
      this.saveProgress(0);
    }
    for (let i = start; i < this.sc.steps.length; i++) {
      const step = this.sc.steps[i];
      if (i === start && start > 0) this.resumeAt(i);
      if (step.indexInChapter === 0 && step.chapter.card) {
        const skip = await this.chapterCard(step.chapter);
        if (skip) { i += step.chapter.steps.length - 1; this.saveProgress(i + 1); continue; }
      }
      await this.playStep(i);
    }
    return this.endCard();
  }

  resumeAt(i) {
    const step = this.sc.steps[i];
    this.stepIndex = i;
    this.view = 'screen';
    this.header = step.chapter.title;
    if (this.unlocked && step.screen === 'harness') this.screen = 'harness';
    this.push(this.screen, [[this.t('resumed', { n: step.indexInChapter + 1, total: step.chapter.steps.length }), 'cyan']]);
  }

  async introCard() {
    const intro = this.sc.intro;
    const c = intro.card;
    const ms = [];
    (c.milestones || []).forEach((m, i) => { ms.push([`${i + 1} `, 'cyan'], ...ui.rich(m, 'cyan'), ['    ', '']); });
    this.view = 'card';
    this.header = intro.header || 'Intro';
    this.card = {
      color: 'orange',
      lines: [[[c.title, 'orange']], [], ms, ...c.lines.map((l) => this.cardLine(l))],
      footer: sub(c.footer || '', this.vars),
    };
    this.log(`PDSF tutorial — ${c.title}`);
    for (const l of this.card.lines) this.log(`  ${ui.plain(l)}`);
    this.setCoach('normal', intro.coach.map((l) => sub(l, this.vars)), intro.cta, { progress: [['~10 min', 'cyan']] });
    await this.waitKey('enter', ['enter']);
  }

  cardLine(l) {
    if (typeof l === 'string') return l ? [[sub(l, this.vars), 'white']] : [];
    if (l.dim) return [[sub(l.dim, this.vars), 'dim']];
    if (l.ok) return [[sub(l.ok, this.vars), 'green']];
    if (l.cmd) return [[sub(l.cmd, this.vars), 'cyan']];
    if (l.simulated) {
      const t = sub(l.simulated, this.vars);
      const i = t.indexOf('SIMULATED');
      return i < 0 ? [[t, 'orange']] : [[t.slice(0, i), 'orange'], [' SIMULATED ', 'bgOrange dark bold'], [t.slice(i + 9), 'orange']];
    }
    if (l.link) return [[`${l.link[0]}  `, 'dim'], [l.link[1], 'green under']];
    if (l.bonus) return [[sub(l.bonus, this.vars), 'purple']];
    if (l.story) return [[l.story[0], 'purple bold'], ['  ', ''], [sub(l.story[1], this.vars), 'dim']];
    if (l.flow) {
      // `a → b → c`: slash commands in orange, the rest (node --test) in green, arrows dim.
      return l.flow.flatMap((x, i) => [...(i ? [[' → ', 'dim']] : []), [x, x.startsWith('/') ? 'orange' : 'green']]);
    }
    if (l.keys) return l.keys.flatMap(([k, label], i) => [...(i ? [['        ', '']] : []), [`[ ${k} ]`, 'cyan'], [` ${label}`, 'dim']]);
    return [];
  }

  // chapterCard(chapter) -> true when the learner skips the chapter (`s`). Used by the bonus
  // chapter: Enter plays it.
  async chapterCard(chapter) {
    const c = chapter.card;
    this.view = 'card';
    this.header = chapter.title;
    this.card = { color: 'purple', width: c.width, title: [[sub(c.title || chapter.title, this.vars), 'purple']], lines: (c.lines || []).map((l) => this.cardLine(l)) };
    for (const l of this.card.lines) this.log(`  ${ui.plain(l)}`);
    this.stepIndex = this.sc.steps.indexOf(chapter.steps[0]);
    this.setCoach('normal', c.coach.map((l) => sub(l, this.vars)), c.cta);
    const k = await this.waitKey('enter', ['enter', 's']);
    return k === 's';
  }

  async endCard() {
    const end = this.sc.end;
    this.stepIndex = -1;
    this.view = 'card';
    this.header = end.header || 'Done';
    this.vars.commits = this.vars.commits || git('rev-list', '--count', 'main..HEAD');
    this.card = { color: 'green', width: 76, lines: end.card.lines.map((l) => this.cardLine(l)) };
    this.log('PDSF tutorial — end');
    for (const l of this.card.lines) this.log(`  ${ui.plain(l)}`);
    const last = this.sc.steps.length;
    this.saveProgress(last);
    this.setCoach('normal', end.coach.map((l) => sub(l, this.vars)), end.cta, { progress: [...ui.dots(0, this.sc.chapters[0].steps.length, true), [' done', 'cyan']] });
    const k = await this.waitKey('q', ['q', 'r', 'enter']);
    return k === 'r' ? 'restart' : 'done';
  }

  async playStep(i) {
    const step = this.sc.steps[i];
    this.stepIndex = i;
    this.view = 'screen';
    this.header = step.chapter.title;
    this.log(`\n### step ${i + 1}/${this.sc.steps.length}: ${step.chapter.id}/${step.id} (${step.kind})`);

    if (step.kind === 'read') {
      if (step.tip) this.push(step.screen, (w) => this.tipBox(step.tip, w));
      if (step.story) this.push(step.screen, this.storyBox(step.story));
      this.stepCoach(step);
      await this.waitKey('enter', ['enter']);
      this.saveProgress(i + 1);
      return;
    }

    this.stepCoach(step);
    let skipped = false;
    for (;;) {
      const line = (await this.readLine(step)).trim().replace(/\s+/g, ' ');
      if (step.skip && line === step.skip && this.screen === step.screen) {
        this.push(this.screen, this.promptEcho(line));
        skipped = true;
        break;
      }
      if (this.screen === step.screen && accepts(step, line)) {
        if (step.effect !== 'clear') this.push(this.screen, this.promptEcho(line));
        skipped = !(await this.execute(step, line));
        break;
      }
      await this.offScript(step, line);
    }
    if (step.dir) await this.check(step);
    this.branch = git('symbolic-ref', '--short', '-q', 'HEAD');
    this.saveProgress(i + 1);
    const done = skipped && step.skipped ? step.skipped : step.done;
    this.setCoach('ok', done.map((l) => sub(l, this.vars)), this.t('doneCta'));
    await this.waitKey('enter', ['enter']);
  }

  promptEcho(line) {
    return this.screen === 'shell' ? [...this.promptSegs(), [line, 'white']] : [['> ', 'dim'], [line, 'white bold']];
  }

  // execute(step, line) -> false when the step's effect could not happen (no IDE): the step
  // then ends with its `skipped` coach.
  async execute(step, line) {
    if (step.effect === 'harness') { this.enterHarness(); return true; }
    if (step.effect === 'help') { this.showHelp(step); return true; }
    if (step.effect === 'clear') { this.clearHarness(); return true; }
    if (step.effect === 'shell') { this.leaveHarness(); return true; }
    if (step.effect === 'ide') return this.openIde(line);
    if (step.effect === 'test') { await this.runTests(step); return true; }
    const dir = stepDir(this.sc, step);
    if (step.play) { await this.play(step, dir); return true; }
    if (dir && fs.existsSync(path.join(dir, 'action.sh'))) {
      this.setCoach('normal', step.coach.map((l) => sub(l, this.vars)), 'running for real…');
      const r = await sh('sh "$1"', path.join(dir, 'action.sh'));
      for (const l of r.out.replace(/\n$/, '').split('\n')) {
        const v = l.match(/^@var ([a-z_]+)=(.*)$/);
        if (v) { this.vars[v[1]] = v[2]; continue; }
        if (l.startsWith('✓')) this.push(this.screen, [['✓', 'green'], [l.slice(1), 'white']]);
        else this.push(this.screen, [[l, 'dim']]);
      }
      if (r.code !== 0) throw new Fatal(`the action of ${step.id} failed (exit ${r.code})`);
    }
    return true;
  }

  enterHarness() {
    this.unlocked = true;
    this.screen = 'harness';
    this.scroll.harness = [];
    this.log('[screen: claude · simulated]');
    this.render();
  }

  leaveHarness() {
    this.screen = 'shell';
    this.log('[screen: shell]');
    this.push('shell', [['(left the simulated harness)', 'dim']]);
  }

  showHelp(step) {
    const dir = ['.claude/skills', '.agents/skills'].map((d) => path.join(WS, d)).find((d) => fs.existsSync(d));
    const skills = dir ? fs.readdirSync(dir).filter((n) => fs.existsSync(path.join(dir, n, 'SKILL.md'))).sort() : [];
    const where = dir ? path.relative(WS, dir) : 'no skills installed';
    this.push('harness', [['PDSF skills', 'orange'], [` (${skills.length} · ${where})`, 'dim']]);
    const help = step.help || {};
    const shown = Object.keys(help).filter((s) => skills.includes(s));
    const w = Math.max(0, ...shown.map((s) => s.length + 1));
    for (const s of shown) this.push('harness', [['  ', ''], [`/${s}`.padEnd(w + 2), 'orange'], [help[s], 'dim']]);
    const also = (step.also || []).filter((s) => skills.includes(s));
    const more = skills.length - shown.length - also.length;
    if (also.length || more > 0) {
      this.push('harness', [['  ', ''], [also.map((s) => `/${s}`).join(' '), 'orange'], [more > 0 ? ` ⋯ and ${more} more` : '', 'dim']]);
    }
  }

  clearHarness() {
    this.scroll.harness = [];
    this.log('[harness cleared]');
    this.push('harness', [['> ', 'dim'], ['/clear', 'white bold']]);
    this.push('harness', [['(no content)', 'dim']]);
  }

  async openIde(line) {
    const cmd = line.split(' ')[0];
    const found = ENV.PDSF_TUTO_NO_IDE === '1' ? false
      : spawnSync('sh', ['-c', 'command -v "$1"', 'sh', cmd], { stdio: 'ignore' }).status === 0;
    if (!found) {
      this.push('shell', [[this.t('noIde', { cmd }), 'dim']]);
      return false;
    }
    try {
      const child = spawn(cmd, ['.'], { cwd: WS, detached: true, stdio: 'ignore', env: ENV });
      child.on('error', () => {});
      child.unref();
    } catch { return false; }
    this.vars.ide = IDES[cmd] || cmd;
    this.push('shell', [['✓', 'green'], [` ${this.vars.ide} opened on ${tilde(WS)}`, 'white']]);
    return true;
  }

  // ------------------------------------------------------------------ off-script

  async offScript(step, line) {
    const almost = () => {
      if (step.screen === 'harness' && this.screen === 'shell') return this.setCoach('warn', this.t('needHarness'), 'Type claude');
      if (step.screen === 'shell' && this.screen === 'harness') return this.setCoach('warn', this.t('needShell'), 'Type /exit');
      return this.setCoach('warn', this.t('almost', { name: this.nameOf(step) }), sub(step.cta, this.vars));
    };
    if (this.screen === 'shell') {
      this.push('shell', this.promptEcho(line));
      if (!line) return;
      const [cmd, sub1] = line.split(' ');
      if (line === 'claude') {
        if (this.unlocked) { this.enterHarness(); this.stepCoach(step); return; }
        almost(); return;
      }
      if (step.screen === 'harness' && line.startsWith('/')) { almost(); return; }
      if (cmd === 'cd') { this.push('shell', [[this.t('shellCd'), 'dim']]); almost(); return; }
      if (SAFE.has(cmd) && (cmd !== 'git' || SAFE_GIT.has(sub1)) && (cmd !== 'node' || sub1 === '--test') && !/[;&|`$><]/.test(line)) {
        const r = await sh(line.replace(/^git /, 'git -c color.ui=never '));
        const out = r.out.replace(/\n$/, '');
        const lines = out ? out.split('\n') : [];
        const max = 40;
        for (const l of lines.slice(0, max)) this.push('shell', [[l.replace(/\t/g, '    '), 'white']]);
        if (lines.length > max) this.push('shell', [[`… ${lines.length - max} more lines`, 'dim']]);
        this.branch = git('symbolic-ref', '--short', '-q', 'HEAD');
        almost();
        return;
      }
      this.push('shell', [[this.t('shellUnknown', { cmd }), 'dim']]);
      almost();
      return;
    }
    // harness
    if (!line) return;
    if (line === '/clear') { this.clearHarness(); return; }
    this.push('harness', this.promptEcho(line));
    if (line === '/exit' || line === '/quit') {
      this.leaveHarness();
      if (step.screen === 'harness') this.setCoach('warn', this.t('leftHarness'), 'Type claude');
      else this.stepCoach(step);
      return;
    }
    if (line === '/help') { this.showHelp(this.sc.steps.find((s) => s.effect === 'help') || {}); return; }
    if (line.startsWith('/')) { this.push('harness', [[this.t('notRecorded', { cmd: line.split(' ')[0] }), 'dim']]); almost(); return; }
    this.push('harness', [[this.t('simulatedReply'), 'dim']]);
    almost();
  }

  // ------------------------------------------------------------------ agent steps

  async play(step, dir) {
    const before = git('rev-parse', 'HEAD');
    const items = step.play;
    const asks = items.filter((it) => 'ask' in it).length;
    let askNo = 0;
    let applied = null;
    let ff = !this.animate;
    const total = items.reduce((n, it) => n + ('checks' in it ? Math.ceil(it.checks.length / 2) + 1 : 'writes' in it ? it.writes.length * 2 : 1), 0);
    const delay = Math.max(60, Math.min(400, Math.floor(3000 / Math.max(1, total))));
    const working = () => this.setCoach('normal', step.coach.map((l) => sub(l, this.vars)), this.t('workingCta'));
    working();
    for (const item of items) {
      if ('ask' in item) {
        askNo++;
        await this.ask(item, askNo, asks);
        ff = !this.animate;
        working();
        continue;
      }
      if (('writes' in item || 'commit' in item) && !applied) applied = await this.apply(dir, before);
      for (const line of this.itemLines(item, applied)) {
        this.push('harness', line);
        if (!ff) {
          await sleep(delay);
          if (this.keys.pending()) {
            const k = this.keys.take();
            if (k === 'ctrl-c') throw new Interrupt();
            ff = true;
          }
        }
      }
    }
    if (!applied) await this.apply(dir, before);
  }

  async ask(item, n, total) {
    const entry = { cursor: item.pick };
    this.push('harness', [[item.ask, 'white bold']]);
    this.push('harness', '');
    const list = (w) => ui.choiceList(item.choices, entry.cursor, { recorded: entry.done ? item.pick : -1 }).map((l) => ui.fit(l, w));
    this.scroll.harness.push(list);
    item.choices.forEach((c, i) => this.log(`  ${i === item.pick ? '❯' : ' '} ${i + 1}. ${c}`));
    this.setCoach('asking', this.t('asking', { n, total }), this.t('askingCta'));
    for (;;) {
      this.render();
      const k = await this.keys.next('enter');
      if (k === 'ctrl-c') throw new Interrupt();
      if (k === 'up') entry.cursor = (entry.cursor + item.choices.length - 1) % item.choices.length;
      else if (k === 'down') entry.cursor = (entry.cursor + 1) % item.choices.length;
      else if (/^[1-9]$/.test(k) && Number(k) <= item.choices.length) entry.cursor = Number(k) - 1;
      else if (k === 'enter') break;
    }
    entry.done = true;
    this.log(`  answered: ${entry.cursor + 1}. ${item.choices[entry.cursor]}`);
    if (entry.cursor !== item.pick) {
      this.push('harness', [['  ', ''], [this.t('offPath', { pick: item.pick + 1 }), 'yellow']]);
    }
    this.render();
  }

  // apply(dir, before) -> what the recording changed, from real git, once rec_apply (the same
  // replay the recorder checks) wrote the recorded files and committed them.
  async apply(dir, before) {
    const r = await sh('. "$PDSF_TUTO_ROOT/lib/scenario.sh" && . "$PDSF_TUTO_ROOT/lib/recording.sh" && rec_apply "$1"', dir);
    if (r.code !== 0) throw new Fatal(`applying the recording of ${path.relative(path.join(ROOT, 'scenario'), dir)} failed:\n${r.out}`);
    const head = git('rev-parse', 'HEAD');
    const stat = {};
    const changed = [];
    if (head !== before) {
      for (const l of git('diff', '--numstat', '--no-renames', before, head).split('\n').filter(Boolean)) {
        const [add, del, p] = l.split('\t');
        stat[p] = { add, del };
        changed.push(p);
      }
    }
    const adrDir = path.join(WS, 'docs', 'adr');
    this.vars.files = String(changed.length);
    this.vars.adrs = String(fs.existsSync(adrDir) ? fs.readdirSync(adrDir).filter((f) => f.endsWith('.md')).length : 0);
    this.vars.commits = git('rev-list', '--count', 'main..HEAD');
    this.branch = git('symbolic-ref', '--short', '-q', 'HEAD');
    // A run that worked on a branch then merged it (`via`): the work is the merged-in commit.
    const merged = git('rev-parse', '-q', '--verify', 'HEAD^2');
    const work = merged || 'HEAD';
    return {
      before, head, changed, stat,
      short: git('rev-parse', '--short', work), subject: git('log', '-1', '--format=%s', work),
      merge: merged ? { short: git('rev-parse', '--short', 'HEAD'), from: git('name-rev', '--name-only', '--exclude=tags/*', merged), into: this.branch } : null,
    };
  }

  itemLines(item, applied) {
    if ('tool' in item) {
      const l = [['⏺ ', 'green'], [item.tool, 'white']];
      if (item.note) l.push([`  ${item.note}`, item.style || 'dim']);
      return [l];
    }
    if ('say' in item) {
      const t = item.say;
      if (!t) return [''];
      if (t.startsWith('# ')) return [[[t.slice(2), 'white bold']]];
      return [ui.rich(t, item.style || 'white')];
    }
    if ('writes' in item) {
      const listed = item.writes.map((w) => w.path);
      const pool = item.more === 'ADRs' ? applied.changed.filter((p) => /^docs\/adr\/.*\.md$/.test(p)) : applied.changed;
      const more = pool.filter((p) => !listed.includes(p)).length;
      const out = item.writes.map((w, i) => {
        const l = [['⏺ ', 'green'], [`Write(${w.path})`, 'white']];
        if (w.note) l.push([`  ${w.note}`, 'dim']);
        if (i === item.writes.length - 1 && more > 0) l.push([`  +${more} ${item.more || 'files'}`, 'dim']);
        return l;
      });
      if (item.stat) {
        const w = Math.max(...listed.map((p) => p.length)) + 2;
        for (const p of listed) {
          const s = applied.stat[p];
          if (!s) continue;
          const l = [['  + ', 'green'], [p.padEnd(w), 'green'], [`+${s.add}`, 'green']];
          if (s.del && s.del !== '0') l.push([` -${s.del}`, 'red']);
          out.push(l);
        }
      }
      return out;
    }
    if ('commit' in item) {
      if (applied.head === applied.before) return [];
      const out = [[['⏺ ', 'green'], ['commit  ', 'white'], [applied.short, 'yellow'], [` ${applied.subject}`, 'white']]];
      const m = applied.merge;
      if (m) out.push([['⏺ ', 'green'], ['merge   ', 'white'], [m.short, 'yellow'], [` ${m.from} → ${m.into}`, 'white']]);
      return out;
    }
    if ('checks' in item) {
      const out = [];
      const w = Math.max(...item.checks.map((c) => c.length)) + 3;
      for (let i = 0; i < item.checks.length; i += 2) {
        const l = [['  ✓ ', 'green'], [item.checks[i].padEnd(w), 'white']];
        if (item.checks[i + 1]) l.push(['✓ ', 'green'], [item.checks[i + 1], 'white']);
        out.push(l);
      }
      if (item.na) out.push([['  – ', 'dim'], [item.na, 'dim']]);
      return out;
    }
    return [];
  }

  // storyBox(story) -> a scrollback entry: the business story the agent will design, read from the
  // workspace file: its title, its `section` (the intention), and how many business rules it has.
  storyBox(story) {
    let st = { title: '', items: [] };
    let rules = 0;
    try {
      const md = fs.readFileSync(path.join(WS, story.file), 'utf8');
      st = storyOf(md, story.section || 'INTENTION');
      rules = storyOf(md, 'BUSINESS RULES').items.length;
    } catch { /* shown as its label only */ }
    const label = [[sub(story.label || story.file, this.vars), 'purple']];
    return (w) => {
      const rows = [[[st.title || story.file, 'white bold']]];
      for (const it of st.items) rows.push([[it, 'white']]);
      if (rules) rows.push([[`${rules} business rules in the file: open it in your IDE`, 'dim']]);
      return ui.box(rows, { w: Math.min(w, 78), color: 'purple', title: label, padX: 1 });
    };
  }

  // runTests(step) — the step's command (`node --test`), FOR REAL in the workspace, shown as a
  // summary: the tests per file, the ones new since `main` (what the bonus added), the totals.
  async runTests(step) {
    this.setCoach('normal', step.coach.map((l) => sub(l, this.vars)), 'running for real…');
    const r = await run('node', testArgs());
    const testDir = path.join(WS, 'test');
    const files = fs.existsSync(testDir) ? fs.readdirSync(testDir).filter((f) => /\.(test\.)?m?js$/.test(f)).sort() : [];
    const name = (f) => f.replace(/\.test\.m?js$|\.m?js$/, '');
    const now = Object.fromEntries(files.map((f) => [name(f), fs.readFileSync(path.join(testDir, f), 'utf8')]));
    const before = Object.fromEntries(files.map((f) => [name(f), git('show', `main:test/${f}`)]));
    const sum = summarize(parseTap(r.out), now, before);
    const line = [];
    sum.files.forEach((f, i) => {
      if (i) line.push(['   ', '']);
      line.push([f.failed ? '✖ ' : '✔ ', f.failed ? 'red' : 'green'], [f.name, 'white'], [` (${f.count})`, 'dim']);
    });
    if (line.length) this.push('shell', line);
    const shown = 3;
    for (const t of sum.fresh.slice(0, shown)) {
      this.push('shell', [[t.ok ? '✔ ' : '✖ ', t.ok ? 'green' : 'red'], [`${t.file} › `, 'dim'], [t.title, 'white'], [' (new)', 'orange']]);
    }
    if (sum.fresh.length > shown) this.push('shell', [['  ', ''], [`… and ${sum.fresh.length - shown} more new tests`, 'dim']]);
    for (const t of sum.failed.slice(0, 5)) this.push('shell', [['✖ ', 'red'], [t.title, 'red']]);
    const c = sum.counts;
    this.push('shell', [['ℹ ', 'cyan'], [`tests ${c.tests}  pass ${c.pass}  fail ${c.fail}`, c.fail ? 'red' : 'white']]);
    Object.assign(this.vars, { tests: String(c.tests), pass: String(c.pass), fail: String(c.fail), fresh: String(sum.fresh.length) });
    this.log(`  node --test: exit ${r.code}, ${c.pass}/${c.tests} pass, ${sum.fresh.length} new`);
  }

  tipBox(tip, w) {
    const bar = 16;
    const lw = Math.max(...tip.rows.map((r) => r.label.length)) + 2;
    const rows = tip.rows.map((r) => [
      [r.label.padEnd(lw), 'yellow'],
      ['■'.repeat(r.fill), r.color || 'dim'], ['·'.repeat(bar - r.fill), 'ghost'],
      [`  ${r.note}`, 'yellow'],
    ]);
    return ['', ...ui.box(rows, { w: Math.min(w, lw + bar + 26), color: 'yellow', title: [[tip.title, 'yellow']], padX: 1 })];
  }

  async check(step) {
    const dir = stepDir(this.sc, step);
    const r = await sh('. "$PDSF_TUTO_ROOT/lib/scenario.sh" && tuto_run_check "$1"', dir);
    const lines = r.out.replace(/\n$/, '').split('\n').filter(Boolean);
    if (r.code === 0) {
      this.log(`  check ${step.id}: ${lines.filter((l) => l.includes('✓')).length} ✓, all pass`);
      return;
    }
    for (const l of lines) this.push(this.screen, [[l, l.includes('✗') ? 'red' : 'dim']]);
    this.setCoach('error', this.t('checkFailed'), this.t('checkFailedCta'));
    await this.waitKey('enter', ['enter']).catch(() => {});
    throw new Fatal(`the check of ${step.id} failed`);
  }
}

// ---------------------------------------------------------------------------- main

async function main() {
  if (!WS || !fs.existsSync(path.join(WS, '.git'))) {
    process.stderr.write('PDSF tutorial: PDSF_TUTO_WORKSPACE must point at the tutorial workspace (a git repo). Start it with tutorial.sh.\n');
    return EXIT.error;
  }
  const app = new App(loadScenario(ROOT));
  if (!app.tty && !ENV.PDSF_TUTO_SCRIPT) {
    process.stderr.write('PDSF tutorial: no terminal. Run it in a terminal, or set PDSF_TUTO_SCRIPT=auto to play the recorded path.\n');
    return EXIT.error;
  }
  const restore = () => {
    if (!app.tty) return;
    process.stdout.write('\x1b[0m\x1b[?25h\x1b[?1049l');
    try { process.stdin.setRawMode(false); } catch { /* not a tty any more */ }
  };
  if (app.tty) {
    process.stdout.write('\x1b[?1049h\x1b[?25l\x1b[2J');
    process.stdout.on('resize', () => app.render());
  }
  const onSignal = () => { restore(); app.saveProgress(Math.max(0, app.stepIndex)); farewell('quit', app); process.exit(EXIT.quit); };
  process.on('SIGINT', onSignal);
  process.on('SIGTERM', onSignal);
  let outcome;
  try {
    outcome = await app.main();
  } catch (e) {
    restore();
    if (e instanceof Interrupt) { farewell('quit', app); return EXIT.quit; }
    if (e instanceof ScriptEnd) {
      const s = app.sc.steps[app.stepIndex];
      process.stderr.write(`PDSF tutorial: the scripted input ran out at step ${s ? `${s.chapter.id}/${s.id}` : app.stepIndex}.\n`);
      return EXIT.script;
    }
    process.stderr.write(`PDSF tutorial: error: ${e instanceof Fatal ? e.message : e.stack || e}\n`);
    process.stderr.write(`Your workspace is intact: ${WS}\n`);
    return EXIT.error;
  }
  restore();
  farewell(outcome, app);
  return outcome === 'restart' ? EXIT.restart : EXIT.done;
}

// farewell(outcome) — the last words, on the normal screen (the app's screen is gone by then).
function farewell(outcome, app) {
  const out = (s) => process.stdout.write(`${s}\n`);
  if (outcome === 'restart') { out('PDSF tutorial: starting over with a fresh workspace…'); return; }
  if (outcome === 'quit') {
    const s = app.sc.steps[app.stepIndex];
    const at = s ? ` at step ${s.indexInChapter + 1}/${s.chapter.steps.length} (${s.chapter.title})` : '';
    out(`PDSF tutorial: progress saved${at}. Re-run the same command to resume.`);
    out(`Your workspace stays in ${WS}`);
    return;
  }
  out('PDSF tutorial: done. Your factory is built.');
  out(`Your workspace stays in ${WS}`);
  out('Tomorrow, on your project:');
  out('  curl -fsSL https://raw.githubusercontent.com/Loulen/prompt-driven-software-factory/main/install.sh | sh');
  out('  claude   then  /build-factory');
}

main().then((code) => process.exit(code), (e) => { process.stderr.write(`${e.stack || e}\n`); process.exit(EXIT.error); });
