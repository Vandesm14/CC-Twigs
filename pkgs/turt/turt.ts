import { pretty_print } from 'cc.pretty';
import { readOrCreate, writeFile } from 'mngr/file';

export type CardinalDirection = 'north' | 'east' | 'south' | 'west';
export type RelativeDirection = 'forward' | 'right' | 'backward' | 'left';
export type CoordinateDirection = '-x' | '+x' | '-z' | '+z';

export type Position = {
  x: number;
  y: number;
  z: number;
  heading: CardinalDirection;
};

export const directions: {
  cardinal: CardinalDirection[];
  relative: RelativeDirection[];
  turns: RelativeDirection[][];
  coords: CoordinateDirection[];
} = {
  cardinal: ['north', 'east', 'south', 'west'],
  relative: ['forward', 'right', 'backward', 'left'],
  turns: [[], ['right'], ['right', 'right'], ['left']],
  coords: ['-z', '+x', '+z', '-x'],
};

export function savePositionFile(position: Position) {
  writeFile('position.json', textutils.serializeJSON(position));
}

export function loadPositionFile(): Position {
  const file = readOrCreate(
    'position.json',
    textutils.serializeJSON({ x: 0, y: 0, z: 0, heading: 'north' })
  );

  return textutils.unserializeJSON(file);
}

export function relativeToCardinal(
  base: CardinalDirection,
  to: RelativeDirection
): CardinalDirection {
  const index = directions.cardinal.indexOf(base);
  const relativeIndex = directions.relative.indexOf(to);

  return directions.cardinal[(index + relativeIndex) % 4] as CardinalDirection;
}

export function cardinalToRelative(
  base: CardinalDirection,
  to: CardinalDirection
): RelativeDirection {
  const index = directions.cardinal.indexOf(base);
  const compassIndex = directions.cardinal.indexOf(to);

  return directions.relative[
    (compassIndex - index + 4) % 4
  ] as RelativeDirection;
}

function repeat<T>(item: T, n: number): T[] {
  const items: T[] = [];
  for (let i = 0; i < n; i++) {
    items.push(item);
  }
  return items;
}

function transformPositionHeading(
  position: Position,
  facing: CardinalDirection,
  n = 1
) {
  const newPosition = { ...position };

  switch (facing) {
    case 'north':
      newPosition.z -= n;
      break;
    case 'east':
      newPosition.x += n;
      break;
    case 'south':
      newPosition.z += n;
      break;
    case 'west':
      newPosition.x -= n;
      break;
  }

  return newPosition;
}

function transformHeading(
  heading: CardinalDirection,
  look: number
): CardinalDirection {
  const index = directions.cardinal.indexOf(heading);
  return directions.cardinal[(index + look + 4) % 4] as CardinalDirection;
}

export class Turtle {
  private x: number;
  private y: number;
  private z: number;
  private heading: CardinalDirection;

  constructor(setup?: Position) {
    const fromFile = loadPositionFile();

    this.x = fromFile.x;
    this.y = fromFile.y;
    this.z = fromFile.z;
    this.heading = fromFile.heading;
  }

  /** Turn to face a {@linkcode CardinalDirection}. */
  face(direction: CardinalDirection) {
    const turns =
      directions.turns[
        directions.relative.indexOf(cardinalToRelative(this.heading, direction))
      ];
    if (!turns) return;

    turns.forEach((turn) =>
      turn === 'left' ? this.turnLeft() : this.turnRight()
    );
  }

  /** Turn to face a {@linkcode RelativeDirection}. */
  turn(direction: RelativeDirection) {
    const turns = directions.turns[directions.relative.indexOf(direction)];
    if (!turns) return;

    turns.forEach((turn) =>
      turn === 'left' ? this.turnLeft() : this.turnRight()
    );
  }

  /** Moves `n` blocks in a {@linkcode RelativeDirection}. */
  move(n: number, direction: RelativeDirection, keepHeading = true) {
    const blocks: Array<() => boolean> = [];

    if (direction === 'forward') {
      blocks.push(...repeat(() => this.forward(), n));
    } else {
      blocks.push(() => {
        this.turn(direction);
        return true;
      });
      blocks.push(...repeat(() => this.forward(), n));
      if (keepHeading)
        blocks.push(() => {
          this.turn(
            directions.relative[
              (directions.relative.indexOf(direction) + 2) % 4
            ]!
          );
          return true;
        });
    }

    for (const block of blocks) {
      const result = block();

      if (result === false) throw new Error('Failed to move');
    }
  }

  moveTo(x: number, y: number, z: number, heading?: CardinalDirection) {
    const xDiff = Math.abs(this.x - x);
    const zDiff = Math.abs(this.z - z);

    if (z > this.z) {
      this.move(zDiff, cardinalToRelative(this.heading, 'south'), false);
    } else if (z < this.z) {
      this.move(zDiff, cardinalToRelative(this.heading, 'north'), false);
    }

    if (x > this.x) {
      this.move(xDiff, cardinalToRelative(this.heading, 'east'), false);
    } else if (x < this.x) {
      this.move(xDiff, cardinalToRelative(this.heading, 'west'), false);
    }

    if (heading && heading !== this.heading) this.face(heading);
  }

  /** Gets the current {@linkcode Position}. */
  position(): Position {
    return {
      x: this.x,
      y: this.y,
      z: this.z,
      heading: this.heading,
    };
  }

  savePosition() {
    pretty_print(this.position());

    savePositionFile({
      x: this.x,
      y: this.y,
      z: this.z,
      heading: this.heading,
    });
  }

  /** Move one block forward. */
  forward() {
    const newPosition = transformPositionHeading(this.position(), this.heading);

    const success = turtle.forward();
    if (success) {
      this.x = newPosition.x;
      this.z = newPosition.z;
    }

    this.savePosition();

    return success;
  }

  /** Move one block backward. */
  back() {
    const newPosition = transformPositionHeading(
      this.position(),
      transformHeading(this.heading, 2)
    );

    const success = turtle.back();
    if (success) {
      this.x = newPosition.x;
      this.z = newPosition.z;
    }

    this.savePosition();

    return success;
  }

  /** Move one block up. */
  up() {
    const success = turtle.up();
    if (success) this.y++;

    this.savePosition();

    return success;
  }

  /** Move one block down. */
  down() {
    const success = turtle.down();
    if (success) this.y--;

    this.savePosition();

    return success;
  }

  /** Turn left. */
  turnLeft() {
    const success = turtle.turnLeft();
    if (success) this.heading = transformHeading(this.heading, -1);

    this.savePosition();

    return success;
  }

  /** Turn right. */
  turnRight() {
    const success = turtle.turnRight();
    if (success) this.heading = transformHeading(this.heading, 1);

    this.savePosition();

    return success;
  }
}
