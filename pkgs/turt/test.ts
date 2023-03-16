import { Turtle } from './turt';

const turt = new Turtle({ x: 0, y: 0, z: 0, heading: 'north' });

turt.move(1, 'forward');

print(turt.position());

turt.move(2, 'backward');

print(turt.position());

turt.move(1, 'left');

print(turt.position());

turt.move(2, 'right');

print(turt.position());
