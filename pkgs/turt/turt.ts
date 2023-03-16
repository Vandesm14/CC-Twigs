import { pretty_print } from 'cc.pretty';
import { readOrCreate, writeFile } from 'mngr/file';

export type CompassDirection = 'north' | 'east' | 'south' | 'west';
export type RelativeDirection = 'forward' | 'right' | 'backward' | 'left';
export type CoordinateDirection = '-x' | '+x' | '-z' | '+z';

export type Position = {
  x: number;
  y: number;
  z: number;
  heading: CompassDirection;
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

export function relativeToCompass(
  facing: CompassDirection,
  relative: RelativeDirection
): CompassDirection {
  const index = directions.compass.indexOf(facing);
  const relativeIndex = directions.relative.indexOf(relative);

  return directions.compass[(index + relativeIndex) % 4] as CompassDirection;
}

export function compassToRelative(
  facing: CompassDirection,
  toFace: CompassDirection
): RelativeDirection {
  const index = directions.compass.indexOf(facing);
  const compassIndex = directions.compass.indexOf(toFace);

  return directions.relative[
    (compassIndex - index + 4) % 4
  ] as RelativeDirection;
}

export const directions: {
  compass: CompassDirection[];
  relative: RelativeDirection[];
  turns: RelativeDirection[][];
  coords: CoordinateDirection[];
} = {
  compass: ['north', 'east', 'south', 'west'],
  relative: ['forward', 'right', 'backward', 'left'],
  turns: [[], ['right'], ['right', 'right'], ['left']],
  coords: ['-z', '+x', '+z', '-x'],
};

function repeat<T>(item: T, n: number): T[] {
  const items: T[] = [];
  for (let i = 0; i < n; i++) {
    items.push(item);
  }
  return items;
}

function transformPositionFacing(
  position: Position,
  facing: CompassDirection,
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

function transformHeading(heading: CompassDirection, look: number) {
  const index = directions.compass.indexOf(heading);
  return directions.compass[(index + look + 4) % 4] as CompassDirection;
}

export class Turtle {
  private x: number;
  private y: number;
  private z: number;
  private heading: CompassDirection;

  constructor(setup?: {
    x: number;
    y: number;
    z: number;
    heading: CompassDirection;
  }) {
    const fromFile = loadPositionFile();

    this.x = fromFile.x;
    this.y = fromFile.y;
    this.z = fromFile.z;
    this.heading = fromFile.heading;
  }

  /** Face a cardinal direction (e.g. `north`, `south`, etc) */
  face(direction: CompassDirection) {
    const turns =
      directions.turns[
        directions.relative.indexOf(compassToRelative(this.heading, direction))
      ];
    if (!turns) return;

    turns.forEach((turn) =>
      turn === 'left' ? this.turnLeft() : this.turnRight()
    );
  }

  /** Turn to a relative direction (e.g. `right`, `backward`) */
  turn(direction: RelativeDirection) {
    const turns = directions.turns[directions.relative.indexOf(direction)];
    if (!turns) return;

    turns.forEach((turn) =>
      turn === 'left' ? this.turnLeft() : this.turnRight()
    );
  }

  /** Moves `n` steps in a relative direction */
  move(n: number, direction: RelativeDirection, keepFace = true) {
    const steps: Array<() => boolean> = [];
    if (direction === 'forward') {
      steps.push(...repeat(() => this.forward(), n));
    } else {
      steps.push(() => {
        this.turn(direction);
        return true;
      });
      steps.push(...repeat(() => this.forward(), n));
      if (keepFace)
        steps.push(() => {
          this.turn(
            directions.relative[
              (directions.relative.indexOf(direction) + 2) % 4
            ]!
          );
          return true;
        });
    }

    for (const step of steps) {
      const result = step();

      if (result === false) throw new Error('Failed to move');
    }
  }

  moveTo(x: number, y: number, z: number, heading?: CompassDirection) {
    const xDiff = Math.abs(this.x - x);
    const zDiff = Math.abs(this.z - z);

    if (z > this.z) {
      this.move(zDiff, compassToRelative(this.heading, 'south'), false);
    } else if (z < this.z) {
      this.move(zDiff, compassToRelative(this.heading, 'north'), false);
    }

    if (x > this.x) {
      this.move(xDiff, compassToRelative(this.heading, 'east'), false);
    } else if (x < this.x) {
      this.move(xDiff, compassToRelative(this.heading, 'west'), false);
    }

    if (heading && heading !== this.heading) this.face(heading);
  }

  /** Gets the current absolute position */
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

  forward() {
    const newPosition = transformPositionFacing(this.position(), this.heading);

    const success = turtle.forward();
    if (success) {
      this.x = newPosition.x;
      this.z = newPosition.z;
    }

    this.savePosition();

    return success;
  }

  back() {
    const newPosition = transformPositionFacing(
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

  up() {
    const success = turtle.up();
    if (success) this.y++;

    this.savePosition();

    return success;
  }

  down() {
    const success = turtle.down();
    if (success) this.y--;

    this.savePosition();

    return success;
  }

  turnLeft() {
    const success = turtle.turnLeft();
    if (success) this.heading = transformHeading(this.heading, -1);

    this.savePosition();

    return success;
  }

  turnRight() {
    const success = turtle.turnRight();
    if (success) this.heading = transformHeading(this.heading, 1);

    this.savePosition();

    return success;
  }
}
