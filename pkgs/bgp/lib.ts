/** Generates a random SHA hash: "8a19e136" */
export function generateRandomHash() {
  return Math.random().toString(16).substring(2, 10);
}

export function sleepUntil(epoch: number) {
  const now = os.epoch('utc');
  const diff = epoch - now;
  if (diff > 0) sleep(diff / 1000);
}
