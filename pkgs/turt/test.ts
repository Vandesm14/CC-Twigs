import { CardinalDirection, Turtle } from './turt';
const args = [...$vararg];

const tryNumberOr = (n: number | string, def: number) => {
  const num = Number(n);
  return isNaN(num) ? def : num;
};

const [x, y, z, heading] = args;
const isValid = args.slice(0, 3).every((arg) => !isNaN(Number(arg)));

const init = {
  x: tryNumberOr(x ?? 0, 0),
  y: tryNumberOr(y ?? 0, 0),
  z: tryNumberOr(z ?? 0, 0),
  heading: heading as CardinalDirection,
};

const turt = new Turtle(isValid ? init : undefined);

turt.moveTo(-534, 101, -89);
turt.moveTo(init.x, init.y, init.z);
