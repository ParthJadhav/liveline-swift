// Deterministic pseudo-random walk shared by every device so all charts show
// the same live stream in sync.
export const streamValue = (t: number): number => {
  return (
    100 +
    5.2 * Math.sin(t * 0.055 + 1.2) +
    2.8 * Math.sin(t * 0.13 + 4.0) +
    1.6 * Math.sin(t * 0.31 + 2.2) +
    0.35 * Math.sin(t * 0.71 + 0.5) +
    0.16 * Math.sin(t * 1.63 + 1.0) +
    t * 0.004
  );
};

export const formatPrice = (value: number): string => {
  return `$${value.toFixed(2)}`;
};

export const clockLabel = (t: number): string => {
  const total = Math.max(0, Math.floor(82160 + t * 0.35));
  const h = Math.floor(total / 3600) % 24;
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(h)}:${pad(m)}:${pad(s)}`;
};
