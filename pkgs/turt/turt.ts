export type CompassDirection = 'north' | 'east' | 'south' | 'west';
export type RelativeDirection = 'forward' | 'right' | 'back' | 'left';

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
} = {
  compass: ['north', 'east', 'south', 'west'],
  relative: ['forward', 'right', 'back', 'left'],
  turns: [[], ['right'], ['right', 'right'], ['left']],
};

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

  /** Turn to a relative direction (e.g. `right`, `back`) */
  turn(direction: RelativeDirection) {
    const turns = directions.turns[directions.relative.indexOf(direction)];
    if (!turns) return;

    turns.forEach((turn) =>
      turn === 'left' ? turtle.turnLeft() : turtle.turnRight()
    );
    this.heading = this.relativeToCompass(direction);
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
