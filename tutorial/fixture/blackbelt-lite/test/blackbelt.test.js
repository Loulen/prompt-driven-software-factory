import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Blackbelt, DomainError } from '../src/blackbelt.js';

const people = [
  { id: 'ada', name: 'Ada', roles: ['consultant'] },
  { id: 'grace', name: 'Grace', roles: ['consultant', 'mentor'] },
  { id: 'margaret', name: 'Margaret', roles: ['mentor', 'sensei'] },
];
const disciplines = [{ id: 'craft', name: 'Software Craftsmanship' }];

function blackbelt(belts = []) {
  return new Blackbelt({ disciplines, people, belts });
}

function belt(overrides) {
  return {
    id: 'B-1',
    consultantId: 'ada',
    disciplineId: 'craft',
    color: 'WHITE',
    status: 'VALIDATED',
    mentorId: 'grace',
    objectives: [],
    ...overrides,
  };
}

test('a consultant with no belt requests the WHITE belt', () => {
  const requested = blackbelt().requestBelt('ada', 'craft');
  assert.equal(requested.color, 'WHITE');
  assert.equal(requested.status, 'REQUESTED');
  assert.equal(requested.mentorId, null);
});

test('a consultant requests the belt after their highest validated one', () => {
  const bb = blackbelt([belt({ id: 'B-1', color: 'WHITE' }), belt({ id: 'B-2', color: 'ORANGE' })]);
  const requested = bb.requestBelt('ada', 'craft');
  assert.equal(requested.color, 'GREEN');
  assert.equal(requested.id, 'B-3');
});

test('a refused belt does not count: the same colour is requested again', () => {
  const bb = blackbelt([belt({ color: 'WHITE' }), belt({ id: 'B-2', color: 'ORANGE', status: 'REFUSED' })]);
  assert.equal(bb.requestBelt('ada', 'craft').color, 'ORANGE');
});

test('only one open belt per discipline', () => {
  const bb = blackbelt([belt({ status: 'IN_PROGRESS' })]);
  assert.throws(() => bb.requestBelt('ada', 'craft'), /already has an open belt/);
});

test('nothing can be requested after the BLACK belt', () => {
  const bb = blackbelt([belt({ color: 'BLACK' })]);
  assert.throws(() => bb.requestBelt('ada', 'craft'), /BLACK/);
});

test('only a known consultant requests a belt, in a known discipline', () => {
  assert.throws(() => blackbelt().requestBelt('nobody', 'craft'), DomainError);
  assert.throws(() => blackbelt().requestBelt('margaret', 'craft'), /not a consultant/);
  assert.throws(() => blackbelt().requestBelt('ada', 'cooking'), /no discipline/);
});

test('a mentor is assigned to a requested belt', () => {
  const bb = blackbelt([belt({ status: 'REQUESTED', mentorId: null })]);
  const assigned = bb.assignMentor('B-1', 'grace');
  assert.equal(assigned.status, 'MENTOR_ASSIGNED');
  assert.equal(assigned.mentorId, 'grace');
});

test('a mentor must be a mentor, and not the consultant themself', () => {
  const bb = blackbelt([belt({ status: 'REQUESTED', mentorId: null, consultantId: 'grace' })]);
  assert.throws(() => bb.assignMentor('B-1', 'ada'), /not a mentor/);
  assert.throws(() => bb.assignMentor('B-1', 'grace'), /own belt/);
});

test('the first objective starts the belt', () => {
  const bb = blackbelt([belt({ status: 'MENTOR_ASSIGNED' })]);
  const objective = bb.addObjective('B-1', 'grace', 'Run a refactoring workshop');
  assert.deepEqual(objective, { id: '1', label: 'Run a refactoring workshop', status: 'TODO' });
  assert.equal(bb.getBelt('B-1').status, 'IN_PROGRESS');
  assert.equal(bb.addObjective('B-1', 'grace', 'Pair on a kata').id, '2');
});

test('only the belt mentor adds objectives, and only before submission', () => {
  const bb = blackbelt([belt({ status: 'MENTOR_ASSIGNED' }), belt({ id: 'B-2', status: 'REQUESTED', mentorId: 'grace' })]);
  assert.throws(() => bb.addObjective('B-1', 'margaret', 'Something'), /only the belt's mentor/);
  assert.throws(() => bb.addObjective('B-1', 'grace', '  '), /needs a label/);
  assert.throws(() => bb.addObjective('B-2', 'grace', 'Something'), /cannot add an objective/);
});

test('the mentor validates an objective of a belt in progress', () => {
  const bb = blackbelt([
    belt({ status: 'IN_PROGRESS', objectives: [{ id: '1', label: 'Kata', status: 'TODO' }] }),
  ]);
  assert.equal(bb.validateObjective('B-1', '1', 'grace').status, 'VALIDATED');
  assert.throws(() => bb.validateObjective('B-1', '1', 'grace'), /already validated/);
  assert.throws(() => bb.validateObjective('B-1', '9', 'grace'), /no objective 9/);
});

test('only the belt mentor validates its objectives', () => {
  const bb = blackbelt([
    belt({ status: 'IN_PROGRESS', objectives: [{ id: '1', label: 'Kata', status: 'TODO' }] }),
  ]);
  assert.throws(() => bb.validateObjective('B-1', '1', 'margaret'), /only the belt's mentor/);
});

test('the sensei validates or refuses a belt that awaits validation', () => {
  const bb = blackbelt([belt({ status: 'NEED_VALIDATION' }), belt({ id: 'B-2', status: 'NEED_VALIDATION' })]);
  assert.equal(bb.decideBelt('B-1', 'margaret', 'VALIDATED').status, 'VALIDATED');
  assert.equal(bb.decideBelt('B-2', 'margaret', 'REFUSED').status, 'REFUSED');
});

test('only a sensei decides, and only on a belt that awaits validation', () => {
  const bb = blackbelt([belt({ status: 'NEED_VALIDATION' }), belt({ id: 'B-2', status: 'IN_PROGRESS' })]);
  assert.throws(() => bb.decideBelt('B-1', 'grace', 'VALIDATED'), /not a sensei/);
  assert.throws(() => bb.decideBelt('B-1', 'margaret', 'MAYBE'), /a decision is/);
  assert.throws(() => bb.decideBelt('B-2', 'margaret', 'VALIDATED'), /cannot go from IN_PROGRESS/);
});

test('the domain works on its own copy of the state', () => {
  const state = { disciplines, people, belts: [] };
  const bb = new Blackbelt(state);
  bb.requestBelt('ada', 'craft');
  assert.equal(state.belts.length, 0);
  assert.equal(bb.toJSON().belts.length, 1);
});
