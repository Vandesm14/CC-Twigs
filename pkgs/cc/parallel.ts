/**
 * Synchronously waits for any function to call {@linkcode coroutine.yield}
 * before continuing execution on the current thread.
 */
export function waitForAny(this: void, ...fns: (() => unknown)[]): void {
  parallel.waitForAny(...fns);
}

/**
 * Synchronously waits for all functions to call {@linkcode coroutine.yield}
 * before continuing execution on the current thread.
 */
export function waitForAll(this: void, ...fns: (() => unknown)[]): void {
  parallel.waitForAll(...fns);
}

declare module parallel {
  function waitForAny(this: void, ...fns: (() => unknown)[]): void;
  function waitForAll(this: void, ...fns: (() => unknown)[]): void;
}
