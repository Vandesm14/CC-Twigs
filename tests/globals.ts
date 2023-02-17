export function print(...strings: string[]) {
  // @ts-expect-error: we are using a test env
  console.log(...strings);
}
