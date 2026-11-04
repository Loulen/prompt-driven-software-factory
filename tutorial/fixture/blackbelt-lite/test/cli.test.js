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
