type CompassDirection = 'north' | 'east' | 'south' | 'west';
type RelativeDirection = 'forward' | 'right' | 'back' | 'left';

export const directions: {
  compass: CompassDirection[];
  relative: RelativeDirection[];
} = {
  compass: ['north', 'east', 'south', 'west'],
  relative: ['forward', 'right', 'back', 'left'],
};

export class Relative {
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
}
