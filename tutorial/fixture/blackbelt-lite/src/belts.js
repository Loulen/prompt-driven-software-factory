// Belt colours, in progression order: a consultant climbs them one by one, per discipline.
export const BELT_COLORS = Object.freeze(['WHITE', 'ORANGE', 'GREEN', 'BLUE', 'BROWN', 'BLACK']);

export function isBeltColor(color) {
  return BELT_COLORS.includes(color);
}

// The colour that comes after `color`; the first colour when `color` is null (no belt yet);
// null after BLACK (there is nothing left to request).
export function nextBeltColor(color) {
  if (color === null || color === undefined) return BELT_COLORS[0];
  const index = BELT_COLORS.indexOf(color);
  if (index === -1) throw new RangeError(`unknown belt colour: ${color}`);
  return BELT_COLORS[index + 1] ?? null;
}

export function compareBeltColors(a, b) {
  return BELT_COLORS.indexOf(a) - BELT_COLORS.indexOf(b);
}
