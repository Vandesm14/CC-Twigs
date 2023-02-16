/**
 * Waits for any supplied function to call {@linkcode coroutine.yield}.
 *
 * @param fns The functions to wait for.
 */
export function waitForAny(this: void, ...fns: (() => unknown)[]): void {
  parallel.waitForAny(...fns);
}

/**
 * Waits for all supplied functions to call {@linkcode coroutine.yield}.
 *
 * @param fns The functions to wait for.
 */
export function waitForAll(this: void, ...fns: (() => unknown)[]): void {
  parallel.waitForAll(...fns);
}

export default { waitForAny, waitForAll };

declare module parallel {
  function waitForAny(this: void, ...fns: (() => unknown)[]): void;
  function waitForAll(this: void, ...fns: (() => unknown)[]): void;
}
