import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const CLI = fileURLToPath(new URL('../src/cli.js', import.meta.url));

function cli(stateFile, ...args) {
  const result = spawnSync(process.execPath, [CLI, ...args], {
    encoding: 'utf8',
    env: { ...process.env, BLACKBELT_STATE: stateFile },
  });
  return { code: result.status, out: result.stdout, err: result.stderr };
}

function withState(fn) {
  const dir = mkdtempSync(join(tmpdir(), 'blackbelt-'));
  try {
    fn(join(dir, 'state.json'));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test('list shows the seeded belts', () =>
  withState((state) => {
    const { code, out } = cli(state, 'list');
    assert.equal(code, 0);
    assert.match(out, /B-2 {2}ada {2}craft {2}ORANGE {2}IN_PROGRESS/);
  }));

test('show lists a belt objectives with their status', () =>
  withState((state) => {
    const { out } = cli(state, 'show', 'B-2');
    assert.match(out, /\[x\] 1\. Pair-program a kata with TDD {2}VALIDATED/);
    assert.match(out, /\[ \] 2\. Run a refactoring workshop {2}TODO/);
  }));

test('a request is saved and visible in the next command', () =>
  withState((state) => {
    assert.match(cli(state, 'request', 'ada', 'cloud').out, /Requested WHITE belt in cloud for ada: B-5/);
    assert.match(cli(state, 'list', 'ada').out, /B-5 {2}ada {2}cloud {2}WHITE {2}REQUESTED/);
  }));

test('a mentor walks a belt from request to validated objectives', () =>
  withState((state) => {
    cli(state, 'request', 'ada', 'cloud');
    assert.match(cli(state, 'assign-mentor', 'B-5', 'margaret').out, /MENTOR_ASSIGNED/);
    assert.match(cli(state, 'add-objective', 'B-5', 'margaret', 'Write', 'a', 'Dockerfile').out, /objective 1 added — Write a Dockerfile/);
    assert.match(cli(state, 'validate-objective', 'B-5', '1', 'margaret').out, /objective 1 validated/);
    assert.match(cli(state, 'show', 'B-5').out, /IN_PROGRESS[\s\S]*\[x\] 1\. Write a Dockerfile/);
  }));

test('a domain rule violation is refused with exit code 2', () =>
  withState((state) => {
    const { code, err } = cli(state, 'request', 'ada', 'craft');
    assert.equal(code, 2);
    assert.match(err, /refused: ada already has an open belt in craft: B-2/);
  }));

test('the belt\'s consultant submits their finished belt; it then awaits a sensei', () =>
  withState((state) => {
    const { code, out } = cli(state, 'submit', 'B-3', 'linus');
    assert.equal(code, 0);
    assert.equal(out, 'B-3: NEED_VALIDATION\n');
    assert.match(cli(state, 'show', 'B-3').out, /B-3 {2}linus {2}cloud {2}WHITE {2}NEED_VALIDATION/);
    assert.match(cli(state, 'decide', 'B-3', 'margaret', 'validated').out, /B-3: VALIDATED/);
  }));

test('a submission with objectives still to validate is refused and names them', () =>
  withState((state) => {
    const { code, err } = cli(state, 'submit', 'B-2', 'ada');
    assert.equal(code, 2);
    assert.equal(err, 'refused: belt B-2 has objectives still to validate: 2. Run a refactoring workshop\n');
    assert.match(cli(state, 'show', 'B-2').out, /B-2 {2}ada {2}craft {2}ORANGE {2}IN_PROGRESS/);
  }));

test('only the belt\'s consultant submits it, and only once', () =>
  withState((state) => {
    const notTheirs = cli(state, 'submit', 'B-3', 'ada');
    assert.equal(notTheirs.code, 2);
    assert.match(notTheirs.err, /^refused: only the belt's consultant \(linus\) can submit it/);
    const nobody = cli(state, 'submit', 'B-3', 'nobody');
    assert.equal(nobody.code, 2);
    assert.match(nobody.err, /^refused: only the belt's consultant/);
    cli(state, 'submit', 'B-3', 'linus');
    const again = cli(state, 'submit', 'B-3', 'linus');
    assert.equal(again.code, 2);
    assert.match(again.err, /^refused: belt B-3 is NEED_VALIDATION: only a belt in progress can be submitted/);
  }));

test('the usage lists submit', () =>
  withState((state) => {
    assert.match(cli(state, 'help').out, /submit <belt> <consultant>/);
  }));

test('an unknown command prints the usage', () =>
  withState((state) => {
    const { code, err } = cli(state, 'frobnicate');
    assert.equal(code, 1);
    assert.match(err, /unknown command: frobnicate/);
  }));

test('reset restores the seed', () =>
  withState((state) => {
    cli(state, 'request', 'ada', 'cloud');
    cli(state, 'reset');
    assert.doesNotMatch(cli(state, 'list').out, /B-5/);
  }));
