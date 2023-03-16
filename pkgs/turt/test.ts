import { Turtle } from './turt';

const turt = new Turtle({ x: 0, y: 0, z: 0, heading: 'north' });

turt.move(1, 'forward');
turt.move(2, 'backward');
turt.move(1, 'left');
turt.move(2, 'right');

turt.moveTo(0, 0, 0, 'north'); // Origin
turt.moveTo(-2, 0, 2); // Computers
turt.moveTo(0, 0, 0, 'north'); // Origin
turt.moveTo(-8, 0, -11); // House
turt.moveTo(0, 0, 0, 'north'); // Origin
