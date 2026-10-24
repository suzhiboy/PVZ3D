/**
 * Every texture in the game is painted at runtime on a 2D canvas: no image
 * assets are shipped. The goal is the hand-painted garden look of the original
 * game — soft blotches, wobbly edges, paper grain — rather than photorealism.
 */
import * as THREE from 'three';
import { clamp, fbm, makeNoise2D, mulberry32, lerp } from './mathx.ts';

export interface Paint {
  c: CanvasRenderingContext2D;
  w: number;
  h: number;
  rnd: () => number;
  noise: (x: number, y: number) => number;
}

const registry: THREE.Texture[] = [];

function paint(w: number, h: number, draw: (p: Paint) => void, seed = 1337): HTMLCanvasElement {
  const cv = document.createElement('canvas');
  cv.width = w;
  cv.height = h;
  const c = cv.getContext('2d');
  if (!c) throw new Error('2d canvas unavailable');
  c.imageSmoothingEnabled = true;
  draw({ c, w, h, rnd: mulberry32(seed), noise: makeNoise2D(seed) });
  return cv;
}

function tex(cv: HTMLCanvasElement, repeatX = 1, repeatY = 1, srgb = true): THREE.CanvasTexture {
  const t = new THREE.CanvasTexture(cv);
  t.wrapS = THREE.RepeatWrapping;
  t.wrapT = THREE.RepeatWrapping;
  t.repeat.set(repeatX, repeatY);
  t.colorSpace = srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace;
  t.needsUpdate = true;
  registry.push(t);
  return t;
}

export function applyAnisotropy(max: number): void {
  for (const t of registry) {
    t.anisotropy = max;
    t.needsUpdate = true;
  }
}

/** Soft round contact shadow. Every plant and zombie sits on one of these; it is
 *  what stops the characters from looking like they float over the lawn. */
export function blobTexture(): THREE.CanvasTexture {
  const cv = paint(96, 96, (p) => {
    const g = p.c.createRadialGradient(p.w / 2, p.h / 2, 0, p.w / 2, p.h / 2, p.w / 2);
    g.addColorStop(0, 'rgba(10, 26, 8, 0.72)');
    g.addColorStop(0.55, 'rgba(10, 26, 8, 0.42)');
    g.addColorStop(1, 'rgba(10, 26, 8, 0)');
    p.c.fillStyle = g;
    p.c.fillRect(0, 0, p.w, p.h);
  }, 991);
  const t = new THREE.CanvasTexture(cv);
  t.colorSpace = THREE.SRGBColorSpace;
  t.needsUpdate = true;
  registry.push(t);
  return t;
}

// ---------------------------------------------------------------------------
// reusable painting helpers
// ---------------------------------------------------------------------------

function grain(c: CanvasRenderingContext2D, w: number, h: number, amount: number, rnd: () => number): void {
  const img = c.getImageData(0, 0, w, h);
  const d = img.data;
  for (let i = 0; i < d.length; i += 4) {
    const n = (rnd() - 0.5) * amount;
    d[i] = clamp(d[i] + n, 0, 255);
    d[i + 1] = clamp(d[i + 1] + n, 0, 255);
    d[i + 2] = clamp(d[i + 2] + n, 0, 255);
  }
  c.putImageData(img, 0, 0);
}

function blotches(
  p: Paint,
  count: number,
  colors: string[],
  minR: number,
  maxR: number,
  alpha: number,
): void {
  const { c, w, h, rnd } = p;
  for (let i = 0; i < count; i++) {
    const x = rnd() * w;
    const y = rnd() * h;
    const r = lerp(minR, maxR, rnd());
    const color = colors[Math.floor(rnd() * colors.length)];
    const g = c.createRadialGradient(x, y, 0, x, y, r);
    const a = alpha * lerp(0.5, 1, rnd());
    g.addColorStop(0, hexAlpha(color, a));
    g.addColorStop(1, hexAlpha(color, 0));
    c.fillStyle = g;
    c.beginPath();
    c.ellipse(x, y, r, r * lerp(0.6, 1.2, rnd()), rnd() * Math.PI, 0, Math.PI * 2);
    c.fill();
  }
}

function hexAlpha(hex: string, a: number): string {
  const n = parseInt(hex.replace('#', ''), 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a.toFixed(3)})`;
}

function speckles(p: Paint, count: number, colors: string[], minR: number, maxR: number, alpha: number): void {
  const { c, w, h, rnd } = p;
  for (let i = 0; i < count; i++) {
    c.fillStyle = hexAlpha(colors[Math.floor(rnd() * colors.length)], alpha * lerp(0.4, 1, rnd()));
    c.beginPath();
    c.arc(rnd() * w, rnd() * h, lerp(minR, maxR, rnd()), 0, Math.PI * 2);
    c.fill();
  }
}

/** Hand-drawn stroke: line with a little jitter along its length. */
function wobblyLine(
  p: Paint,
  x0: number,
  y0: number,
  x1: number,
  y1: number,
  width: number,
  color: string,
  alpha: number,
  jitter = 1.5,
): void {
  const { c, rnd } = p;
  const steps = Math.max(3, Math.floor(Math.hypot(x1 - x0, y1 - y0) / 12));
  c.strokeStyle = hexAlpha(color, alpha);
  c.lineWidth = width;
  c.lineCap = 'round';
  c.beginPath();
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    const x = lerp(x0, x1, t) + (rnd() - 0.5) * jitter;
    const y = lerp(y0, y1, t) + (rnd() - 0.5) * jitter;
    if (i === 0) c.moveTo(x, y);
    else c.lineTo(x, y);
  }
  c.stroke();
}

/** Feathered darker border, so tiled surfaces read as soft painted squares. */
function softEdge(p: Paint, strength: number, inset = 0): void {
  const { c, w, h } = p;
  const g = c.createLinearGradient(0, 0, 0, h);
  g.addColorStop(0, `rgba(0,0,0,${strength})`);
  g.addColorStop(0.12, 'rgba(0,0,0,0)');
  g.addColorStop(0.88, 'rgba(0,0,0,0)');
  g.addColorStop(1, `rgba(0,0,0,${strength})`);
  c.fillStyle = g;
  c.fillRect(inset, 0, w - inset * 2, h);
  const g2 = c.createLinearGradient(0, 0, w, 0);
  g2.addColorStop(0, `rgba(0,0,0,${strength})`);
  g2.addColorStop(0.12, 'rgba(0,0,0,0)');
  g2.addColorStop(0.88, 'rgba(0,0,0,0)');
  g2.addColorStop(1, `rgba(0,0,0,${strength})`);
  c.fillStyle = g2;
  c.fillRect(0, inset, w, h - inset * 2);
}

const GRASS_DARK = ['#3f8a2a', '#4b9a32', '#357a24', '#57a63a'];
const GRASS_LIGHT = ['#8ed35a', '#a3e06b', '#7ec74a', '#b8ea7d'];

// ---------------------------------------------------------------------------
// ground textures
// ---------------------------------------------------------------------------

/** One lawn tile. Two tints of this are alternated by the instanced lawn mesh. */
export function grassTileTexture(): THREE.CanvasTexture {
  const cv = paint(
    512,
    512,
    (p) => {
      const { c, w, h, rnd } = p;
      // base: soft mottling so a single tile never reads as flat fill
      c.fillStyle = '#5fb03f';
      c.fillRect(0, 0, w, h);
      for (let i = 0; i < 26; i++) {
        const x = rnd() * w;
        const y = rnd() * h;
        const r = 40 + rnd() * 90;
        const g = c.createRadialGradient(x, y, 0, x, y, r);
        const warm = rnd() > 0.5;
        g.addColorStop(0, hexAlpha(warm ? '#7cc95a' : '#4a9130', 0.3));
        g.addColorStop(1, hexAlpha(warm ? '#7cc95a' : '#4a9130', 0));
        c.fillStyle = g;
        c.fillRect(x - r, y - r, r * 2, r * 2);
      }
      blotches(p, 26, GRASS_DARK, 40, 130, 0.34);
      blotches(p, 22, GRASS_LIGHT, 34, 110, 0.3);

      // mown streaks: the lawn was cut this morning
      c.save();
      c.globalAlpha = 0.035;
      for (let i = 0; i < 9; i++) {
        c.fillStyle = i % 2 === 0 ? '#ffffff' : '#204d16';
        c.fillRect(0, (i / 9) * h, w, h / 18);
      }
      c.restore();

      // blades, thicker and denser than before so close-ups hold up
      c.lineCap = 'round';
      for (let i = 0; i < 1500; i++) {
        const x = rnd() * w;
        const y = rnd() * h;
        const len = lerp(8, 26, rnd());
        const lean = lerp(-7, 7, rnd());
        const light = rnd() > 0.52;
        c.strokeStyle = hexAlpha(light ? '#b4ec7e' : '#2f7420', lerp(0.22, 0.72, rnd()));
        c.lineWidth = lerp(1, 3.1, rnd());
        c.beginPath();
        c.moveTo(x, y);
        c.quadraticCurveTo(x + lean * 0.5, y - len * 0.6, x + lean, y - len);
        c.stroke();
      }

      // clover and the odd dandelion: two or three per tile, never a carpet
      for (let i = 0; i < 7; i++) {
        const x = rnd() * w;
        const y = rnd() * h;
        const clover = rnd() > 0.3;
        c.fillStyle = clover ? hexAlpha('#2b6f1c', 0.55) : hexAlpha('#ffef9e', 0.9);
        for (let k = 0; k < (clover ? 3 : 5); k++) {
          const a = (k / (clover ? 3 : 5)) * Math.PI * 2 + rnd();
          c.beginPath();
          c.arc(x + Math.cos(a) * 4, y + Math.sin(a) * 4, clover ? 3.4 : 2.1, 0, Math.PI * 2);
          c.fill();
        }
      }
      grain(c, w, h, 18, rnd);
      // a mown square edge: the lawn grid is part of the puzzle, so each tile
      // gets a slightly darker rim instead of blending into its neighbour
      c.strokeStyle = 'rgba(28, 74, 22, 0.28)';
      c.lineWidth = 6;
      c.strokeRect(3, 3, w - 6, h - 6);
      c.strokeStyle = 'rgba(196, 240, 150, 0.12)';
      c.lineWidth = 2;
      c.strokeRect(9, 9, w - 18, h - 18);
      softEdge(p, 0.1);
    },
    21,
  );
  return tex(cv);
}

/** Free-range grass outside the lawn grid (side yard, backyard surrounds). */
export function wildGrassTexture(): THREE.CanvasTexture {
  const cv = paint(
    512,
    512,
    (p) => {
      const { c, w, h, rnd } = p;
      c.fillStyle = '#5aa83d';
      c.fillRect(0, 0, w, h);
      blotches(p, 40, GRASS_DARK, 40, 150, 0.3);
      blotches(p, 36, GRASS_LIGHT, 40, 130, 0.26);
      for (let i = 0; i < 900; i++) {
        const x = rnd() * w;
        const y = rnd() * h;
        const len = lerp(6, 22, rnd());
        c.strokeStyle = hexAlpha(rnd() > 0.5 ? '#a5e074' : '#3a8425', lerp(0.2, 0.6, rnd()));
        c.lineWidth = lerp(1, 2.6, rnd());
        c.beginPath();
        c.moveTo(x, y);
        c.quadraticCurveTo(x + lerp(-6, 6, rnd()), y - len * 0.6, x + lerp(-9, 9, rnd()), y - len);
        c.stroke();
      }
      grain(c, w, h, 14, rnd);
    },
    33,
  );
  return tex(cv, 14, 14);
}

export function soilTexture(): THREE.CanvasTexture {
  const cv = paint(
    512,
    512,
    (p) => {
      const { c, w, h, rnd } = p;
      c.fillStyle = '#6b4a2f';
      c.fillRect(0, 0, w, h);
      blotches(p, 40, ['#4d3320', '#7d5a38', '#8f6b45'], 30, 120, 0.4);
      speckles(p, 900, ['#3d2a1a', '#a17a52', '#5a3f28'], 1, 4, 0.5);
      for (let i = 0; i < 40; i++) {
        c.strokeStyle = hexAlpha('#3f2a18', lerp(0.15, 0.4, rnd()));
        c.lineWidth = lerp(1, 3, rnd());
        c.beginPath();
        const y = rnd() * h;
        c.moveTo(0, y);
        c.bezierCurveTo(w * 0.3, y + lerp(-20, 20, rnd()), w * 0.7, y + lerp(-20, 20, rnd()), w, y + lerp(-10, 10, rnd()));
        c.stroke();
      }
      grain(c, w, h, 18, rnd);
    },
    41,
  );
  return tex(cv, 3, 3);
}

export function concreteTexture(): THREE.CanvasTexture {
  const cv = paint(
    512,
    512,
    (p) => {
      const { c, w, h, rnd } = p;
      c.fillStyle = '#cfcabb';
      c.fillRect(0, 0, w, h);
      blotches(p, 26, ['#b6b1a2', '#e2ddcf', '#a8a294'], 40, 150, 0.3);
      speckles(p, 1400, ['#9d988a', '#eae5d7', '#8b857a'], 0.6, 2, 0.4);
      for (let i = 0; i < 7; i++) {
        wobblyLine(p, rnd() * w, rnd() * h, rnd() * w, rnd() * h, lerp(0.8, 1.8, rnd()), '#8a8478', 0.28, 6);
      }
      grain(c, w, h, 12, rnd);
    },
    51,
  );
  return tex(cv, 4, 4);
}

export function asphaltTexture(): THREE.CanvasTexture {
  const cv = paint(
    512,
    512,
    (p) => {
      const { c, w, h, rnd } = p;
      c.fillStyle = '#5a5c60';
      c.fillRect(0, 0, w, h);
      blotches(p, 30, ['#4a4c50', '#6a6d72', '#45474a'], 40, 160, 0.35);
      speckles(p, 2600, ['#7b7e83', '#3e4043', '#8d9095'], 0.6, 2.2, 0.55);
      grain(c, w, h, 20, rnd);
    },
    61,
  );
  return tex(cv, 6, 6);
}

export function roadStripeTexture(): THREE.CanvasTexture {
  const cv = paint(
    64,
    256,
    (p) => {
      const { c, w, h, rnd } = p;
      c.clearRect(0, 0, w, h);
      c.fillStyle = '#e8e4d6';
      c.fillRect(w * 0.34, h * 0.28, w * 0.32, h * 0.44);
      speckles(p, 60, ['#c9c4b4'], 0.5, 1.6, 0.4);
      grain(c, w, h, 18, rnd);
    },
    71,
  );
  return tex(cv, 1, 1);
}

// ---------------------------------------------------------------------------
// building textures
// ---------------------------------------------------------------------------

export function sidingTexture(): THREE.CanvasTexture {
  const cv = paint(
    512,
    512,
    (p) => {
      const { c, w, h, rnd } = p;
      c.fillStyle = '#f1ece0';
      c.fillRect(0, 0, w, h);
      const rows = 12;
      const rh = h / rows;
      for (let i = 0; i < rows; i++) {
        const y = i * rh;
        const g = c.createLinearGradient(0, y, 0, y + rh);
        g.addColorStop(0, 'rgba(255,255,255,0.62)');
        g.addColorStop(0.62, 'rgba(238,230,212,0.22)');
        g.addColorStop(1, 'rgba(104,95,80,0.52)');
        c.fillStyle = g;
        c.fillRect(0, y, w, rh);
        // each lap gets its own faint tint so a big wall never reads as one colour
        c.fillStyle = `rgba(126,105,74,${(0.015 + rnd() * 0.035).toFixed(3)})`;
        c.fillRect(0, y, w, rh);
        wobblyLine(p, 0, y + rh - 0.5, w, y + rh - 0.5, 1.1, '#7d7466', 0.42, 1.2);
      }
      blotches(p, 12, ['#ded7c6', '#fffdf6'], 40, 140, 0.22);
      grain(c, w, h, 9, rnd);
    },
    81,
  );
  return tex(cv, 2, 1);
}

export function brickTexture(): THREE.CanvasTexture {
  const cv = paint(
    512,
    512,
    (p) => {
      const { c, w, h, rnd } = p;
      c.fillStyle = '#c8bcae';
      c.fillRect(0, 0, w, h);
      const rows = 10;
      const cols = 5;
      const bh = h / rows;
      const bw = w / cols;
      for (let r = 0; r < rows; r++) {
        const offset = r % 2 === 0 ? 0 : bw / 2;
        for (let k = -1; k <= cols; k++) {
          const x = k * bw + offset;
          const y = r * bh;
          const tone = lerp(0, 1, rnd());
          const col = `rgb(${Math.round(lerp(158, 186, tone))},${Math.round(lerp(84, 104, tone))},${Math.round(lerp(66, 80, tone))})`;
          c.fillStyle = col;
          c.fillRect(x + 2, y + 2, bw - 4, bh - 4);
          c.fillStyle = hexAlpha('#ffffff', 0.06);
          c.fillRect(x + 2, y + 2, bw - 4, 2);
        }
      }
      blotches(p, 18, ['#7d4a3a', '#d9a894'], 20, 70, 0.2);
      grain(c, w, h, 14, rnd);
    },
    91,
  );
  return tex(cv, 3, 2);
}

export function shingleTexture(): THREE.CanvasTexture {
  const cv = paint(
    512,
    512,
    (p) => {
      const { c, w, h, rnd } = p;
      c.fillStyle = '#5c6a72';
      c.fillRect(0, 0, w, h);
      const rows = 8;
      const rh = h / rows;
      for (let r = 0; r < rows; r++) {
        const y = r * rh;
        const offset = r % 2 === 0 ? 0 : rh * 0.6;
        for (let x = -rh; x < w + rh; x += rh * 1.2) {
          const tone = lerp(0, 1, rnd());
          c.fillStyle = `rgb(${Math.round(lerp(72, 104, tone))},${Math.round(lerp(84, 118, tone))},${Math.round(lerp(92, 126, tone))})`;
          c.fillRect(x + offset, y, rh * 1.15, rh * 0.92);
        }
        c.fillStyle = 'rgba(24,30,34,0.35)';
        c.fillRect(0, y + rh * 0.86, w, rh * 0.14);
      }
      blotches(p, 14, ['#44525a', '#7d8d95'], 30, 90, 0.22);
      grain(c, w, h, 12, rnd);
    },
    101,
  );
  return tex(cv, 6, 4);
}

export function woodTexture(): THREE.CanvasTexture {
  const cv = paint(
    512,
    512,
    (p) => {
      const { c, w, h, rnd } = p;
      c.fillStyle = '#d8c49c';
      c.fillRect(0, 0, w, h);
      const planks = 5;
      const pw = w / planks;
      for (let i = 0; i < planks; i++) {
        const x = i * pw;
        c.fillStyle = hexAlpha(rnd() > 0.5 ? '#cbb389' : '#e0cea8', 0.55);
        c.fillRect(x, 0, pw, h);
        for (let k = 0; k < 22; k++) {
          c.strokeStyle = hexAlpha(rnd() > 0.5 ? '#a9926a' : '#f0e2c2', lerp(0.08, 0.28, rnd()));
          c.lineWidth = lerp(0.6, 2.2, rnd());
          c.beginPath();
          const x0 = x + rnd() * pw;
          c.moveTo(x0, 0);
          c.bezierCurveTo(x0 + lerp(-8, 8, rnd()), h * 0.33, x0 + lerp(-8, 8, rnd()), h * 0.66, x0 + lerp(-6, 6, rnd()), h);
          c.stroke();
        }
        wobblyLine(p, x, 0, x, h, 1.6, '#9c855e', 0.5, 1.4);
      }
      grain(c, w, h, 12, rnd);
    },
    111,
  );
  return tex(cv, 2, 2);
}

export function copingTexture(): THREE.CanvasTexture {
  const cv = paint(
    512,
    512,
    (p) => {
      const { c, w, h, rnd } = p;
      c.fillStyle = '#e6e2d3';
      c.fillRect(0, 0, w, h);
      const n = 4;
      const s = w / n;
      for (let i = 0; i < n; i++) {
        for (let j = 0; j < n; j++) {
          c.fillStyle = hexAlpha(rnd() > 0.5 ? '#f4f1e6' : '#dbd6c5', 0.7);
          c.fillRect(i * s + 2, j * s + 2, s - 4, s - 4);
        }
      }
      blotches(p, 16, ['#c9c4b2', '#fffdf4'], 20, 80, 0.26);
      speckles(p, 500, ['#bdb8a6', '#ffffff'], 0.5, 1.8, 0.3);
      grain(c, w, h, 10, rnd);
    },
    121,
  );
  return tex(cv, 6, 6);
}

export function poolFloorTexture(): THREE.CanvasTexture {
  const cv = paint(
    512,
    512,
    (p) => {
      const { c, w, h, rnd } = p;
      c.fillStyle = '#9fdbe8';
      c.fillRect(0, 0, w, h);
      const n = 8;
      const s = w / n;
      for (let i = 0; i < n; i++) {
        for (let j = 0; j < n; j++) {
          c.fillStyle = hexAlpha(i % 2 === j % 2 ? '#bfeaf3' : '#8fd2e2', 0.65);
          c.fillRect(i * s + 1.5, j * s + 1.5, s - 3, s - 3);
        }
      }
      blotches(p, 20, ['#d8f4fa', '#79c4d8'], 30, 110, 0.3);
      grain(c, w, h, 8, rnd);
    },
    131,
  );
  return tex(cv, 4, 3);
}

export function hedgeTexture(): THREE.CanvasTexture {
  const cv = paint(
    256,
    256,
    (p) => {
      const { c, w, h, rnd } = p;
      c.fillStyle = '#37702a';
      c.fillRect(0, 0, w, h);
      blotches(p, 40, ['#2b5c20', '#4b8c33', '#5da03c'], 14, 50, 0.5);
      for (let i = 0; i < 700; i++) {
        c.fillStyle = hexAlpha(rnd() > 0.55 ? '#63ac45' : '#255018', lerp(0.2, 0.6, rnd()));
        c.beginPath();
        c.ellipse(rnd() * w, rnd() * h, lerp(2, 5, rnd()), lerp(1.5, 3.6, rnd()), rnd() * Math.PI, 0, Math.PI * 2);
        c.fill();
      }
      grain(c, w, h, 16, rnd);
    },
    141,
  );
  return tex(cv, 2, 2);
}

export function wallTexture(): THREE.CanvasTexture {
  const cv = paint(
    512,
    512,
    (p) => {
      const { c, w, h, rnd } = p;
      c.fillStyle = '#e9dfcd';
      c.fillRect(0, 0, w, h);
      blotches(p, 14, ['#dccfb8', '#f6efe2'], 40, 160, 0.24);
      // faint damask-ish pattern
      for (let i = 0; i < 26; i++) {
        const x = rnd() * w;
        const y = rnd() * h;
        c.strokeStyle = hexAlpha('#c8b79b', 0.18);
        c.lineWidth = 1.2;
        c.beginPath();
        c.ellipse(x, y, 9, 14, rnd() * Math.PI, 0, Math.PI * 2);
        c.stroke();
      }
      grain(c, w, h, 8, rnd);
    },
    151,
  );
  return tex(cv, 3, 2);
}

export function carpetTexture(): THREE.CanvasTexture {
  const cv = paint(
    256,
    256,
    (p) => {
      const { c, w, h, rnd } = p;
      c.fillStyle = '#b8534a';
      c.fillRect(0, 0, w, h);
      blotches(p, 18, ['#9c4038', '#cc6b60'], 20, 90, 0.3);
      speckles(p, 1800, ['#8f3a33', '#d97f73'], 0.5, 1.6, 0.35);
      for (let i = 0; i < 10; i++) {
        c.strokeStyle = hexAlpha('#e0a396', 0.3);
        c.lineWidth = 2;
        c.strokeRect(18 + i * 6, 18 + i * 6, w - 36 - i * 12, h - 36 - i * 12);
      }
      grain(c, w, h, 12, rnd);
    },
    161,
  );
  return tex(cv, 1, 1);
}

export function dashingTexture(): THREE.CanvasTexture {
  const cv = paint(64, 64, (p) => {
    const { c, w, h } = p;
    c.clearRect(0, 0, w, h);
    c.fillStyle = '#e8e4d6';
    c.fillRect(w * 0.36, h * 0.2, w * 0.28, h * 0.6);
  });
  return tex(cv, 1, 1);
}

// ---------------------------------------------------------------------------
// sprites & shader aids
// ---------------------------------------------------------------------------

/** Soft radial glow used for sun orbs, sparks and light bloom sprites. */
export function glowTexture(): THREE.CanvasTexture {
  const cv = paint(128, 128, (p) => {
    const { c, w, h } = p;
    const g = c.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, w / 2);
    g.addColorStop(0, 'rgba(255,255,255,1)');
    g.addColorStop(0.35, 'rgba(255,240,150,0.75)');
    g.addColorStop(1, 'rgba(255,220,90,0)');
    c.fillStyle = g;
    c.fillRect(0, 0, w, h);
  });
  const t = tex(cv);
  t.wrapS = THREE.ClampToEdgeWrapping;
  t.wrapT = THREE.ClampToEdgeWrapping;
  return t;
}

/** Hovered-tile marker: bright rounded frame with a soft inner wash. */
export function tileHighlightTexture(): THREE.CanvasTexture {
  const cv = paint(128, 128, (p) => {
    const { c, w, h } = p;
    c.clearRect(0, 0, w, h);
    c.fillStyle = 'rgba(255,255,255,0.14)';
    c.fillRect(0, 0, w, h);
    c.strokeStyle = 'rgba(255,255,255,0.95)';
    c.lineWidth = 6;
    c.setLineDash([16, 9]);
    c.strokeRect(4, 4, w - 8, h - 8);
    c.setLineDash([]);
    const g = c.createLinearGradient(0, 0, 0, h);
    g.addColorStop(0, 'rgba(255,255,255,0.35)');
    g.addColorStop(1, 'rgba(255,255,255,0.05)');
    c.fillStyle = g;
    c.fillRect(0, 0, w, h);
  });
  const t = tex(cv);
  t.wrapS = THREE.ClampToEdgeWrapping;
  t.wrapT = THREE.ClampToEdgeWrapping;
  return t;
}

/** Grayscale fbm used by the water shader for ripples and sparkle. */
export function waterNoiseTexture(): THREE.CanvasTexture {
  const noise = makeNoise2D(909);
  const cv = paint(256, 256, (p) => {
    const { c, w, h } = p;
    const img = c.createImageData(w, h);
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        const u = (x / w) * 8;
        const v = (y / h) * 8;
        const n = fbm(noise, u, v, 4, 0.55);
        const i = (y * w + x) * 4;
        const val = clamp(Math.round(n * 255), 0, 255);
        img.data[i] = val;
        img.data[i + 1] = val;
        img.data[i + 2] = val;
        img.data[i + 3] = 255;
      }
    }
    c.putImageData(img, 0, 0);
  });
  return tex(cv, 1, 1, false);
}
