import { compareBeltColors, nextBeltColor } from './belts.js';
import { BELT_STATUSES, canTransition, isClosed } from './workflow.js';

export const OBJECTIVE_STATUSES = Object.freeze({
  TODO: 'TODO',
  VALIDATED: 'VALIDATED',
});

export class DomainError extends Error {
  constructor(message) {
    super(message);
    this.name = 'DomainError';
  }
}

// The Blackbelt domain over a plain state object:
//   { disciplines: [{ id, name }], people: [{ id, name, roles: [...] }], belts: [...] }
// Roles: `consultant` (climbs belts), `mentor` (coaches a belt, validates its objectives),
// `sensei` (takes the final decision on a belt).
export class Blackbelt {
  constructor(state) {
    this.state = structuredClone(state);
    this.state.belts ??= [];
  }

  toJSON() {
    return structuredClone(this.state);
  }

  listDisciplines() {
    return this.state.disciplines;
  }

  listPeople() {
    return this.state.people;
  }

  listBelts({ consultantId, disciplineId } = {}) {
    return this.state.belts.filter(
      (belt) =>
        (consultantId === undefined || belt.consultantId === consultantId) &&
        (disciplineId === undefined || belt.disciplineId === disciplineId),
    );
  }

  getBelt(beltId) {
    const belt = this.state.belts.find((candidate) => candidate.id === beltId);
    if (!belt) throw new DomainError(`no belt ${beltId}`);
    return belt;
  }

  // The highest belt colour validated for this consultant in this discipline, or null.
  currentColor(consultantId, disciplineId) {
    const validated = this.listBelts({ consultantId, disciplineId })
      .filter((belt) => belt.status === BELT_STATUSES.VALIDATED)
      .map((belt) => belt.color)
      .sort(compareBeltColors);
    return validated.at(-1) ?? null;
  }

  // A consultant requests the next belt in a discipline: WHITE first, then the colour after the
  // highest validated one. One open belt per discipline at a time.
  requestBelt(consultantId, disciplineId) {
    this.#person(consultantId, 'consultant');
    this.#discipline(disciplineId);
    const open = this.listBelts({ consultantId, disciplineId }).find((belt) => !isClosed(belt.status));
    if (open) {
      throw new DomainError(`${consultantId} already has an open belt in ${disciplineId}: ${open.id} (${open.status})`);
    }
    const color = nextBeltColor(this.currentColor(consultantId, disciplineId));
    if (color === null) throw new DomainError(`${consultantId} already holds the BLACK belt in ${disciplineId}`);
    const belt = {
      id: this.#nextBeltId(),
      consultantId,
      disciplineId,
      color,
      status: BELT_STATUSES.REQUESTED,
      mentorId: null,
      objectives: [],
    };
    this.state.belts.push(belt);
    return belt;
  }

  assignMentor(beltId, mentorId) {
    const belt = this.getBelt(beltId);
    this.#person(mentorId, 'mentor');
    if (mentorId === belt.consultantId) throw new DomainError('a consultant cannot mentor their own belt');
    this.#move(belt, BELT_STATUSES.MENTOR_ASSIGNED);
    belt.mentorId = mentorId;
    return belt;
  }

  // The mentor sets the belt's objectives; the first one starts the belt (→ IN_PROGRESS).
  addObjective(beltId, mentorId, label) {
    const belt = this.getBelt(beltId);
    this.#assignedMentor(belt, mentorId);
    if (!label || !label.trim()) throw new DomainError('an objective needs a label');
    if (belt.status === BELT_STATUSES.MENTOR_ASSIGNED) this.#move(belt, BELT_STATUSES.IN_PROGRESS);
    if (belt.status !== BELT_STATUSES.IN_PROGRESS) {
      throw new DomainError(`cannot add an objective to a belt in ${belt.status}`);
    }
    const objective = { id: String(belt.objectives.length + 1), label: label.trim(), status: OBJECTIVE_STATUSES.TODO };
    belt.objectives.push(objective);
    return objective;
  }

  validateObjective(beltId, objectiveId, mentorId) {
    const belt = this.getBelt(beltId);
    this.#assignedMentor(belt, mentorId);
    if (belt.status !== BELT_STATUSES.IN_PROGRESS) {
      throw new DomainError(`cannot validate an objective of a belt in ${belt.status}`);
    }
    const objective = belt.objectives.find((candidate) => candidate.id === String(objectiveId));
    if (!objective) throw new DomainError(`belt ${beltId} has no objective ${objectiveId}`);
    if (objective.status === OBJECTIVE_STATUSES.VALIDATED) {
      throw new DomainError(`objective ${objectiveId} of belt ${beltId} is already validated`);
    }
    objective.status = OBJECTIVE_STATUSES.VALIDATED;
    return objective;
  }

  // The belt's consultant hands their finished belt over for a sensei's decision.
  // Check order matters: ownership first, so a refusal never reveals another consultant's
  // objectives; status before objectives, since a submitted belt's objectives are frozen and
  // listing them would mislead. "No objective" is unreachable from the CLI today (a belt only
  // goes in progress with its first objective) but stays explicit.
  submitBelt(beltId, consultantId) {
    const belt = this.getBelt(beltId);
    if (belt.consultantId !== consultantId) {
      throw new DomainError(`only the belt's consultant (${belt.consultantId}) can submit it`);
    }
    if (belt.status !== BELT_STATUSES.IN_PROGRESS) {
      throw new DomainError(`belt ${belt.id} is ${belt.status}: only a belt in progress can be submitted`);
    }
    if (belt.objectives.length === 0) throw new DomainError(`belt ${belt.id} has no objective`);
    const remaining = belt.objectives.filter((objective) => objective.status !== OBJECTIVE_STATUSES.VALIDATED);
    if (remaining.length) {
      const list = remaining.map((objective) => `${objective.id}. ${objective.label}`).join('; ');
      throw new DomainError(`belt ${belt.id} has objectives still to validate: ${list}`);
    }
    this.#move(belt, BELT_STATUSES.NEED_VALIDATION);
    return belt;
  }

  // The sensei's final decision on a belt that awaits validation.
  decideBelt(beltId, senseiId, decision) {
    const belt = this.getBelt(beltId);
    this.#person(senseiId, 'sensei');
    if (decision !== BELT_STATUSES.VALIDATED && decision !== BELT_STATUSES.REFUSED) {
      throw new DomainError(`a decision is ${BELT_STATUSES.VALIDATED} or ${BELT_STATUSES.REFUSED}, not ${decision}`);
    }
    this.#move(belt, decision);
    return belt;
  }

  #move(belt, to) {
    if (!canTransition(belt.status, to)) {
      throw new DomainError(`belt ${belt.id} cannot go from ${belt.status} to ${to}`);
    }
    belt.status = to;
  }

  #assignedMentor(belt, mentorId) {
    if (belt.mentorId !== mentorId) {
      throw new DomainError(`only the belt's mentor (${belt.mentorId ?? 'none yet'}) can do that`);
    }
  }

  #person(personId, role) {
    const person = this.state.people.find((candidate) => candidate.id === personId);
    if (!person) throw new DomainError(`no person ${personId}`);
    if (!person.roles.includes(role)) throw new DomainError(`${personId} is not a ${role}`);
    return person;
  }

  #discipline(disciplineId) {
    const discipline = this.state.disciplines.find((candidate) => candidate.id === disciplineId);
    if (!discipline) throw new DomainError(`no discipline ${disciplineId}`);
    return discipline;
  }

  #nextBeltId() {
    const max = Math.max(0, ...this.state.belts.map((belt) => Number(belt.id.replace(/^B-/, '')) || 0));
    return `B-${max + 1}`;
  }
}
