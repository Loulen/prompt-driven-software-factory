import { test } from 'node:test';
import assert from 'node:assert/strict';
import { BELT_COLORS, compareBeltColors, isBeltColor, nextBeltColor } from '../src/belts.js';

test('belt colours go WHITE → ORANGE → GREEN → BLUE → BROWN → BLACK', () => {
  assert.deepEqual(BELT_COLORS, ['WHITE', 'ORANGE', 'GREEN', 'BLUE', 'BROWN', 'BLACK']);
});

test('the first belt is WHITE', () => {
  assert.equal(nextBeltColor(null), 'WHITE');
});

test('each colour is followed by the next one, and nothing comes after BLACK', () => {
  assert.equal(nextBeltColor('WHITE'), 'ORANGE');
  assert.equal(nextBeltColor('BROWN'), 'BLACK');
  assert.equal(nextBeltColor('BLACK'), null);
});

test('an unknown colour is rejected', () => {
  assert.equal(isBeltColor('PINK'), false);
  assert.throws(() => nextBeltColor('PINK'), RangeError);
});

test('colours compare by progression order', () => {
  assert.ok(compareBeltColors('GREEN', 'ORANGE') > 0);
  assert.ok(compareBeltColors('WHITE', 'BLACK') < 0);
});
