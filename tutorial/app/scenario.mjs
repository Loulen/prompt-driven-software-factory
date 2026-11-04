// PDSF Tutorial — the scenario: loader and linter (Node 18, zero dependency).
//
// The scenario is tutorial/scenario/scenario.json (format 2, documented in tutorial/README.md
// § Scenario format). The terminal app reads it; so can any other surface (a playground…).
//
//   node tutorial/app/scenario.mjs lint      checks the scenario; exit 1 with one line per problem
//   node tutorial/app/scenario.mjs steps     lists the steps: <chapter>/<id> <kind> <screen> <expect>
import { readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { strWidth } from './ui.mjs';

export const TUTORIAL_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

// A coach line must fit an 80-column terminal next to its marker: 2 lines on screen, never more.
export const COACH_MAX = 74;
export const KINDS = ['do', 'read'];
export const SCREENS = ['shell', 'harness'];
export const EFFECTS = ['ide', 'harness', 'shell', 'help', 'clear'];

// Typical values of the coach placeholders, to lint the lengths as the learner will see them.
export const SAMPLE_VARS = { ws: '~/pdsf-tutorial/blackbelt', skills: '16', files: '10', adrs: '3', commits: '3', ide: 'VS Code', n: '1', total: '2', pick: '1', name: '/build-factory' };

// The app's own coach texts (scenario.texts): the ones shown in the coach band.
export const COACH_TEXTS = ['asking', 'almost', 'needHarness', 'needShell', 'leftHarness', 'stuck', 'checkFailed'];

export function loadScenario(root = TUTORIAL_ROOT) {
  const file = join(root, 'scenario', 'scenario.json');
  const scenario = JSON.parse(readFileSync(file, 'utf8'));
  scenario.root = root;
  scenario.steps = [];
  for (const chapter of scenario.chapters || []) {
    for (const [i, step] of (chapter.steps || []).entries()) {
      step.chapter = chapter;
      step.indexInChapter = i;
      scenario.steps.push(step);
    }
  }
  return scenario;
}

// sub(text, vars) -> text with its {name} placeholders filled (unknown ones kept as typed).
export const sub = (text, vars = {}) => String(text).replace(/\{([a-z_]+)\}/g, (m, k) => (vars[k] != null ? String(vars[k]) : m));

export const stepDir = (scenario, step) => (step.dir ? join(scenario.root, 'scenario', step.dir) : null);

// accepts(step, input) -> the input is the step's expected input (exactly, or matching `accept`).
export function accepts(step, input) {
  const t = input.trim().replace(/\s+/g, ' ');
  if (t === step.expect) return true;
  return step.accept ? new RegExp(step.accept).test(t) : false;
}

// transcriptTurns(dir) -> [{role, choices}] of the step's recording.
export function transcriptTurns(dir) {
  const text = readFileSync(join(dir, 'recording', 'transcript.md'), 'utf8');
  const turns = [];
  for (const line of text.split('\n')) {
    const m = line.match(/^<!-- pdsf-turn: (learner|agent) -->$/);
    if (m) { turns.push({ role: m[1], choices: null }); continue; }
    const c = line.match(/^<!-- pdsf-choices: (.*) -->$/);
    if (c && turns.length) turns[turns.length - 1].choices = c[1].split(' | ').filter(Boolean);
  }
  return turns;
}

// lint(scenario) -> a list of problems (empty: the scenario is valid).
export function lint(scenario) {
  const problems = [];
  const bad = (where, what) => problems.push(`${where}: ${what}`);
  const coachText = (where, lines, { max = 2, required = true } = {}) => {
    if (lines == null) { if (required) bad(where, 'missing'); return; }
    if (!Array.isArray(lines) || lines.length < 1 || lines.length > max) {
      bad(where, `must be 1 to ${max} lines (has ${Array.isArray(lines) ? lines.length : 'not a list'})`);
      return;
    }
    for (const l of lines) {
      if (typeof l !== 'string' || !l.trim()) { bad(where, 'empty line'); continue; }
      const n = strWidth(sub(l, SAMPLE_VARS));
      if (n > COACH_MAX) bad(where, `line longer than ${COACH_MAX} columns (${n}): ${l}`);
    }
  };

  if (scenario.format !== 2) bad('scenario', 'format must be 2');
  if (!scenario.intro?.card) bad('intro', 'the intro card is missing');
  coachText('intro.coach', scenario.intro?.coach);
  if (!scenario.intro?.cta) bad('intro.cta', 'a call to action is required');
  if (!scenario.end?.card) bad('end', 'the end card is missing');
  coachText('end.coach', scenario.end?.coach);
  if (!scenario.end?.cta) bad('end.cta', 'a call to action is required');
  if (!scenario.chapters?.length) bad('scenario', 'no chapter');
  for (const k of COACH_TEXTS) coachText(`texts.${k}`, scenario.texts?.[k]);
  for (const k of ['askingCta', 'workingCta', 'doneCta', 'stuckCta', 'checkFailedCta']) if (!scenario.texts?.[k]) bad(`texts.${k}`, 'missing');
  for (const chapter of scenario.chapters || []) {
    if (!chapter.card) continue;
    coachText(`${chapter.id}.card.coach`, chapter.card.coach);
    if (!chapter.card.cta) bad(`${chapter.id}.card.cta`, 'a call to action is required');
  }

  const ids = new Set();
  for (const step of scenario.steps) {
    const where = `${step.chapter.id}/${step.id}`;
    if (!step.id) bad(where, 'no id');
    if (ids.has(step.id)) bad(where, 'duplicate id');
    ids.add(step.id);
    if (!KINDS.includes(step.kind)) bad(where, `kind must be one of ${KINDS.join(' | ')}`);
    if (!SCREENS.includes(step.screen)) bad(where, `screen must be one of ${SCREENS.join(' | ')}`);
    coachText(`${where}.coach`, step.coach);
    if (!step.cta) bad(where, 'a call to action (cta) is required');
    if (step.kind === 'do') {
      if (!step.expect) bad(where, 'a do step needs its expected input (expect)');
      if (step.accept) {
        try {
          if (!new RegExp(step.accept).test(step.expect)) bad(where, 'expect does not match accept');
        } catch (e) { bad(where, `accept is not a valid regex: ${e.message}`); }
      }
      coachText(`${where}.done`, step.done);
      coachText(`${where}.hint`, step.hint == null ? null : [step.hint], { max: 1 });
      coachText(`${where} (almost)`, (scenario.texts?.almost || []).map((l) => sub(l, { name: step.name || step.expect })));
      if (step.skip) coachText(`${where}.skipped`, step.skipped);
    } else if (step.kind === 'read') {
      if (step.expect || step.play || step.effect) bad(where, 'a read step has no input, play nor effect');
    }
    if (step.effect && !EFFECTS.includes(step.effect)) bad(where, `unknown effect ${step.effect}`);
    const dir = stepDir(scenario, step);
    if (dir) {
      if (!existsSync(join(dir, 'check.sh'))) bad(where, `no check.sh in ${step.dir}`);
    }
    if (step.play) {
      if (!dir) { bad(where, 'a played step needs its dir (recording)'); continue; }
      if (!existsSync(join(dir, 'recording', 'transcript.md'))) { bad(where, `no recording in ${step.dir}`); continue; }
      const turns = transcriptTurns(dir);
      for (const item of step.play) {
        if (!('ask' in item)) continue;
        if (!Array.isArray(item.choices) || item.choices.length < 2) bad(where, `question "${item.ask}" needs at least 2 choices`);
        if (!(item.pick >= 0 && item.pick < (item.choices || []).length)) bad(where, `question "${item.ask}": pick is not one of its choices`);
        const t = turns[item.turn - 1];
        if (!t || t.role !== 'learner' || !t.choices) bad(where, `question "${item.ask}": turn ${item.turn} is not a recorded learner answer with choices`);
      }
    }
  }
  return problems;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const cmd = process.argv[2];
  const scenario = loadScenario(process.argv[3] || TUTORIAL_ROOT);
  if (cmd === 'lint') {
    const problems = lint(scenario);
    for (const p of problems) console.log(p);
    process.exit(problems.length ? 1 : 0);
  } else if (cmd === 'steps') {
    for (const s of scenario.steps) console.log([`${s.chapter.id}/${s.id}`, s.kind, s.screen, s.expect || '-'].join('\t'));
  } else {
    console.error('usage: node scenario.mjs lint|steps [TUTORIAL_ROOT]');
    process.exit(2);
  }
}
