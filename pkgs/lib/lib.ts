export const pluralize = (
  n: number,
  singular: string,
  plural?: string
): string =>
  n === 1 ? `${n} ${singular}` : `${n} ${plural || singular + 's'}`;

export function getModems(): string[] {
  const modems = peripheral
    .getNames()
    .filter((name) => peripheral.getType(name)[0] === 'modem');
  // if (modems.length === 0) {
  //   print('No modems found.');
  // } else {
  //   print(`${pluralize(modems.length, 'modem')} found.`);
  // }

  return modems;
}

export const dedupe = <T>(el: T, i: number, arr: T[]): boolean =>
  arr.indexOf(el) === i;
