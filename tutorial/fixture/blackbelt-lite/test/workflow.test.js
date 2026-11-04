import { test } from 'node:test';
import assert from 'node:assert/strict';
import { canTransition, isClosed } from '../src/workflow.js';

test('the belt workflow moves forward one step at a time', () => {
  assert.ok(canTransition('REQUESTED', 'MENTOR_ASSIGNED'));
  assert.ok(canTransition('MENTOR_ASSIGNED', 'IN_PROGRESS'));
  assert.ok(canTransition('IN_PROGRESS', 'NEED_VALIDATION'));
  assert.ok(canTransition('NEED_VALIDATION', 'VALIDATED'));
  assert.ok(canTransition('NEED_VALIDATION', 'REFUSED'));
});

test('the belt workflow cannot skip a step or go back', () => {
  assert.equal(canTransition('REQUESTED', 'IN_PROGRESS'), false);
  assert.equal(canTransition('IN_PROGRESS', 'VALIDATED'), false);
  assert.equal(canTransition('IN_PROGRESS', 'MENTOR_ASSIGNED'), false);
  assert.equal(canTransition('VALIDATED', 'REFUSED'), false);
});

test('VALIDATED and REFUSED are the closed statuses', () => {
  assert.ok(isClosed('VALIDATED'));
  assert.ok(isClosed('REFUSED'));
  assert.equal(isClosed('NEED_VALIDATION'), false);
});
