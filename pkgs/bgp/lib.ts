/** Generates a random SHA hash: "8a19e136" */
export function generateRandomHash() {
  return Math.random().toString(16).substring(2, 10);
}
