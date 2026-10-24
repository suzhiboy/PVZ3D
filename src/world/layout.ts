/**
 * Static world coordinates. Everything in the game derives from this file:
 * the two lawns, the house footprint, and the yards' zombie/mower lines.
 *
 * Axes: +X is east (toward the street in the front yard), +Z is south,
 * +Y is up. The player starts on the porch looking east down the lawn.
 */
export const TILE = 1.6;
export const COLS = 9;

export type YardName = 'front' | 'back';

export interface YardDef {
  readonly name: YardName;
  readonly label: string;
  readonly cols: number;
  readonly rows: number;
  /** Lawn bounds (outer edges of the tiled area). */
  readonly x0: number;
  readonly x1: number;
  readonly z0: number;
  readonly z1: number;
  /** Rows occupied by pool water instead of grass. */
  readonly waterRows: readonly number[];
  /** +1 when the house lies at +X of the lawn, -1 when it lies at -X. */
  readonly houseSide: 1 | -1;
  readonly mowerX: number;
  readonly spawnX: number;
  /** X a zombie reaches to steal the brain (behind the mowers). */
  readonly goalX: number;
}

export class Yard implements YardDef {
  private readonly def: YardDef;

  constructor(def: YardDef) {
    this.def = def;
  }

  get name(): YardName {
    return this.def.name;
  }
  get label(): string {
    return this.def.label;
  }
  get cols(): number {
    return this.def.cols;
  }
  get rows(): number {
    return this.def.rows;
  }
  get x0(): number {
    return this.def.x0;
  }
  get x1(): number {
    return this.def.x1;
  }
  get z0(): number {
    return this.def.z0;
  }
  get z1(): number {
    return this.def.z1;
  }
  get waterRows(): readonly number[] {
    return this.def.waterRows;
  }
  get houseSide(): 1 | -1 {
    return this.def.houseSide;
  }
  get mowerX(): number {
    return this.def.mowerX;
  }
  get spawnX(): number {
    return this.def.spawnX;
  }
  get goalX(): number {
    return this.def.goalX;
  }

  /** Column 0 is always the one closest to the house. */
  colX(c: number): number {
    return this.def.houseSide < 0
      ? this.def.x0 + (c + 0.5) * TILE
      : this.def.x1 - (c + 0.5) * TILE;
  }

  rowZ(r: number): number {
    return this.def.z0 + (r + 0.5) * TILE;
  }

  /** Nearest column index for an X position (unclamped). */
  colAt(x: number): number {
    const raw =
      this.def.houseSide < 0
        ? Math.floor((x - this.def.x0) / TILE)
        : Math.floor((this.def.x1 - x) / TILE);
    return raw;
  }

  rowAt(z: number): number {
    return Math.floor((z - this.def.z0) / TILE);
  }

  inside(x: number, z: number, pad = 0): boolean {
    return (
      x >= this.def.x0 + pad &&
      x <= this.def.x1 - pad &&
      z >= this.def.z0 + pad &&
      z <= this.def.z1 - pad
    );
  }

  isWaterRow(r: number): boolean {
    return this.def.waterRows.includes(r);
  }

  cellWater(c: number, r: number): boolean {
    return c >= 0 && c < this.cols && r >= 0 && r < this.rows && this.isWaterRow(r);
  }

  /** World-space centre of a cell. */
  cellCenter(c: number, r: number): { x: number; z: number } {
    return { x: this.colX(c), z: this.rowZ(r) };
  }

  /** Direction a zombie walks in, in X units: from the spawn line toward the house. */
  get zombieDir(): 1 | -1 {
    return this.def.goalX > this.def.spawnX ? 1 : -1;
  }

  /** Distance from the spawn line to the mower line. */
  get runLength(): number {
    return Math.abs(this.def.mowerX - this.def.spawnX);
  }
}

export const FRONT_YARD = new Yard({
  name: 'front',
  label: '前院',
  cols: COLS,
  rows: 5,
  x0: -7.2,
  x1: 7.2,
  z0: -4.0,
  z1: 4.0,
  waterRows: [],
  houseSide: -1,
  mowerX: -7.0,
  spawnX: 13.6,
  goalX: -7.7,
});

export const BACK_YARD = new Yard({
  name: 'back',
  label: '后院泳池',
  cols: COLS,
  rows: 6,
  x0: -34.8,
  x1: -20.4,
  z0: -4.8,
  z1: 4.8,
  waterRows: [2, 3],
  houseSide: 1,
  mowerX: -20.6,
  spawnX: -34.4,
  goalX: -20.1,
});

export const YARDS: Record<YardName, Yard> = {
  front: FRONT_YARD,
  back: BACK_YARD,
};

/** Pool water surface height and the height the player wades at. */
export const POOL = {
  surfaceY: -0.18,
  wadeY: -0.46,
  floorY: -1.5,
  /** Coping ring geometry, derived from the back lawn. */
  get z0(): number {
    return BACK_YARD.rowZ(2) - TILE / 2;
  },
  get z1(): number {
    return BACK_YARD.rowZ(3) + TILE / 2;
  },
  get x0(): number {
    return BACK_YARD.x0 + 0.25;
  },
  get x1(): number {
    return BACK_YARD.x1 - 0.25;
  },
} as const;

export const HOUSE = {
  /** Outer wall bounds. */
  x0: -18.0,
  x1: -8.2,
  z0: -6.5,
  z1: 6.5,
  wallT: 0.3,
  /** Interior floor height (also porch / deck height). */
  floorY: 0.45,
  storey: 2.9,
  get upperY(): number {
    return this.floorY + this.storey;
  },
  get i0(): number {
    return this.x0 + this.wallT;
  },
  get i1(): number {
    return this.x1 - this.wallT;
  },
  get j0(): number {
    return this.z0 + this.wallT;
  },
  get j1(): number {
    return this.z1 - this.wallT;
  },
  /** Height of the ground-floor ceiling / underside of the upper slab. */
  get slabY(): number {
    return this.upperY - 0.16;
  },
  frontDoorZ: -0.6,
  backDoorZ: 1.6,
  /** Stoop slab in front of the front door. */
  porch: { x0: -8.2, x1: -7.3, z0: -2.2, z1: 1.0 },
  /** Small deck behind the back door. */
  deck: { x0: -19.4, x1: -18.0, z0: -1.2, z1: 3.4 },
  /** Stair run: climbs along -X against the south interior wall. */
  stairs: { x0: -13.9, x1: -9.4, z0: -6.2, z1: -4.9 },
} as const;

/** Where the player is placed when a level starts / after winning. */
export const SPAWNS = {
  front: { x: -7.75, y: HOUSE.floorY, z: -0.6, yaw: -Math.PI / 2 },
  back: { x: -19.0, y: HOUSE.floorY, z: 1.6, yaw: Math.PI / 2 },
  house: { x: -9.2, y: HOUSE.floorY, z: -0.6, yaw: -Math.PI / 2 },
} as const;

/** Road and sidewalk strips east of the front yard. */
export const STREET = {
  curbX: 8.2,
  roadX0: 8.6,
  roadX1: 15.4,
  farWalkX: 16.4,
  z0: -26,
  z1: 26,
} as const;
