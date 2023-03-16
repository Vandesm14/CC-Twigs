export type CompassDirection = 'north' | 'east' | 'south' | 'west';
export type RelativeDirection = 'forward' | 'right' | 'backward' | 'left';
export type CoordinateDirection = '-x' | '+x' | '-z' | '+z';

export type Position = {
  x: number;
  y: number;
  z: number;
  heading: CompassDirection;
};

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

export class Turtle {
  private x: number;
  private y: number;
  private z: number;
  private heading: CompassDirection;

  constructor(setup: {
    x: number;
    y: number;
    z: number;
    heading: CompassDirection;
  }) {
    this.x = setup.x;
    this.y = setup.y;
    this.z = setup.z;
    this.heading = setup.heading;
  }

  relativeToCompass(move: RelativeDirection): CompassDirection {
    const facing = this.heading;
    const index = directions.compass.indexOf(facing);
    const relativeIndex = directions.relative.indexOf(move);

    return directions.compass[(index + relativeIndex) % 4] as CompassDirection;
  }

  compassToRelative(move: CompassDirection): RelativeDirection {
    const facing = this.heading;
    const index = directions.compass.indexOf(facing);
    const compassIndex = directions.compass.indexOf(move);

    return directions.relative[
      (compassIndex - index + 4) % 4
    ] as RelativeDirection;
  }

  /** Face a cardinal direction (e.g. `north`, `south`, etc) */
  face(direction: CompassDirection) {
    const turns =
      directions.turns[
        directions.relative.indexOf(this.compassToRelative(direction))
      ];
    if (!turns) return;

    turns.forEach((turn) =>
      turn === 'left' ? turtle.turnLeft() : turtle.turnRight()
    );

    this.heading = direction;
  }

  /** Turn to a relative direction (e.g. `right`, `backward`) */
  turn(direction: RelativeDirection) {
    const turns = directions.turns[directions.relative.indexOf(direction)];
    if (!turns) return;

    turns.forEach((turn) =>
      turn === 'left' ? turtle.turnLeft() : turtle.turnRight()
    );
    this.heading = this.relativeToCompass(direction);
  }

  /** Moves `n` steps in a relative direction */
  move(n: number, direction: RelativeDirection, keepFace = true) {
    const facing = this.relativeToCompass(direction);
    const steps: Array<() => boolean> = [];
    if (direction === 'forward') {
      steps.push(...repeat(() => turtle.forward(), n));
      // } else if (direction === 'backward') {
      //   steps.push(...repeat(() => turtle.back(), n));
    } else {
      steps.push(() => {
        this.turn(direction);
        return true;
      });
      steps.push(...repeat(() => turtle.forward(), n));
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

    switch (facing) {
      case 'north':
        this.z -= n;
        break;
      case 'east':
        this.x += n;
        break;
      case 'south':
        this.z += n;
        break;
      case 'west':
        this.x -= n;
        break;
    }
  }

  moveTo(x: number, y: number, z: number, heading?: CompassDirection) {
    const xDiff = this.x - x;
    const zDiff = this.z - z;

    print(`${x} - ${this.x} = ${xDiff}`);
    print(`${z} - ${this.z} = ${zDiff}`);

    if (z > this.z) {
      print(`Moving ${Math.abs(zDiff)} steps south`);
      this.move(Math.abs(zDiff), this.compassToRelative('south'), false);
    } else if (z < this.z) {
      print(`Moving ${Math.abs(zDiff)} steps north`);
      this.move(Math.abs(zDiff), this.compassToRelative('north'), false);
    }

    if (x > this.x) {
      print(`Moving ${Math.abs(xDiff)} steps east`);
      this.move(Math.abs(xDiff), this.compassToRelative('east'), false);
    } else if (x < this.x) {
      print(`Moving ${Math.abs(xDiff)} steps west`);
      this.move(Math.abs(xDiff), this.compassToRelative('west'), false);
    }

    if (heading && heading !== this.heading) {
      this.face(heading);

      print(`Turned to face ${heading}`);
    }
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
}
