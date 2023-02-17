import * as globals from './globals';

declare global {
  let global: any;
}

// import * as test from '../pkgs/test/test';

function setGlobals() {
  Object.entries(globals).forEach(([key, value]) => {
    global[key] = value;
  });
}

describe('Name of the group', () => {
  it('should do something', async () => {
    setGlobals();

    const test = await import('../pkgs/test/test');

    expect(2 + 2).toBe(4);
    expect(test).toBeDefined();
  });
});
