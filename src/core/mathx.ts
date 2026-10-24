export const TAU = Math.PI * 2;
export const DEG = Math.PI / 180;

export function clamp(v: number, lo: number, hi: number): number {
  return v < lo ? lo : v > hi ? hi : v;
}

export function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

/** Frame-rate independent exponential smoothing. */
export function damp(a: number, b: number, lambda: number, dt: number): number {
  return lerp(a, b, 1 - Math.exp(-lambda * dt));
}

export function smoothstep(e0: number, e1: number, x: number): number {
  const t = clamp((x - e0) / (e1 - e0), 0, 1);
  return t * t * (3 - 2 * t);
}

export function invLerp(a: number, b: number, v: number): number {
  return b === a ? 0 : (v - a) / (b - a);
}

/** Wrap an angle into [-PI, PI]. */
export function wrapAngle(a: number): number {
  while (a > Math.PI) a -= TAU;
  while (a < -Math.PI) a += TAU;
  return a;
}

/** Deterministic PRNG (mulberry32). */
export function mulberry32(seed: number): () => number {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function randRange(rnd: () => number, a: number, b: number): number {
  return a + (b - a) * rnd();
}

export function pick<T>(rnd: () => number, arr: readonly T[]): T {
  return arr[Math.min(arr.length - 1, Math.floor(rnd() * arr.length))];
}

export function randInt(rnd: () => number, a: number, b: number): number {
  return a + Math.floor(rnd() * (b - a + 1));
}

/** Cheap 2D value noise with smooth interpolation, seeded. */
export function makeNoise2D(seed: number): (x: number, y: number) => number {
  const hash = (ix: number, iy: number): number => {
    let h = (ix * 374761393 + iy * 668265263 + seed * 1442695040888963407) | 0;
    h = (h ^ (h >>> 13)) * 1274126177;
    h = h ^ (h >>> 16);
    return (h >>> 0) / 4294967296;
  };
  const fade = (t: number): number => t * t * (3 - 2 * t);
  return (x: number, y: number): number => {
    const x0 = Math.floor(x);
    const y0 = Math.floor(y);
    const sx = fade(x - x0);
    const sy = fade(y - y0);
    const n00 = hash(x0, y0);
    const n10 = hash(x0 + 1, y0);
    const n01 = hash(x0, y0 + 1);
    const n11 = hash(x0 + 1, y0 + 1);
    return lerp(lerp(n00, n10, sx), lerp(n01, n11, sx), sy);
  };
}

/** Fractal brownian motion over value noise. */
export function fbm(noise: (x: number, y: number) => number, x: number, y: number, octaves = 4, gain = 0.5): number {
  let amp = 1;
  let freq = 1;
  let sum = 0;
  let norm = 0;
  for (let i = 0; i < octaves; i++) {
    sum += amp * noise(x * freq, y * freq);
    norm += amp;
    amp *= gain;
    freq *= 2;
  }
  return sum / norm;
}

/** Round to a fixed number of decimals (used for deterministic math in tests). */
export function round(v: number, decimals = 3): number {
  const m = 10 ** decimals;
  return Math.round(v * m) / m;
}
