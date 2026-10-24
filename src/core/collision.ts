/**
 * Hand-authored collision world. Geometry builders register walkable floors
 * and solid boxes as they create meshes, so collision and visuals cannot drift.
 *
 * The player is modelled as a vertical cylinder: it walks on the highest floor
 * beneath its feet (with a step-up allowance), and solid boxes only block when
 * their vertical span overlaps the player's body. That lets a floor slab be
 * walkable on top while the space underneath stays free.
 */
export interface Rect {
  x0: number;
  x1: number;
  z0: number;
  z1: number;
}

export type FloorAxis = 'flat' | 'x' | 'z';

export interface Floor extends Rect {
  /** Height at (x0,z0). For flat floors this is the only height. */
  y0: number;
  /** Height at the far corner (x1,z1) for ramps. */
  y1: number;
  axis: FloorAxis;
  /** Optional tag for gameplay queries (e.g. 'pool', 'stairs'). */
  tag?: string;
}

export interface WallBox extends Rect {
  y0: number;
  y1: number;
}

export const STEP_HEIGHT = 0.55;
export const PLAYER_RADIUS = 0.33;
export const PLAYER_HEIGHT = 1.75;
export const EYE_HEIGHT = 1.63;

export class Collision {
  readonly floors: Floor[] = [];
  readonly walls: WallBox[] = [];
  readonly water: Rect[] = [];

  addFloor(x0: number, x1: number, z0: number, z1: number, y: number, tag?: string): Floor {
    const f: Floor = { x0, x1, z0, z1, y0: y, y1: y, axis: 'flat', tag };
    this.floors.push(f);
    return f;
  }

  /** A sloped walkable surface (stairs). Height runs from y0 at the low edge to y1. */
  addRamp(x0: number, x1: number, z0: number, z1: number, y0: number, y1: number, axis: 'x' | 'z', tag?: string): Floor {
    const f: Floor = { x0, x1, z0, z1, y0, y1, axis, tag };
    this.floors.push(f);
    return f;
  }

  addWall(x0: number, x1: number, z0: number, z1: number, y0: number, y1: number): WallBox {
    const w: WallBox = { x0, x1, z0, z1, y0, y1 };
    this.walls.push(w);
    return w;
  }

  /** Convenience: wall from a rect and a height range. */
  addWallRect(r: Rect, y0: number, y1: number): WallBox {
    return this.addWall(r.x0, r.x1, r.z0, r.z1, y0, y1);
  }

  addWater(r: Rect): void {
    this.water.push(r);
  }

  inWater(x: number, z: number): boolean {
    for (const w of this.water) {
      if (x >= w.x0 && x <= w.x1 && z >= w.z0 && z <= w.z1) return true;
    }
    return false;
  }

  /** Highest floor at (x,z) that the player can step onto from feetY. */
  groundAt(x: number, z: number, feetY: number, step = STEP_HEIGHT): number | null {
    let best: number | null = null;
    const limit = feetY + step;
    for (const f of this.floors) {
      if (x < f.x0 || x > f.x1 || z < f.z0 || z > f.z1) continue;
      const h = floorHeight(f, x, z);
      if (h > limit) continue;
      if (best === null || h > best) best = h;
    }
    return best;
  }

  /** Floor height ignoring the step limit (used for spawning / falling). */
  highestFloor(x: number, z: number, below = Infinity): number | null {
    let best: number | null = null;
    for (const f of this.floors) {
      if (x < f.x0 || x > f.x1 || z < f.z0 || z > f.z1) continue;
      const h = floorHeight(f, x, z);
      if (h > below) continue;
      if (best === null || h > best) best = h;
    }
    return best;
  }

  /** True when a cylinder at (x,z) would intersect a solid box. */
  blocked(
    x: number,
    z: number,
    feetY: number,
    radius = PLAYER_RADIUS,
    height = PLAYER_HEIGHT,
    step = STEP_HEIGHT,
  ): boolean {
    const lo = feetY + step;
    const hi = feetY + height;
    for (const w of this.walls) {
      if (w.y1 <= lo || w.y0 >= hi) continue;
      const cx = Math.max(w.x0, Math.min(x, w.x1));
      const cz = Math.max(w.z0, Math.min(z, w.z1));
      const dx = x - cx;
      const dz = z - cz;
      if (dx * dx + dz * dz < radius * radius) return true;
    }
    return false;
  }

  /**
   * Slide-move a cylinder by (dx,dz), resolving each axis separately.
   * Subdivided so fast motion cannot tunnel through thin walls.
   */
  slide(
    from: { x: number; z: number },
    dx: number,
    dz: number,
    feetY: number,
    radius = PLAYER_RADIUS,
  ): { x: number; z: number } {
    let { x, z } = from;
    const dist = Math.hypot(dx, dz);
    const parts = Math.max(1, Math.ceil(dist / 0.1));
    const sx = dx / parts;
    const sz = dz / parts;
    for (let i = 0; i < parts; i++) {
      const nx = x + sx;
      if (!this.blocked(nx, z, feetY, radius)) x = nx;
      const nz = z + sz;
      if (!this.blocked(x, nz, feetY, radius)) z = nz;
    }
    return { x, z };
  }
}

export function floorHeight(f: Floor, x: number, z: number): number {
  if (f.axis === 'flat') return f.y0;
  const t =
    f.axis === 'x'
      ? (x - f.x0) / Math.max(1e-6, f.x1 - f.x0)
      : (z - f.z0) / Math.max(1e-6, f.z1 - f.z0);
  return f.y0 + (f.y1 - f.y0) * Math.min(1, Math.max(0, t));
}
