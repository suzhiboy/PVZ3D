/**
 * Procedural unit models, drawn in the cartoon register of the original game:
 * fat rounded volumes, one dominant colour per body, a readable face and an ink
 * outline. Every model is authored facing +X so the animation code only has to
 * set `group.rotation.y` to the unit's heading.
 *
 * Two conventions the animation code depends on:
 *   - legs hang *down* from their pivot (geometry at negative Y),
 *   - arms point *forward* along +X from their pivot.
 */
import * as THREE from 'three';
import type { PlantKind, ZombieKind } from './types.ts';
import { applyInk, toon } from '../core/materials.ts';
import { blobTexture } from '../core/textures.ts';

const cache = new Map<string, THREE.Group>();

const BLOB_TEX = blobTexture();
let blobGeo: THREE.PlaneGeometry | null = null;

/** Soft dark disc under a character, so it reads as standing on the lawn. */
function shadowBlob(r: number, y = 0.02): THREE.Mesh {
  blobGeo ??= new THREE.PlaneGeometry(1, 1);
  const m = new THREE.Mesh(
    blobGeo,
    new THREE.MeshBasicMaterial({
      map: BLOB_TEX,
      transparent: true,
      depthWrite: false,
      opacity: 1,
      color: 0x1a2c14,
    }),
  );
  m.rotation.x = -Math.PI / 2;
  m.scale.set(r * 2.6, r * 2.6, 1);
  m.position.y = y;
  m.userData.noInk = true;
  m.renderOrder = 1;
  return m;
}

function ball(
  r: number,
  mat: THREE.Material,
  x: number,
  y: number,
  z: number,
  sx = 1,
  sy = 1,
  sz = 1,
): THREE.Mesh {
  const m = new THREE.Mesh(new THREE.SphereGeometry(r, 18, 14), mat);
  m.position.set(x, y, z);
  m.scale.set(sx, sy, sz);
  m.castShadow = true;
  return m;
}

function box(w: number, h: number, d: number, mat: THREE.Material, x: number, y: number, z: number): THREE.Mesh {
  const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
  m.position.set(x, y, z);
  m.castShadow = true;
  return m;
}

/** Cylinder lying along +X (snouts, discs, pipes). */
function tubeX(rt: number, rb: number, len: number, mat: THREE.Material, x: number, y: number, z: number): THREE.Mesh {
  const m = new THREE.Mesh(new THREE.CylinderGeometry(rt, rb, len, 16), mat);
  m.rotation.z = -Math.PI / 2;
  m.position.set(x, y, z);
  m.castShadow = true;
  return m;
}

/** Capsule standing along +Y, pivoted at its centre. */
function capsuleX(r: number, len: number, mat: THREE.Material, x: number, y: number, z: number): THREE.Mesh {
  const m = new THREE.Mesh(new THREE.CapsuleGeometry(r, len, 6, 14), mat);
  m.rotation.z = -Math.PI / 2;
  m.position.set(x, y, z);
  m.castShadow = true;
  return m;
}

function cone(r: number, h: number, mat: THREE.Material, x: number, y: number, z: number): THREE.Mesh {
  const m = new THREE.Mesh(new THREE.ConeGeometry(r, h, 16), mat);
  m.position.set(x, y, z);
  m.castShadow = true;
  return m;
}

/** A small white eye with a dark pupil, looking along +X. */
function eye(x: number, y: number, z: number, size = 0.075): THREE.Group {
  const g = new THREE.Group();
  g.position.set(x, y, z);
  const white = ball(size, toon(0xfbf7ea), 0, 0, 0, 1, 1, 0.72);
  white.userData.noInk = true;
  const pupil = ball(size * 0.52, toon(0x1b1b22), size * 0.34, 0, size * 0.42, 1, 1, 1);
  pupil.userData.noInk = true;
  const gleam = ball(size * 0.2, toon(0xffffff), size * 0.5, size * 0.24, size * 0.68, 1, 1, 1);
  gleam.userData.noInk = true;
  g.add(white, pupil, gleam);
  return g;
}

/** A dark smile arc lying in the XY plane, opening toward +X. */
function smile(x: number, y: number, z: number, radius: number, mat: THREE.Material): THREE.Mesh {
  const m = new THREE.Mesh(new THREE.TorusGeometry(radius, radius * 0.17, 6, 14, Math.PI * 0.9), mat);
  m.rotation.z = -Math.PI * 0.45;
  m.rotation.y = Math.PI / 2;
  m.position.set(x, y, z);
  m.userData.noInk = true;
  return m;
}

const MAT = {
  stem: 0x4b9440,
  stemDark: 0x33702c,
  leaf: 0x5cb44b,
  leafDark: 0x357d2f,
  petal: 0xffd044,
  petalDark: 0xf5a91d,
  seed: 0x8c5a22,
  seedDark: 0x6b421a,
  pea: 0x74c948,
  peaDark: 0x4c9c2e,
  snow: 0xa9dcef,
  snowDark: 0x74b8d4,
  nut: 0xc98a45,
  nutDark: 0x9d6229,
  cherry: 0xdb3a3f,
  cherryDark: 0xa82430,
  potato: 0xbb8a4d,
  potatoDark: 0x8f6231,
  chomper: 0x9a4fbe,
  chomperLight: 0xc073e0,
  mouth: 0x2c0f28,
  skin: 0xa8c07e,
  skinDark: 0x7f9a5c,
  shirt: 0x6a5aa8,
  shirtDark: 0x4a3d77,
  pants: 0x454964,
  pantsDark: 0x33364b,
  eye: 0x1b1b22,
  shoe: 0x2c2c36,
  cone: 0xe6782a,
  coneDark: 0xb4561a,
  bucket: 0xa6afb9,
  bucketDark: 0x77808a,
  pole: 0x6b5a3f,
  flag: 0xd23b3b,
  hair: 0x3b3a33,
  teeth: 0xfdf6e3,
};

/** Stem, two leaves and a soil collar — the base of every upright plant. */
function stemAndLeaves(g: THREE.Group, height: number): void {
  const stem = capsuleX(0.055, height * 0.72, toon(MAT.stem), 0, height * 0.5, 0);
  stem.rotation.z = Math.PI / 2; // stand it up
  g.add(stem);
  g.add(ball(0.13, toon(MAT.leafDark), 0, 0.04, 0, 1.3, 0.35, 1.1));
  for (const s of [-1, 1]) {
    const leaf = ball(0.23, toon(MAT.leaf), 0.02, 0.16, s * 0.22, 1.35, 0.22, 0.72);
    leaf.rotation.x = s * 0.34;
    leaf.rotation.z = -0.18;
    g.add(leaf);
  }
}

function buildSunflower(): THREE.Group {
  const g = new THREE.Group();
  stemAndLeaves(g, 0.9);

  const head = new THREE.Group();
  head.position.set(0.03, 1.0, 0);
  head.rotation.z = -0.12;

  // petal ring, fanned in the YZ plane so it faces +X
  for (let i = 0; i < 13; i++) {
    const a = (i / 13) * Math.PI * 2;
    const petal = ball(
      0.155,
      toon(i % 2 === 0 ? MAT.petal : MAT.petalDark),
      0.02,
      Math.sin(a) * 0.3,
      Math.cos(a) * 0.3,
      0.34,
      1.15,
      0.62,
    );
    petal.rotation.x = -a;
    head.add(petal);
  }

  const face = tubeX(0.21, 0.235, 0.14, toon(MAT.seed), 0.13, 0, 0);
  head.add(face);
  head.add(tubeX(0.145, 0.155, 0.04, toon(MAT.seedDark), 0.21, 0, 0));
  head.add(eye(0.235, 0.075, 0.085, 0.062));
  head.add(eye(0.235, 0.075, -0.085, 0.062));
  head.add(smile(0.225, -0.055, 0, 0.075, toon(MAT.seedDark)));
  for (const s of [-1, 1]) {
    head.add(ball(0.045, toon(MAT.petalDark), 0.2, -0.03, s * 0.15, 1, 0.6, 1));
  }
  g.add(head);
  applyInk(g);
  return g;
}

function buildShooter(pale: boolean, barrels: number): THREE.Group {
  const g = new THREE.Group();
  stemAndLeaves(g, 0.82);

  const body = toon(pale ? MAT.snow : MAT.pea);
  const bodyDark = toon(pale ? MAT.snowDark : MAT.peaDark);
  const head = new THREE.Group();
  head.position.set(0.02, 1.0, 0);

  head.add(ball(0.31, body, 0, 0, 0, 1.08, 1, 0.96));
  // a little sprout on the crown: the signature of a peashooter
  head.add(capsuleX(0.022, 0.13, toon(MAT.stem), -0.06, 0.26, 0).rotateZ(Math.PI / 2));
  head.add(ball(0.1, toon(MAT.leaf), -0.02, 0.36, 0, 1.2, 0.5, 1));

  for (let i = 0; i < barrels; i++) {
    const y = barrels === 1 ? 0.02 : i === 0 ? -0.09 : 0.13;
    head.add(tubeX(0.115, 0.155, 0.3, body, 0.34, y, 0));
    head.add(tubeX(0.15, 0.15, 0.05, bodyDark, 0.49, y, 0));
    const hole = tubeX(0.085, 0.085, 0.02, toon(MAT.mouth), 0.51, y, 0);
    hole.userData.noInk = true;
    head.add(hole);
  }

  head.add(eye(0.19, 0.13, 0.15, 0.07));
  head.add(eye(0.19, 0.13, -0.13, 0.06));
  if (pale) {
    for (const s of [-1, 1]) head.add(cone(0.06, 0.16, toon(0xffffff), -0.02, 0.3, s * 0.14).rotateZ(-0.3));
  }
  g.add(head);
  applyInk(g);
  return g;
}

function buildNut(tall: boolean): THREE.Group {
  const g = new THREE.Group();
  const height = tall ? 1.55 : 1.0;
  const r = tall ? 0.35 : 0.37;

  const body = ball(r, toon(MAT.nut), 0, height * 0.5 + 0.05, 0, 1.04, (height / r) * 0.42, 0.98);
  g.add(body);
  g.add(ball(r * 0.42, toon(MAT.nutDark), -0.04, height + 0.06, 0, 1, 0.55, 1));

  // worried brows + eyes + a wobbly mouth
  for (const s of [-1, 1]) {
    const brow = box(0.13, 0.035, 0.03, toon(MAT.nutDark), r * 0.78, height * 0.5 + 0.28, s * 0.15);
    brow.rotation.z = s * 0.28;
    g.add(brow);
  }
  g.add(eye(r * 0.8, height * 0.5 + 0.16, 0.13, 0.062));
  g.add(eye(r * 0.8, height * 0.5 + 0.16, -0.13, 0.062));
  g.add(box(0.05, 0.05, 0.2, toon(MAT.nutDark), r * 0.86, height * 0.5 - 0.03, 0));

  // shell texture: a few darker creases
  for (const [y, z] of [
    [height * 0.75, 0.18],
    [height * 0.3, -0.16],
  ] as const) {
    const crease = box(0.03, 0.16, 0.03, toon(MAT.nutDark), r * 0.9, y, z);
    crease.rotation.x = 0.4;
    crease.userData.noInk = true;
    g.add(crease);
  }
  applyInk(g);
  return g;
}

function buildCherry(): THREE.Group {
  const g = new THREE.Group();
  const spots: readonly (readonly [number, number, number])[] = [
    [0.1, 0.3, 0.15],
    [-0.02, 0.25, -0.17],
  ];
  for (const [dx, r, dz] of spots) {
    g.add(ball(r, toon(MAT.cherry), dx, r + 0.05, dz));
    const shine = ball(r * 0.3, toon(0xffffff), dx + 0.08, r * 1.5, dz + 0.06, 1, 1.2, 1);
    shine.userData.noInk = true;
    g.add(shine);
    g.add(eye(dx + r * 0.62, r + 0.15, dz + 0.1, 0.045));
    g.add(eye(dx + r * 0.62, r + 0.15, dz - 0.1, 0.045));
    const brow = box(0.09, 0.025, 0.025, toon(MAT.cherryDark), dx + r * 0.6, r + 0.28, dz);
    brow.rotation.z = -0.35;
    g.add(brow);
  }
  // stems joining above the fruit
  const stemL = capsuleX(0.022, 0.26, toon(MAT.stem), 0.06, 0.62, 0.12);
  stemL.rotation.set(0.25, 0, 0.5);
  const stemR = capsuleX(0.022, 0.24, toon(MAT.stem), 0.06, 0.6, -0.12);
  stemR.rotation.set(-0.25, 0, 0.55);
  g.add(stemL, stemR);
  g.add(ball(0.12, toon(MAT.leaf), 0.08, 0.8, 0, 1.1, 0.45, 1));
  applyInk(g);
  return g;
}

function buildPotatoMine(): THREE.Group {
  const g = new THREE.Group();
  g.add(ball(0.4, toon(MAT.potato), 0, 0.13, 0, 1.24, 0.52, 1.08));
  for (const [x, z] of [
    [0.14, 0.16],
    [-0.16, -0.13],
    [0.02, -0.22],
  ] as const) {
    g.add(ball(0.06, toon(MAT.potatoDark), x, 0.24, z, 1, 0.6, 1));
  }
  g.add(eye(0.3, 0.2, 0.13, 0.055));
  g.add(eye(0.3, 0.2, -0.13, 0.055));
  g.add(box(0.09, 0.03, 0.18, toon(MAT.mouth), 0.32, 0.09, 0));
  // fuse + bulb
  const fuse = capsuleX(0.018, 0.16, toon(0x4a4038), 0.02, 0.32, 0);
  fuse.rotation.z = Math.PI / 2;
  g.add(fuse);
  g.add(ball(0.055, toon(0xe8452f), 0.02, 0.42, 0));
  // dirt collar
  const ring = new THREE.Mesh(new THREE.TorusGeometry(0.4, 0.055, 6, 20), toon(0x6f4a1e));
  ring.rotation.x = Math.PI / 2;
  ring.position.y = 0.03;
  ring.castShadow = true;
  g.add(ring);
  applyInk(g);
  return g;
}

function buildThreepeater(): THREE.Group {
  const g = new THREE.Group();
  stemAndLeaves(g, 0.72);
  const heads: readonly (readonly [number, number, number])[] = [
    [0.04, 1.06, 0],
    [-0.12, 0.86, 0.22],
    [-0.12, 0.86, -0.22],
  ];
  heads.forEach(([dx, y, dz], i) => {
    const head = new THREE.Group();
    head.position.set(dx, y, dz);
    head.rotation.z = i === 0 ? 0 : -0.1;
    head.add(ball(0.22, toon(MAT.pea), 0, 0, 0, 1.12, 1, 0.96));
    head.add(tubeX(0.085, 0.115, 0.24, toon(MAT.pea), 0.25, 0, 0));
    head.add(tubeX(0.11, 0.11, 0.04, toon(MAT.peaDark), 0.36, 0, 0));
    head.add(eye(0.15, 0.1, 0.1, 0.05));
    head.add(eye(0.15, 0.1, -0.1, 0.05));
    g.add(head);
  });
  applyInk(g);
  return g;
}

function buildChomper(): THREE.Group {
  const g = new THREE.Group();
  const stem = capsuleX(0.075, 0.42, toon(MAT.stem), -0.06, 0.3, 0);
  stem.rotation.z = Math.PI / 2 + 0.14;
  g.add(stem);
  g.add(ball(0.16, toon(MAT.leaf), -0.24, 0.12, 0, 1.3, 0.28, 0.9));

  const head = new THREE.Group();
  head.position.set(0.06, 0.76, 0);
  head.rotation.z = -0.1;

  // upper jaw and lower jaw, open to show a dark throat
  const upper = ball(0.32, toon(MAT.chomper), 0.06, 0.12, 0, 1.25, 0.72, 1);
  const lower = ball(0.3, toon(MAT.chomper), 0.08, -0.16, 0, 1.2, 0.6, 1);
  head.add(upper, lower);
  const throat = ball(0.2, toon(MAT.mouth), 0.24, -0.02, 0, 1.1, 0.62, 0.86);
  throat.userData.noInk = true;
  head.add(throat);
  for (let i = -1; i <= 1; i++) {
    head.add(cone(0.045, 0.11, toon(MAT.teeth), 0.44, 0.14, i * 0.13).rotateZ(Math.PI));
    head.add(cone(0.04, 0.1, toon(MAT.teeth), 0.44, -0.12, i * 0.12));
  }
  // spots
  for (const [x, y, z] of [
    [-0.02, 0.26, 0.12],
    [-0.16, 0.18, -0.1],
  ] as const) {
    head.add(ball(0.055, toon(MAT.chomperLight), x, y, z, 1, 0.7, 1));
  }
  head.add(eye(0.18, 0.3, 0.15, 0.05));
  head.add(eye(0.18, 0.3, -0.15, 0.05));
  g.add(head);
  applyInk(g);
  return g;
}

function buildLilypad(): THREE.Group {
  const g = new THREE.Group();
  const pad = new THREE.Mesh(
    new THREE.CylinderGeometry(0.64, 0.6, 0.07, 26, 1, false, 0.38, Math.PI * 1.88),
    toon(0x53a341),
  );
  pad.position.y = 0.035;
  pad.receiveShadow = true;
  pad.castShadow = true;
  g.add(pad);
  // veins
  for (let i = 0; i < 7; i++) {
    const a = (i / 7) * Math.PI * 1.8 + 0.5;
    const vein = box(0.5, 0.012, 0.02, toon(0x3d8231), 0, 0.07, 0);
    vein.position.set(Math.cos(a) * 0.27, 0.072, Math.sin(a) * 0.27);
    vein.rotation.y = -a;
    vein.userData.noInk = true;
    g.add(vein);
  }
  const flower = new THREE.Group();
  flower.position.set(-0.18, 0.08, 0.16);
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * Math.PI * 2;
    const petal = ball(0.085, toon(0xf2a0c4), Math.cos(a) * 0.08, 0.05, Math.sin(a) * 0.08, 1, 0.6, 1);
    petal.rotation.y = -a;
    flower.add(petal);
  }
  flower.add(ball(0.05, toon(0xffe066), 0, 0.09, 0));
  g.add(flower);
  applyInk(g);
  return g;
}

export function buildPlantModel(kind: PlantKind): THREE.Group {
  const hit = cache.get(kind);
  if (hit) return hit.clone(true);
  let g: THREE.Group;
  switch (kind) {
    case 'sunflower':
      g = buildSunflower();
      break;
    case 'peashooter':
      g = buildShooter(false, 1);
      break;
    case 'snowpea':
      g = buildShooter(true, 1);
      break;
    case 'repeater':
      g = buildShooter(false, 2);
      break;
    case 'wallnut':
      g = buildNut(false);
      break;
    case 'tallnut':
      g = buildNut(true);
      break;
    case 'cherrybomb':
      g = buildCherry();
      break;
    case 'potatomine':
      g = buildPotatoMine();
      break;
    case 'threepeater':
      g = buildThreepeater();
      break;
    case 'chomper':
      g = buildChomper();
      break;
    case 'lilypad':
      g = buildLilypad();
      break;
  }
  g.add(shadowBlob(kind === 'lilypad' ? 0.66 : 0.46));
  cache.set(kind, g);
  return g.clone(true);
}

export interface ZombieModel {
  group: THREE.Group;
  legL: THREE.Object3D;
  legR: THREE.Object3D;
  armL: THREE.Object3D;
  armR: THREE.Object3D;
  head: THREE.Object3D;
}

export function buildZombieModel(kind: ZombieKind): ZombieModel {
  const group = new THREE.Group();
  const skin = toon(MAT.skin);
  const skinDark = toon(MAT.skinDark);
  const shirt = toon(kind === 'flag' ? 0x9c4350 : MAT.shirt);
  const shirtDark = toon(kind === 'flag' ? 0x6f2c37 : MAT.shirtDark);

  const hipY = 0.86;

  const makeLeg = (z: number): THREE.Group => {
    const leg = new THREE.Group();
    leg.position.set(0, hipY, z);
    const thigh = capsuleX(0.095, 0.56, toon(MAT.pants), 0, -0.34, 0);
    thigh.rotation.z = Math.PI / 2;
    leg.add(thigh);
    leg.add(box(0.16, 0.29, 0.19, toon(MAT.pants), 0, -0.14, 0));
    const shoe = box(0.28, 0.11, 0.2, toon(MAT.shoe), 0.06, -0.66, 0);
    leg.add(shoe);
    return leg;
  };
  const legL = makeLeg(0.14);
  const legR = makeLeg(-0.14);
  group.add(legL, legR);

  // hunched torso: rounded, wider at the shoulders
  group.add(ball(0.29, shirt, -0.01, hipY + 0.3, 0, 0.95, 1.12, 0.92));
  group.add(ball(0.24, shirtDark, -0.01, hipY + 0.06, 0, 1.02, 0.5, 0.98));
  // ragged shirt hem + tie
  group.add(box(0.1, 0.34, 0.07, shirtDark, 0.25, hipY + 0.3, 0));
  const collar = box(0.14, 0.1, 0.24, toon(0xd8d2c0), 0.16, hipY + 0.54, 0);
  collar.userData.noInk = true;
  group.add(collar);

  const makeArm = (z: number): THREE.Group => {
    const arm = new THREE.Group();
    arm.position.set(0.04, hipY + 0.5, z);
    const upper = capsuleX(0.075, 0.3, shirt, 0.2, 0, 0);
    const fore = capsuleX(0.068, 0.24, skin, 0.5, -0.02, 0);
    arm.add(upper, fore);
    arm.add(ball(0.095, skin, 0.66, -0.03, 0));
    return arm;
  };
  const armL = makeArm(0.25);
  const armR = makeArm(-0.25);
  group.add(armL, armR);

  const head = new THREE.Group();
  head.position.set(0.03, hipY + 0.72, 0);
  head.add(ball(0.23, skin, 0, 0, 0, 1.05, 1.1, 0.95));
  head.add(ball(0.16, skinDark, -0.06, -0.16, 0, 1, 0.7, 1));
  head.add(eye(0.2, 0.05, 0.1, 0.062));
  head.add(eye(0.2, 0.05, -0.09, 0.055));
  // heavy brows + stitched mouth
  const browL = box(0.05, 0.035, 0.13, skinDark, 0.19, 0.13, 0.1);
  browL.rotation.x = -0.25;
  const browR = box(0.05, 0.035, 0.13, skinDark, 0.19, 0.13, -0.09);
  browR.rotation.x = 0.25;
  head.add(browL, browR);
  head.add(box(0.06, 0.075, 0.17, toon(0x3a241c), 0.2, -0.13, 0));
  head.add(box(0.03, 0.07, 0.03, toon(MAT.teeth), 0.23, -0.12, 0.04));
  head.add(box(0.03, 0.07, 0.03, toon(MAT.teeth), 0.23, -0.12, -0.04));
  // hair tufts
  for (const [x, y, z] of [
    [-0.1, 0.19, 0.06],
    [-0.02, 0.22, -0.09],
    [-0.16, 0.12, -0.02],
  ] as const) {
    head.add(ball(0.07, toon(MAT.hair), x, y, z, 1.2, 0.7, 1));
  }
  group.add(head);

  if (kind === 'cone') {
    const c = cone(0.22, 0.46, toon(MAT.cone), 0.02, hipY + 1.02, 0);
    c.rotation.z = -0.08;
    group.add(c);
    const band = tubeX(0.2, 0.185, 0.06, toon(MAT.coneDark), 0.02, hipY + 0.86, 0);
    band.rotation.z = 0;
    band.scale.set(1, 1, 1);
    band.rotation.x = Math.PI / 2;
    band.rotation.z = 0;
    group.add(band);
  } else if (kind === 'bucket') {
    const b = new THREE.Mesh(new THREE.CylinderGeometry(0.23, 0.2, 0.36, 18), toon(MAT.bucket));
    b.position.set(0.02, hipY + 1.02, 0);
    b.rotation.z = -0.06;
    b.castShadow = true;
    group.add(b);
    const rim = new THREE.Mesh(new THREE.TorusGeometry(0.23, 0.028, 6, 20), toon(MAT.bucketDark));
    rim.rotation.x = Math.PI / 2;
    rim.position.set(0.02, hipY + 1.19, 0);
    group.add(rim);
    const dent = box(0.1, 0.1, 0.02, toon(MAT.bucketDark), 0.12, hipY + 1.05, 0.21);
    dent.userData.noInk = true;
    group.add(dent);
  } else if (kind === 'flag') {
    const pole = capsuleX(0.025, 1.0, toon(MAT.pole), -0.34, hipY + 0.9, 0.28);
    pole.rotation.z = Math.PI / 2;
    group.add(pole);
    group.add(box(0.44, 0.3, 0.03, toon(MAT.flag), -0.1, hipY + 1.28, 0.28));
  }

  applyInk(group, 0.026);
  group.add(shadowBlob(0.5));
  return { group, legL, legR, armL, armR, head };
}
