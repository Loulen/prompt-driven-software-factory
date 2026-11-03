// The belt workflow:
//   REQUESTED → MENTOR_ASSIGNED → IN_PROGRESS → NEED_VALIDATION → VALIDATED / REFUSED
export const BELT_STATUSES = Object.freeze({
  REQUESTED: 'REQUESTED',
  MENTOR_ASSIGNED: 'MENTOR_ASSIGNED',
  IN_PROGRESS: 'IN_PROGRESS',
  NEED_VALIDATION: 'NEED_VALIDATION',
  VALIDATED: 'VALIDATED',
  REFUSED: 'REFUSED',
});

const TRANSITIONS = Object.freeze({
  REQUESTED: ['MENTOR_ASSIGNED'],
  MENTOR_ASSIGNED: ['IN_PROGRESS'],
  IN_PROGRESS: ['NEED_VALIDATION'],
  NEED_VALIDATION: ['VALIDATED', 'REFUSED'],
  VALIDATED: [],
  REFUSED: [],
});

export function canTransition(from, to) {
  return (TRANSITIONS[from] ?? []).includes(to);
}

// A closed belt is final: the consultant may request a new one in the same discipline.
export function isClosed(status) {
  return status === BELT_STATUSES.VALIDATED || status === BELT_STATUSES.REFUSED;
}
