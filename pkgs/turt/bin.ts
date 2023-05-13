import { pretty_print } from 'cc.pretty';
import { CardinalDirection, Turtle } from './turt';
const args = [...$vararg];

const tryNumberOr = (n: number | string, def: number) => {
  const num = Number(n);
  return isNaN(num) ? def : num;
};

const [cmd, x, y, z, heading] = args;
const isValid = args.slice(1, 4).every((arg) => !isNaN(Number(arg)));

const init = {
  x: tryNumberOr(x ?? 0, 0),
  y: tryNumberOr(y ?? 0, 0),
  z: tryNumberOr(z ?? 0, 0),
  heading: heading as CardinalDirection,
};

const turt = new Turtle(isValid && cmd === 'set' ? init : undefined);

if (cmd === 'set') {
  if (!isValid) {
    throw new Error('Invalid coordinates');
  }

  print('Set coordinates to:');
  pretty_print(init);
} else if (cmd === 'moveto') {
  if (!isValid) {
    throw new Error('Invalid coordinates');
  }

  print('Moving to:');
  pretty_print(init);

  turt.moveTo(init.x, init.y, init.z, init.heading ?? undefined);
} else if (cmd === 'forward') {
  if (isNaN(Number(x))) {
    throw new Error('Invalid distance');
  }

  turt.move(Number(x), 'forward');
}
