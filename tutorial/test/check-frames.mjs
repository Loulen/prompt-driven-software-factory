// PDSF Tutorial — checks the screens a run rendered (PDSF_TUTO_FRAMES): each one is exactly the
// terminal's size, no line is wider than the terminal, the coach band is the last 4 rows (a rule
// with the progress, at most 2 lines of text, a call to action). Prints the first problem.
//
//   node tutorial/test/check-frames.mjs FRAMES COLS ROWS
import fs from 'node:fs';
import { strWidth } from '../app/ui.mjs';

const [file, cols, rows] = [process.argv[2], Number(process.argv[3]), Number(process.argv[4])];
const frames = fs.readFileSync(file, 'utf8').split('\n\f\n').filter(Boolean);
const fail = (msg) => { console.log(msg); process.exit(1); };
if (frames.length < 20) fail(`only ${frames.length} frames`);
for (const [i, f] of frames.entries()) {
  const lines = f.split('\n');
  const bad = (m) => fail(`frame ${i}: ${m}\n${f}`);
  if (lines.length !== rows) bad(`${lines.length} rows, not ${rows}`);
  for (const l of lines) if (strWidth(l) > cols) bad(`line wider than ${cols}: ${l}`);
  const r = lines.findIndex((l) => l.includes('──── coach ────'));
  if (r !== rows - 4) bad('the coach band is not the last 4 rows (rule, 2 lines max, call to action)');
  if (!/[●◉○]|~10 min/.test(lines[r])) bad('no progress indicator');
  if (!lines[rows - 1].trim()) bad('no call to action');
}
