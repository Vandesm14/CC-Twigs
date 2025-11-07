const X = (n: number) => (n <= 1 ? '' : 'r' + 'f'.repeat(n - 1) + 'l');
const Y = (n: number) => 'f'.repeat(n);
const XY = (x: number, y: number) => X(x) + Y(y);

const branches = {
  // L: Left
  // R: Right
  // F: Forward
  // I: Input (take items)
  // O: Output (put items)
  // X: Move until checkpoint (orange)
  // H: Home (stack up and wait)
  //
  input: {
    1: 'fix',
    2: 'ffix',
    _: 'x',
  },
  storage: {
    // b1, s1
    1: 'lx' + XY(1, 1) + 'oxxl',
    2: 'lx' + XY(2, 1) + 'oxxl',
    3: 'lx' + XY(3, 1) + 'oxxl',
    4: 'lx' + XY(1, 2) + 'oxxl',
    5: 'lx' + XY(2, 2) + 'oxxl',
    6: 'lx' + XY(3, 2) + 'oxxl',

    // b1, s2
    7: 'lx' + XY(1, 1) + 'oxl',
    8: 'lx' + XY(2, 1) + 'oxl',
    9: 'lx' + XY(3, 1) + 'oxl',
    10: 'lx' + XY(1, 2) + 'oxl',
    11: 'lx' + XY(2, 2) + 'oxl',
    12: 'lx' + XY(3, 2) + 'oxl',

    // b2, s1
    13: 'x' + XY(1, 1) + 'oxx',
    14: 'x' + XY(2, 1) + 'oxx',
    15: 'x' + XY(3, 1) + 'oxx',
    16: 'x' + XY(1, 2) + 'oxx',
    17: 'x' + XY(2, 2) + 'oxx',
    18: 'x' + XY(3, 2) + 'oxx',

    // b2, s2
    19: 'xx' + XY(1, 1) + 'ox',
    20: 'xx' + XY(2, 1) + 'ox',
    21: 'xx' + XY(3, 1) + 'ox',
    22: 'xx' + XY(1, 2) + 'ox',
    23: 'xx' + XY(2, 2) + 'ox',
    24: 'xx' + XY(3, 2) + 'ox',
  },
  output: {
    1: 'xfoxh',
    2: 'xffoxh',
  },
};
