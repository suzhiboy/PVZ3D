/**
 * Everything that makes the lots feel like an American suburb: picket and
 * privacy fences, hedges, trees, a mailbox, a lamp post, neighbour houses,
 * patio furniture and pool toys. Picket planks are batched into InstancedMesh
 * so a 25 m run costs one draw call.
 */
import * as THREE from 'three';
import type { Collision } from '../core/collision.ts';
import { mulberry32 } from '../core/mathx.ts';
import { PALETTE, getAssets, solid, textured, toon, uvScale } from '../core/materials.ts';
import { boxAt, cylinderAt, sphereAt } from './parts.ts';
import { HOUSE, POOL, STREET } from './layout.ts';

const UP = new THREE.Vector3(0, 1, 0);

/**
 * Foliage is built from faceted icosahedra rather than smooth spheres: the flat
 * facets catch the key light in hard patches, which is what makes the canopy
 * read as painted clumps of leaves instead of a green balloon.
 */
const CLUMP_GEO = new THREE.IcosahedronGeometry(1, 1);
const LEAF_TONES = [0x74c95a, 0x5bb048, 0x469a3c, 0x357f33] as const;

function clump(
  x: number,
  y: number,
  z: number,
  r: number,
  tone: number,
  rng: () => number,
  squash = 0.84,
): THREE.Mesh {
  const m = new THREE.Mesh(CLUMP_GEO, toon(tone));
  m.position.set(x, y, z);
  m.rotation.set(rng() * Math.PI * 2, rng() * Math.PI * 2, rng() * Math.PI * 2);
  m.scale.set(r, r * squash, r * (0.9 + rng() * 0.2));
  m.castShadow = true;
  m.receiveShadow = true;
  return m;
}

/** Collects transforms for one geometry/material pair and emits one InstancedMesh. */
class Instances {
  private readonly list: THREE.Matrix4[] = [];
  private readonly one = new THREE.Vector3(1, 1, 1);
  private readonly pos = new THREE.Vector3();
  private readonly quat = new THREE.Quaternion();

  constructor(
    private readonly geo: THREE.BufferGeometry,
    private readonly mat: THREE.Material,
  ) {}

  add(x: number, y: number, z: number, ry = 0, sx = 1, sy = 1, sz = 1): void {
    const m = new THREE.Matrix4();
    this.pos.set(x, y, z);
    this.quat.setFromAxisAngle(UP, ry);
    m.compose(this.pos, this.quat, this.one.set(sx, sy, sz));
    this.list.push(m);
  }

  flush(parent: THREE.Object3D): void {
    if (this.list.length === 0) return;
    const im = new THREE.InstancedMesh(this.geo, this.mat, this.list.length);
    for (let i = 0; i < this.list.length; i++) im.setMatrixAt(i, this.list[i]);
    im.instanceMatrix.needsUpdate = true;
    im.castShadow = true;
    im.receiveShadow = true;
    parent.add(im);
  }
}

interface FenceStyle {
  height: number;
  privacy: boolean;
}

/** One straight fence run between two points (axis aligned in practice). */
function fenceRun(
  scene: THREE.Scene,
  col: Collision,
  pickets: Instances,
  posts: Instances,
  x0: number,
  z0: number,
  x1: number,
  z1: number,
  style: FenceStyle,
): void {
  const alongX = Math.abs(x1 - x0) >= Math.abs(z1 - z0);
  const a0 = alongX ? Math.min(x0, x1) : Math.min(z0, z1);
  const a1 = alongX ? Math.max(x0, x1) : Math.max(z0, z1);
  const fixed = alongX ? z0 : x0;
  const h = style.height;
  const ry = alongX ? 0 : Math.PI / 2;
  const railMat = solid(style.privacy ? PALETTE.darkWood : PALETTE.trimShadow);

  // rails (two for picket, cap for privacy)
  const railYs = style.privacy ? [h - 0.09] : [0.34, 0.84];
  for (const ry2 of railYs) {
    const len = a1 - a0;
    const rail = boxAt(
      alongX ? len : 0.07,
      style.privacy ? 0.09 : 0.08,
      alongX ? 0.07 : len,
      railMat,
      alongX ? (a0 + a1) / 2 : fixed,
      ry2,
      alongX ? fixed : (a0 + a1) / 2,
    );
    scene.add(rail);
  }

  // posts
  const postStep = style.privacy ? 2.4 : 2.2;
  const postH = h + (style.privacy ? 0.12 : 0.14);
  for (let a = a0; a <= a1 + 0.01; a += postStep) {
    posts.add(
      alongX ? a : fixed,
      postH / 2,
      alongX ? fixed : a,
      ry,
      style.privacy ? 1.35 : 1.2,
      postH,
      style.privacy ? 1.35 : 1.2,
    );
  }

  // planks
  const pitch = style.privacy ? 0.152 : 0.168;
  for (let a = a0 + 0.09; a <= a1 - 0.06; a += pitch) {
    pickets.add(
      alongX ? a : fixed,
      h / 2,
      alongX ? fixed : a,
      ry,
      style.privacy ? 1.55 : 1,
      h,
      style.privacy ? 1.42 : 1,
    );
  }

  // collision slab
  const pad = 0.09;
  if (alongX) col.addWall(a0, a1, fixed - pad, fixed + pad, 0, h);
  else col.addWall(fixed - pad, fixed + pad, a0, a1, 0, h);
}

interface HedgeOpts {
  height: number;
  rng: () => number;
}

function hedgeRow(
  scene: THREE.Scene,
  col: Collision,
  x0: number,
  z0: number,
  x1: number,
  z1: number,
  opts: HedgeOpts,
): void {
  const assets = getAssets();
  const w = Math.abs(x1 - x0);
  const d = Math.abs(z1 - z0);
  const h = opts.height;
  const geo = new THREE.BoxGeometry(Math.max(w, 0.7), h, Math.max(d, 0.7));
  uvScale(geo, Math.max(w, 0.7) / 2.2, h / 2.2);
  const mesh = new THREE.Mesh(geo, textured(assets.hedge));
  mesh.position.set((x0 + x1) / 2, h / 2, (z0 + z1) / 2);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  scene.add(mesh);

  const alongX = w >= d;
  const len = Math.max(w, d);
  const count = Math.max(3, Math.round(len / 0.62));
  for (let i = 0; i < count; i++) {
    const t = (i + 0.5) / count;
    const tone = LEAF_TONES[i % 3];
    const r = 0.34 + opts.rng() * 0.16;
    scene.add(
      clump(
        alongX ? Math.min(x0, x1) + len * t : (x0 + x1) / 2 + (opts.rng() - 0.5) * 0.34,
        h - 0.08 + opts.rng() * 0.14,
        alongX ? (z0 + z1) / 2 + (opts.rng() - 0.5) * 0.34 : Math.min(z0, z1) + len * t,
        r,
        tone,
        opts.rng,
        0.72,
      ),
    );
  }
  col.addWall(
    Math.min(x0, x1) - 0.3,
    Math.max(x0, x1) + 0.3,
    Math.min(z0, z1) - 0.3,
    Math.max(z0, z1) + 0.3,
    0,
    h,
  );
}

function bush(scene: THREE.Scene, x: number, z: number, r: number, rng: () => number): void {
  // five overlapping clumps: one low mass, three shoulders, one bright crown
  const layout: readonly (readonly [number, number, number, number, number])[] = [
    [0, 0.46, 0, 0.78, 2],
    [-0.5, 0.4, 0.34, 0.56, 1],
    [0.52, 0.36, -0.3, 0.54, 1],
    [-0.28, 0.4, -0.46, 0.5, 2],
    [0.2, 0.78, 0.06, 0.6, 0],
  ];
  for (const [dx, dy, dz, s, tone] of layout) {
    const jitter = 0.9 + rng() * 0.22;
    scene.add(
      clump(x + dx * r, dy * r, z + dz * r, r * s * jitter, LEAF_TONES[tone], rng, 0.86),
    );
  }
}

function tree(
  scene: THREE.Scene,
  col: Collision,
  x: number,
  z: number,
  height: number,
  rng: () => number,
): void {
  const bark = solid(0x5f4834);
  const trunk = cylinderAt(height * 0.035, height * 0.062, height * 0.56, bark, x, 0, z, 10);
  scene.add(trunk);
  // two visible limbs so the crown does not float on a pole
  for (const s of [-1, 1]) {
    const limb = cylinderAt(height * 0.016, height * 0.026, height * 0.2, bark, x, 0, z, 8);
    limb.position.set(x + s * height * 0.05, height * 0.44, z + s * height * 0.03);
    limb.rotation.z = s * 0.6;
    limb.rotation.x = s * 0.3;
    scene.add(limb);
  }
  const crownY = height * 0.66;
  const r = height * 0.3;
  // a dome of 9 clumps: the low ring reads dark, the crown catches the light
  const ring = 5;
  for (let i = 0; i < ring; i++) {
    const a = (i / ring) * Math.PI * 2 + rng() * 0.5;
    const rr = r * (0.44 + rng() * 0.14);
    scene.add(
      clump(
        x + Math.cos(a) * r * 0.62,
        crownY - r * 0.08 + rng() * r * 0.16,
        z + Math.sin(a) * r * 0.62,
        rr,
        LEAF_TONES[1 + (i % 3)],
        rng,
        0.78,
      ),
    );
  }
  for (let i = 0; i < 4; i++) {
    const a = (i / 4) * Math.PI * 2 + 0.7 + rng() * 0.4;
    scene.add(
      clump(
        x + Math.cos(a) * r * 0.3,
        crownY + r * (0.3 + rng() * 0.18),
        z + Math.sin(a) * r * 0.3,
        r * (0.4 + rng() * 0.14),
        i % 2 === 0 ? LEAF_TONES[0] : LEAF_TONES[1],
        rng,
        0.9,
      ),
    );
  }
  scene.add(clump(x, crownY + r * 0.5, z, r * 0.5, LEAF_TONES[0], rng, 0.86));
  col.addWall(x - 0.28, x + 0.28, z - 0.28, z + 0.28, 0, height * 0.45);
}

function mailbox(scene: THREE.Scene, col: Collision, x: number, z: number, ry: number): void {
  const wood = solid(PALETTE.darkWood);
  const metal = solid(0xe8e4da);
  const post = boxAt(0.09, 1.02, 0.09, wood, x, 0, z);
  scene.add(post);
  const body = new THREE.Group();
  const box = boxAt(0.26, 0.22, 0.44, metal, 0, 1.02, 0);
  body.add(box);
  const arch = cylinderAt(0.13, 0.13, 0.44, metal, 0, 1.24, 0, 10);
  arch.rotation.z = Math.PI / 2;
  arch.scale.set(1, 0.55, 1);
  body.add(arch);
  const flag = boxAt(0.03, 0.18, 0.06, solid(0xd8493f), 0.15, 1.2, 0.08);
  body.add(flag);
  body.position.set(x, 0, z);
  body.rotation.y = ry;
  scene.add(body);
  col.addWall(x - 0.22, x + 0.22, z - 0.22, z + 0.22, 0, 1.3);
}

function lampPost(scene: THREE.Scene, col: Collision, x: number, z: number): void {
  const metal = solid(0x3d4148);
  scene.add(cylinderAt(0.09, 0.13, 3.6, metal, x, 0, z, 10));
  scene.add(cylinderAt(0.22, 0.26, 0.16, metal, x, 0, z, 10));
  const arm = boxAt(0.7, 0.09, 0.09, metal, x + 0.3, 3.52, z);
  scene.add(arm);
  const head = new THREE.Group();
  head.add(boxAt(0.34, 0.13, 0.34, metal, 0, 0, 0));
  head.add(
    boxAt(0.26, 0.1, 0.26, solid(0xfff0bd, { emissive: 0xffe6a3, emissiveIntensity: 0.7 }), 0, -0.1, 0),
  );
  head.position.set(x + 0.62, 3.4, z);
  scene.add(head);
  col.addWall(x - 0.2, x + 0.2, z - 0.2, z + 0.2, 0, 3.6);
}

function hydrant(scene: THREE.Scene, col: Collision, x: number, z: number): void {
  const red = solid(0xc83f33);
  scene.add(cylinderAt(0.13, 0.16, 0.52, red, x, 0, z, 10));
  scene.add(cylinderAt(0.16, 0.13, 0.1, red, x, 0.52, z, 10));
  const dome = sphereAt(0.13, red, x, 0.62, z, 10);
  dome.scale.y = 0.7;
  scene.add(dome);
  for (const dir of [-1, 1]) {
    const nozzle = cylinderAt(0.055, 0.055, 0.16, red, x + dir * 0.15, 0.3, z, 8);
    nozzle.rotation.z = Math.PI / 2;
    scene.add(nozzle);
  }
  col.addWall(x - 0.2, x + 0.2, z - 0.2, z + 0.2, 0, 0.7);
}

function patioTable(scene: THREE.Scene, col: Collision, x: number, z: number): void {
  const assets = getAssets();
  const white = solid(0xf1ece1);
  const top = cylinderAt(0.62, 0.62, 0.07, white, x, 0.7, z, 16);
  scene.add(top);
  scene.add(cylinderAt(0.06, 0.09, 0.7, white, x, 0, z, 8));
  scene.add(cylinderAt(0.36, 0.4, 0.06, white, x, 0.01, z, 12));
  // umbrella
  scene.add(cylinderAt(0.035, 0.035, 2.45, solid(PALETTE.woodLight), x, 0.06, z, 8));
  const canopy = new THREE.Mesh(
    new THREE.ConeGeometry(1.15, 0.4, 10, 1, true),
    solid(0xe8f0f4, { side: THREE.DoubleSide }),
  );
  canopy.position.set(x, 2.45, z);
  canopy.castShadow = true;
  scene.add(canopy);
  for (let i = 0; i < 2; i++) {
    const cz = z + (i === 0 ? -0.95 : 0.95);
    scene.add(boxAt(0.42, 0.06, 0.42, textured(assets.wood, 0xd8c49a), x, 0.42, cz));
    scene.add(boxAt(0.06, 0.42, 0.06, white, x - 0.16, 0, cz - 0.16));
    scene.add(boxAt(0.06, 0.42, 0.06, white, x + 0.16, 0, cz - 0.16));
    scene.add(boxAt(0.06, 0.42, 0.06, white, x - 0.16, 0, cz + 0.16));
    scene.add(boxAt(0.06, 0.42, 0.06, white, x + 0.16, 0, cz + 0.16));
    const back = boxAt(0.42, 0.45, 0.06, white, x, 0.48, cz + (i === 0 ? -0.18 : 0.18));
    scene.add(back);
  }
  col.addWall(x - 0.7, x + 0.7, z - 0.7, z + 0.7, 0, 0.8);
}

function lounger(scene: THREE.Scene, col: Collision, x: number, z: number, ry: number): void {
  const g = new THREE.Group();
  const frame = solid(PALETTE.woodLight);
  const pad = solid(PALETTE.fabricGreen);
  g.add(boxAt(0.62, 0.07, 1.7, pad, 0, 0.3, 0));
  for (const sx of [-0.26, 0.26]) {
    for (const sz of [-0.76, 0.76]) g.add(boxAt(0.05, 0.3, 0.05, frame, sx, 0, sz));
  }
  const back = boxAt(0.62, 0.07, 0.72, pad, 0, 0.34, -0.78);
  back.rotation.x = -0.85;
  g.add(back);
  g.position.set(x, 0, z);
  g.rotation.y = ry;
  scene.add(g);
  const half = 0.9;
  col.addWall(x - half, x + half, z - half, z + half, 0, 0.55);
}

function neighbourHouse(scene: THREE.Scene, x: number, z: number, ry: number, rng: () => number): void {
  const assets = getAssets();
  const g = new THREE.Group();
  const w = 7.5;
  const d = 8.5;
  const h = 4.4;
  const wall = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), textured(assets.siding, 0xf2e6d2));
  wall.position.y = h / 2;
  wall.castShadow = true;
  wall.receiveShadow = true;
  g.add(wall);
  const roofMat = solid(rng() > 0.5 ? 0x7a3f36 : 0x4a5761);
  for (const dir of [-1, 1]) {
    const slope = boxAt(w + 0.7, 0.22, d * 0.62, roofMat, 0, h + 0.72, 0);
    slope.rotation.x = dir * 0.62;
    slope.position.z = dir * d * 0.24;
    g.add(slope);
  }
  const door = boxAt(0.95, 2.1, 0.12, solid(PALETTE.darkWood), 0, 0, d / 2 + 0.02);
  g.add(door);
  const glass = solid(0x8fb6c4);
  const frame = solid(PALETTE.trim);
  for (let i = 0; i < 3; i++) {
    const wx = -2.2 + i * 2.2;
    const win = boxAt(1.1, 1.1, 0.1, glass, wx, 1.3, d / 2 + 0.02);
    g.add(win);
    for (const oy of [0, 1.16]) for (const ox of [-0.6, 0.56]) {
      g.add(boxAt(0.08, 0.06, 0.14, frame, wx + ox, 1.3 + oy, d / 2 + 0.02));
    }
  }
  g.position.set(x, 0, z);
  g.rotation.y = ry;
  scene.add(g);
}

function poolToys(scene: THREE.Scene, rng: () => number): void {
  const cx = (POOL.x0 + POOL.x1) / 2;
  const y = POOL.surfaceY + 0.02;
  const ringMat = solid(PALETTE.flowerPink);
  const ringMat2 = solid(PALETTE.flowerYellow);
  const ringGeo = new THREE.TorusGeometry(0.3, 0.085, 8, 18);
  const spots: Array<[number, number]> = [
    [-2.6, -0.6],
    [1.2, 0.7],
    [3.4, -0.9],
    [6.4, 0.9],
  ];
  for (let i = 0; i < spots.length; i++) {
    const ring = new THREE.Mesh(ringGeo, i % 2 === 0 ? ringMat : ringMat2);
    ring.rotation.x = -Math.PI / 2;
    ring.position.set(cx + spots[i][0], y, spots[i][1]);
    ring.castShadow = true;
    scene.add(ring);
  }
  const ball = sphereAt(0.19, solid(0xf6f2e8), cx + 4.6 + rng() * 0.4, y + 0.16, -0.4, 12);
  scene.add(ball);
  const stripe = new THREE.Mesh(new THREE.TorusGeometry(0.19, 0.035, 6, 16), solid(PALETTE.flowerRed));
  stripe.position.copy(ball.position);
  stripe.rotation.x = Math.PI / 2;
  scene.add(stripe);
}

export function buildScenery(scene: THREE.Scene, col: Collision): void {
  const rng = mulberry32(20240607);

  const picketGeo = new THREE.BoxGeometry(0.095, 1, 0.03);
  const postGeo = new THREE.BoxGeometry(0.12, 1, 0.12);
  const pickets = new Instances(picketGeo, solid(0xf0e9d8));
  const posts = new Instances(postGeo, solid(0xe4dcc8));

  // ---- front yard boundary (north + south of the front lawn) ----
  fenceRun(scene, col, pickets, posts, HOUSE.x1 - 0.1, -5.35, STREET.curbX + 0.4, -5.35, {
    height: 1.02,
    privacy: false,
  });
  fenceRun(scene, col, pickets, posts, HOUSE.x1 - 0.1, 4.72, STREET.curbX + 0.4, 4.72, {
    height: 1.02,
    privacy: false,
  });

  // ---- backyard: privacy fence on three sides ----
  const backWest = -35.9;
  fenceRun(scene, col, pickets, posts, backWest, -5.6, backWest, 5.6, { height: 1.85, privacy: true });
  fenceRun(scene, col, pickets, posts, backWest, -5.6, HOUSE.x0 + 0.1, -5.6, {
    height: 1.85,
    privacy: true,
  });
  fenceRun(scene, col, pickets, posts, backWest, 5.6, HOUSE.x0 + 0.1, 5.6, {
    height: 1.85,
    privacy: true,
  });

  // far side of the street: low picket along the far sidewalk
  fenceRun(scene, col, pickets, posts, STREET.farWalkX + 0.3, -24, STREET.farWalkX + 0.3, 24, {
    height: 0.9,
    privacy: false,
  });

  pickets.flush(scene);
  posts.flush(scene);

  // ---- hedges ----
  hedgeRow(scene, col, HOUSE.x1 - 0.2, -6.6, HOUSE.x1 + 4.2, -6.2, { height: 1.3, rng });
  hedgeRow(scene, col, HOUSE.x1 - 0.2, 5.9, HOUSE.x1 + 3.0, 6.35, { height: 1.15, rng });
  hedgeRow(scene, col, backWest + 0.15, -4.8, backWest + 4.6, -4.5, { height: 1.25, rng });
  hedgeRow(scene, col, HOUSE.x0 - 2.4, 5.35, HOUSE.x0, 5.05, { height: 1.1, rng });

  // ---- foundation planting in front of the house ----
  for (let i = 0; i < 7; i++) {
    bush(scene, HOUSE.x1 + 0.65 + (i % 3) * 1.55, -5.6 + Math.floor(i / 3) * 1.1 + rng() * 0.4, 0.5, rng);
  }
  bush(scene, HOUSE.x1 + 1.1, 2.4, 0.62, rng);
  bush(scene, HOUSE.x1 + 1.9, 3.3, 0.5, rng);

  // ---- trees ----
  tree(scene, col, STREET.farWalkX + 4.0, -7.5, 7.4, rng);
  tree(scene, col, STREET.farWalkX + 4.6, 3.0, 6.6, rng);
  tree(scene, col, STREET.farWalkX + 3.8, 14.5, 7.0, rng);
  tree(scene, col, 2.0, 8.5, 6.2, rng);
  tree(scene, col, -4.6, 9.2, 7.1, rng);
  tree(scene, col, backWest - 2.6, -6.6, 7.8, rng);
  tree(scene, col, backWest - 3.2, 0.4, 6.8, rng);
  tree(scene, col, backWest - 2.2, 7.2, 7.4, rng);
  tree(scene, col, -26.0, 8.4, 6.6, rng);
  tree(scene, col, -14.0, 9.6, 7.0, rng);

  // ---- street furniture ----
  mailbox(scene, col, STREET.curbX - 0.75, -4.6, 0);
  lampPost(scene, col, STREET.curbX - 0.6, -8.5);
  lampPost(scene, col, STREET.curbX - 0.6, 12.5);
  hydrant(scene, col, STREET.curbX - 0.5, 2.6);

  // ---- neighbours + shed ----
  neighbourHouse(scene, 25.5, -9.0, -Math.PI / 2 + 0.15, rng);
  neighbourHouse(scene, 27.0, 13.5, -Math.PI / 2 - 0.2, rng);

  // ---- patio furniture on the pool-side strip ----
  patioTable(scene, col, -19.15, 4.15);
  lounger(scene, col, -19.6, -2.8, Math.PI / 2);
  lounger(scene, col, -19.6, -4.4, Math.PI / 2);

  // ---- pool toys ----
  poolToys(scene, rng);

  // ---- decorative pots by the porch ----
  const potMat = solid(PALETTE.terracotta);
  for (const [px, pz] of [
    [HOUSE.x1 + 0.55, -2.9],
    [HOUSE.x1 + 0.55, 1.5],
  ]) {
    scene.add(cylinderAt(0.24, 0.17, 0.42, potMat, px, 0.05, pz, 10));
    bush(scene, px, pz, 0.32, rng);
  }

  // garden gnome guarding the front walk
  const gnome = new THREE.Group();
  gnome.add(cylinderAt(0.14, 0.22, 0.34, solid(0x2f5aa8), 0, 0, 0, 8));
  gnome.add(sphereAt(0.105, solid(0xe8b58f), 0, 0.4, 0, 8));
  const hat = new THREE.Mesh(new THREE.ConeGeometry(0.13, 0.26, 8), solid(0xc23a30));
  hat.position.y = 0.6;
  hat.castShadow = true;
  gnome.add(hat);
  gnome.position.set(-6.6, 0.15, -4.55);
  scene.add(gnome);

  // a couple of distant tree silhouettes to close the horizon
  const farLeaf = solid(0x3f7a3a);
  for (let i = 0; i < 8; i++) {
    const blob = sphereAt(2.6 + rng() * 1.6, farLeaf, -46 + i * 2.4, 3.4 + rng() * 1.4, -26 + rng() * 46, 8);
    scene.add(blob);
  }

}



