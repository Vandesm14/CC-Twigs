export function sleepUntil(epoch: number) {
  const now = os.epoch('utc');
  const diff = epoch - now;
  if (diff > 0) sleep(diff / 1000);
}

export function luaArray(luaArr: Record<number, any>) {
  return Object.values(luaArr ?? {});
}

export function chunkArray<T>(arr: T[], chunkSize: number): T[][] {
  const chunks = [];
  for (let i = 0; i < arr.length; i += chunkSize) {
    chunks.push(arr.slice(i, i + chunkSize));
  }
  return chunks;
}
