export function realMsToGameMs(ms: number) {
  return ms * 72;
}

export function gameMsToRealMs(ms: number) {
  return ms / 72;
}

export function epoch(locale?: string): number {
  return locale ? os.epoch(locale) : os.epoch() * (1 / 72);
}
