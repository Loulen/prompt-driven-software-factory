#!/usr/bin/env node
// A tiny CLI over the Blackbelt domain. State lives in a local JSON file (see store.js).
import { Blackbelt, DomainError } from './blackbelt.js';
import { loadState, resetState, saveState } from './store.js';

const USAGE = `blackbelt-lite — consultants grow belt by belt in a discipline, coached by a mentor.

USAGE
  node src/cli.js <command> [args]

COMMANDS
  list [consultant]                               List belts (optionally one consultant's)
  show <belt>                                     Show a belt and its objectives
  request <consultant> <discipline>               Request the next belt in a discipline
  assign-mentor <belt> <mentor>                   Assign a mentor to a requested belt
  add-objective <belt> <mentor> <label...>        The mentor adds an objective (starts the belt)
  validate-objective <belt> <objective> <mentor>  The mentor validates an objective
  decide <belt> <sensei> validated|refused        The sensei's final decision on a belt
  people                                          List people and their roles
  disciplines                                     List disciplines
  reset                                           Restore the seed data

State file: $BLACKBELT_STATE, else .blackbelt-state.json at the project root.`;

function formatBelt(belt) {
  const mentor = belt.mentorId ? `mentor ${belt.mentorId}` : 'no mentor';
  return `${belt.id}  ${belt.consultantId}  ${belt.disciplineId}  ${belt.color}  ${belt.status}  (${mentor})`;
}

function formatObjective(objective) {
  const mark = objective.status === 'VALIDATED' ? 'x' : ' ';
  return `  [${mark}] ${objective.id}. ${objective.label}  ${objective.status}`;
}

const COMMANDS = {
  list: (bb, [consultantId]) => {
    const belts = bb.listBelts({ consultantId });
    return belts.length ? belts.map(formatBelt).join('\n') : 'No belt.';
  },
  show: (bb, [beltId]) => {
    const belt = bb.getBelt(beltId);
    const objectives = belt.objectives.length ? belt.objectives.map(formatObjective) : ['  (no objective yet)'];
    return [formatBelt(belt), 'Objectives:', ...objectives].join('\n');
  },
  request: (bb, [consultantId, disciplineId]) => {
    const belt = bb.requestBelt(consultantId, disciplineId);
    return `Requested ${belt.color} belt in ${belt.disciplineId} for ${belt.consultantId}: ${belt.id}`;
  },
  'assign-mentor': (bb, [beltId, mentorId]) => {
    const belt = bb.assignMentor(beltId, mentorId);
    return `${belt.id}: mentor ${belt.mentorId} assigned (${belt.status})`;
  },
  'add-objective': (bb, [beltId, mentorId, ...label]) => {
    const objective = bb.addObjective(beltId, mentorId, label.join(' '));
    return `${beltId}: objective ${objective.id} added — ${objective.label}`;
  },
  'validate-objective': (bb, [beltId, objectiveId, mentorId]) => {
    const objective = bb.validateObjective(beltId, objectiveId, mentorId);
    return `${beltId}: objective ${objective.id} validated — ${objective.label}`;
  },
  decide: (bb, [beltId, senseiId, decision]) => {
    const belt = bb.decideBelt(beltId, senseiId, String(decision ?? '').toUpperCase());
    return `${belt.id}: ${belt.status}`;
  },
  people: (bb) => bb.listPeople().map((p) => `${p.id}  ${p.name}  ${p.roles.join(', ')}`).join('\n'),
  disciplines: (bb) => bb.listDisciplines().map((d) => `${d.id}  ${d.name}`).join('\n'),
};

const READ_ONLY = new Set(['list', 'show', 'people', 'disciplines']);

function run(argv) {
  const [command, ...args] = argv;
  if (!command || command === 'help' || command === '--help' || command === '-h') {
    return { code: command ? 0 : 1, out: USAGE };
  }
  if (command === 'reset') {
    resetState();
    return { code: 0, out: 'State restored from the seed.' };
  }
  const handler = COMMANDS[command];
  if (!handler) return { code: 1, err: `unknown command: ${command}\n\n${USAGE}` };
  const bb = new Blackbelt(loadState());
  try {
    const out = handler(bb, args);
    if (!READ_ONLY.has(command)) saveState(bb.toJSON());
    return { code: 0, out };
  } catch (error) {
    if (error instanceof DomainError) return { code: 2, err: `refused: ${error.message}` };
    throw error;
  }
}

const { code, out, err } = run(process.argv.slice(2));
if (out) console.log(out);
if (err) console.error(err);
process.exitCode = code;
