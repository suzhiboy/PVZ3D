/**
 * The house: two storeys, a gable roof, a furnished ground floor and an
 * upstairs bedroom. Exterior walls are assembled from solid segments around
 * door/window openings, and every solid segment registers collision.
 */
import * as THREE from 'three';
import type { Collision } from '../core/collision.ts';
import { getAssets, PALETTE, solid, textured, uvScale } from '../core/materials.ts';
import { HOUSE } from './layout.ts';
import { boxAt, cylinderAt, planeAt, sphereAt } from './parts.ts';

type Opening = { a0: number; a1: number; b0: number; b1: number; kind: 'door' | 'window' };

interface WallSpec {
  along: 'x' | 'z';
  a0: number;
  a1: number;
  /** Centre of the wall thickness along the other axis. */
  fixed: number;
  thickness: number;
  y0: number;
  y1: number;
  material: THREE.Material;
  openings?: Opening[];
}

export interface HouseResult {
  update(dt: number): void;
  lights: THREE.Light[];
}

const WALL_UV = 2.6;

export function buildHouse(scene: THREE.Scene, col: Collision): HouseResult {
  const assets = getAssets();
  const siding = textured(assets.siding, 0xf7e7c8);
  const interior = textured(assets.wallpaper);
  const trim = solid(PALETTE.trim);
  const trimDark = solid(PALETTE.trimShadow, { side: THREE.DoubleSide });
  const brick = textured(assets.brick);
  const roofMat = textured(assets.shingle);
  const glass = solid(PALETTE.glass, {
    transparent: true,
    opacity: 0.28,
    depthWrite: false,
    standard: true,
    roughness: 0.08,
    metalness: 0.1,
  });
  const woodFloor = textured(assets.wood, 0xc9a678);
  const stairWood = solid(0x8a6a48);

  const wallMeshes: THREE.Mesh[] = [];
  void wallMeshes;

  /** Wall material mesh with world-scaled UVs. */
  const wallBox = (
    x0: number,
    x1: number,
    z0: number,
    z1: number,
    y0: number,
    y1: number,
    material: THREE.Material,
    collide = true,
  ): THREE.Mesh => {
    const w = Math.max(0.02, x1 - x0);
    const h = Math.max(0.02, y1 - y0);
    const d = Math.max(0.02, z1 - z0);
    const g = new THREE.BoxGeometry(w, h, d);
    uvScale(g, Math.max(w, d) / WALL_UV, h / WALL_UV);
    const m = new THREE.Mesh(g, material);
    m.position.set((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2);
    m.castShadow = true;
    m.receiveShadow = true;
    scene.add(m);
    wallMeshes.push(m);
    if (collide) col.addWall(x0, x1, z0, z1, y0, y1);
    return m;
  };

  const spec = (s: WallSpec): void => {
    const t = s.thickness / 2;
    const seg = (a0: number, a1: number, b0: number, b1: number): void => {
      if (a1 - a0 < 0.001 || b1 - b0 < 0.001) return;
      if (s.along === 'x') wallBox(a0, a1, s.fixed - t, s.fixed + t, b0, b1, s.material);
      else wallBox(s.fixed - t, s.fixed + t, a0, a1, b0, b1, s.material);
    };

    const ops = [...(s.openings ?? [])].sort((a, b) => a.a0 - b.a0);
    let cursor = s.a0;
    for (const op of ops) {
      const a0 = Math.max(s.a0, op.a0);
      const a1 = Math.min(s.a1, op.a1);
      if (a0 > cursor) seg(cursor, a0, s.y0, s.y1);
      if (op.b0 > s.y0) seg(a0, a1, s.y0, op.b0);
      if (op.b1 < s.y1) seg(a0, a1, op.b1, s.y1);
      cursor = Math.max(cursor, a1);

      // frame + glass
      const fz = s.fixed;
      if (op.kind === 'window') {
        const outerA = { a0: a0 - 0.06, a1: a1 + 0.06 };
        // glass plane
        if (s.along === 'x') {
          const g = new THREE.Mesh(new THREE.PlaneGeometry(a1 - a0, op.b1 - op.b0), glass);
          g.position.set((a0 + a1) / 2, (op.b0 + op.b1) / 2, fz);
          scene.add(g);
          const g2 = g.clone();
          g2.rotation.y = Math.PI;
          scene.add(g2);
          col.addWall(a0, a1, fz - t, fz + t, op.b0, op.b1);
        } else {
          const g = new THREE.Mesh(new THREE.PlaneGeometry(a1 - a0, op.b1 - op.b0), glass);
          g.rotation.y = Math.PI / 2;
          g.position.set(fz, (op.b0 + op.b1) / 2, (a0 + a1) / 2);
          scene.add(g);
          const g2 = g.clone();
          g2.rotation.y = -Math.PI / 2;
          scene.add(g2);
          col.addWall(fz - t, fz + t, a0, a1, op.b0, op.b1);
        }
        // frame pieces
        const frameBox = (aa0: number, aa1: number, bb0: number, bb1: number): void => {
          if (s.along === 'x') {
            wallBox(aa0, aa1, fz - t - 0.03, fz + t + 0.03, bb0, bb1, trim, false);
          } else {
            wallBox(fz - t - 0.03, fz + t + 0.03, aa0, aa1, bb0, bb1, trim, false);
          }
        };
        frameBox(outerA.a0, a0, op.b0, op.b1);
        frameBox(a1, outerA.a1, op.b0, op.b1);
        frameBox(a0, a1, op.b0 - 0.09, op.b0);
        frameBox(a0, a1, op.b1, op.b1 + 0.09);
        frameBox(a0, a1, (op.b0 + op.b1) / 2 - 0.035, (op.b0 + op.b1) / 2 + 0.035);
        // vertical muntin: with the check rail this splits the sash into the
        // classic 2-over-2 panes and stops the glass reading as a black hole
        const muntinX = (a0 + a1) / 2;
        frameBox(muntinX - 0.028, muntinX + 0.028, op.b0, (op.b0 + op.b1) / 2);
        frameBox(muntinX - 0.028, muntinX + 0.028, (op.b0 + op.b1) / 2, op.b1);
        // sill
        frameBox(a0 - 0.12, a1 + 0.12, op.b0 - 0.12, op.b0 - 0.02);
      } else {
        // doorway casing
        const casing = (aa0: number, aa1: number, bb0: number, bb1: number): void => {
          if (s.along === 'x') wallBox(aa0, aa1, fz - t - 0.04, fz + t + 0.04, bb0, bb1, trim, false);
          else wallBox(fz - t - 0.04, fz + t + 0.04, aa0, aa1, bb0, bb1, trim, false);
        };
        casing(a0 - 0.1, a0, op.b0, op.b1 + 0.1);
        casing(a1, a1 + 0.1, op.b0, op.b1 + 0.1);
        casing(a0 - 0.1, a1 + 0.1, op.b1, op.b1 + 0.12);
        // threshold
        if (s.along === 'x') col.addFloor(a0, a1, fz - t, fz + t, HOUSE.floorY, 'threshold');
        else col.addFloor(fz - t, fz + t, a0, a1, HOUSE.floorY, 'threshold');
      }
    }
    if (cursor < s.a1) seg(cursor, s.a1, s.y0, s.y1);
  };

  // -------------------------------------------------------------------------
  // shell
  // -------------------------------------------------------------------------
  const wallT = HOUSE.wallT;
  const eastFixed = HOUSE.x1 - wallT / 2;
  const westFixed = HOUSE.x0 + wallT / 2;
  const northFixed = HOUSE.z0 + wallT / 2;
  const southFixed = HOUSE.z1 - wallT / 2;
  const slabY = HOUSE.slabY;
  const upperY = HOUSE.upperY;
  const eaveY = upperY + 2.55;

  const fd = HOUSE.frontDoorZ;
  const bd = HOUSE.backDoorZ;

  const groundOpenEast: Opening[] = [
    { a0: fd - 0.62, a1: fd + 0.62, b0: 0, b1: 2.5, kind: 'door' },
    { a0: -4.9, a1: -2.5, b0: 1.45, b1: 2.7, kind: 'window' },
  ];
  const upperOpenEast: Opening[] = [
    { a0: -4.9, a1: -2.5, b0: upperY + 0.80, b1: upperY + 1.90, kind: 'window' },
    { a0: 2.1, a1: 4.2, b0: upperY + 0.80, b1: upperY + 1.90, kind: 'window' },
  ];
  const groundOpenWest: Opening[] = [
    { a0: bd - 0.6, a1: bd + 0.6, b0: 0, b1: 2.5, kind: 'door' },
    { a0: -3.4, a1: -1.4, b0: 1.45, b1: 2.7, kind: 'window' },
  ];
  const upperOpenWest: Opening[] = [
    { a0: -3.4, a1: -1.4, b0: upperY + 0.80, b1: upperY + 1.90, kind: 'window' },
    { a0: 2.4, a1: 4.4, b0: upperY + 0.80, b1: upperY + 1.90, kind: 'window' },
  ];
  const groundOpenNorth: Opening[] = [
    { a0: -14.2, a1: -11.6, b0: 1.6, b1: 2.7, kind: 'window' },
  ];
  const upperOpenNorth: Opening[] = [
    { a0: -13.4, a1: -10.8, b0: upperY + 0.80, b1: upperY + 1.90, kind: 'window' },
  ];
  const groundOpenSouth: Opening[] = [
    { a0: -16.4, a1: -14.2, b0: 1.45, b1: 2.7, kind: 'window' },
  ];
  const upperOpenSouth: Opening[] = [
    { a0: -12.6, a1: -10.4, b0: upperY + 0.80, b1: upperY + 1.90, kind: 'window' },
  ];

  // foundation skirt
  wallBox(HOUSE.x0 - 0.05, HOUSE.x1 + 0.05, HOUSE.z0 - 0.05, HOUSE.z1 + 0.05, -0.35, 0.44, brick, false);

  // ground floor exterior
  spec({ along: 'z', a0: HOUSE.z0, a1: HOUSE.z1, fixed: eastFixed, thickness: wallT, y0: 0.0, y1: slabY, material: siding, openings: groundOpenEast });
  spec({ along: 'z', a0: HOUSE.z0, a1: HOUSE.z1, fixed: westFixed, thickness: wallT, y0: 0.0, y1: slabY, material: siding, openings: groundOpenWest });
  spec({ along: 'x', a0: HOUSE.i0, a1: HOUSE.i1, fixed: northFixed, thickness: wallT, y0: 0.0, y1: slabY, material: siding, openings: groundOpenNorth });
  spec({ along: 'x', a0: HOUSE.i0, a1: HOUSE.i1, fixed: southFixed, thickness: wallT, y0: 0.0, y1: slabY, material: siding, openings: groundOpenSouth });

  // upper floor exterior
  spec({ along: 'z', a0: HOUSE.z0, a1: HOUSE.z1, fixed: eastFixed, thickness: wallT, y0: slabY, y1: eaveY, material: siding, openings: upperOpenEast });
  spec({ along: 'z', a0: HOUSE.z0, a1: HOUSE.z1, fixed: westFixed, thickness: wallT, y0: slabY, y1: eaveY, material: siding, openings: upperOpenWest });
  spec({ along: 'x', a0: HOUSE.i0, a1: HOUSE.i1, fixed: northFixed, thickness: wallT, y0: slabY, y1: eaveY, material: siding, openings: upperOpenNorth });
  spec({ along: 'x', a0: HOUSE.i0, a1: HOUSE.i1, fixed: southFixed, thickness: wallT, y0: slabY, y1: eaveY, material: siding, openings: upperOpenSouth });

  // -------------------------------------------------------------------------
  // floors and slab
  // -------------------------------------------------------------------------
  const floorGeo = new THREE.PlaneGeometry(HOUSE.i1 - HOUSE.i0, HOUSE.j1 - HOUSE.j0);
  floorGeo.rotateX(-Math.PI / 2);
  uvScale(floorGeo, (HOUSE.i1 - HOUSE.i0) / 2.6, (HOUSE.j1 - HOUSE.j0) / 2.6);
  const floorMesh = new THREE.Mesh(floorGeo, woodFloor);
  floorMesh.position.set((HOUSE.i0 + HOUSE.i1) / 2, HOUSE.floorY, (HOUSE.j0 + HOUSE.j1) / 2);
  floorMesh.receiveShadow = true;
  scene.add(floorMesh);
  col.addFloor(HOUSE.i0, HOUSE.i1, HOUSE.j0, HOUSE.j1, HOUSE.floorY, 'house-floor');

  // upper slab with a stairwell hole
  const s = HOUSE.stairs;
  const slabTop = upperY;
  const slabBottom = slabY;
  const slabPiece = (x0: number, x1: number, z0: number, z1: number): void => {
    const m = wallBox(x0, x1, z0, z1, slabBottom, slabTop, trim, false);
    void m;
    col.addFloor(x0, x1, z0, z1, slabTop, 'upper-floor');
  };
  slabPiece(HOUSE.i0, HOUSE.i1, s.z1, HOUSE.j1);
  slabPiece(HOUSE.i0, s.x0, HOUSE.j0, s.z1);
  slabPiece(s.x1, HOUSE.i1, HOUSE.j0, s.z1);
  // fascia band around the storey break
  wallBox(HOUSE.x0 - 0.08, HOUSE.x1 + 0.08, HOUSE.z0 - 0.08, HOUSE.z0 + 0.02, slabY - 0.12, slabY + 0.06, trim, false);
  wallBox(HOUSE.x0 - 0.08, HOUSE.x1 + 0.08, HOUSE.z1 - 0.02, HOUSE.z1 + 0.08, slabY - 0.12, slabY + 0.06, trim, false);
  wallBox(HOUSE.x0 - 0.08, HOUSE.x0 + 0.02, HOUSE.z0, HOUSE.z1, slabY - 0.12, slabY + 0.06, trim, false);
  wallBox(HOUSE.x1 - 0.02, HOUSE.x1 + 0.08, HOUSE.z0, HOUSE.z1, slabY - 0.12, slabY + 0.06, trim, false);

  // upper ceiling
  const ceil = planeAt(HOUSE.i1 - HOUSE.i0, HOUSE.j1 - HOUSE.j0, trim, (HOUSE.i0 + HOUSE.i1) / 2, eaveY - 0.02, (HOUSE.j0 + HOUSE.j1) / 2);
  ceil.rotation.x = Math.PI;
  scene.add(ceil);

  // -------------------------------------------------------------------------
  // roof
  // -------------------------------------------------------------------------
  const cx = (HOUSE.x0 + HOUSE.x1) / 2;
  const ovh = 0.62;
  const hz0 = HOUSE.z0 - ovh;
  const hz1 = HOUSE.z1 + ovh;
  const halfW = (HOUSE.x1 - HOUSE.x0) / 2 + ovh;
  const rise = 3.1;
  const slope = Math.hypot(halfW, rise);
  const ang = Math.atan2(rise, halfW);
  const roofMidZ = (hz0 + hz1) / 2;

  const roofPiece = (dir: 1 | -1): void => {
    const g = new THREE.BoxGeometry(slope, 0.22, hz1 - hz0);
    uvScale(g, slope / 2.4, (hz1 - hz0) / 2.4);
    const m = new THREE.Mesh(g, roofMat);
    m.rotation.z = dir === 1 ? -ang : ang;
    const ex = dir === 1 ? HOUSE.x1 + ovh : HOUSE.x0 - ovh;
    m.position.set((ex + cx) / 2, (eaveY + eaveY + rise) / 2, roofMidZ);
    m.castShadow = true;
    m.receiveShadow = true;
    scene.add(m);
    // white fascia board tucked under the eave so the roof edge reads crisply
    scene.add(boxAt(0.12, 0.26, hz1 - hz0, trim, ex - dir * 0.02, eaveY - 0.22, roofMidZ));
    // soffit panel under the overhang
    const soffit = planeAt(0.62, hz1 - hz0, trim, ex - dir * 0.33, eaveY - 0.06, roofMidZ);
    scene.add(soffit);
  };
  roofPiece(1);
  roofPiece(-1);
  // gutters: a half-round run hanging off each eave plus downspouts at the
  // corners — cheap detail that reads as "someone built this house"
  const gutterMat = solid(PALETTE.metal, { standard: true, roughness: 0.45, metalness: 0.5 });
  for (const dir of [1, -1] as const) {
    const ex = dir === 1 ? HOUSE.x1 + ovh - 0.1 : HOUSE.x0 - ovh + 0.1;
    const run = boxAt(0.15, 0.13, hz1 - hz0, gutterMat, ex, eaveY - 0.34, roofMidZ);
    run.castShadow = false;
    scene.add(run);
    for (const dz of [hz0 + 0.35, hz1 - 0.35]) {
      const spout = cylinderAt(0.055, 0.055, eaveY - 0.34, gutterMat, ex, 0, dz, 8);
      spout.castShadow = false;
      scene.add(spout);
    }
  }
  // ridge cap
  const ridge = new THREE.Mesh(new THREE.BoxGeometry(0.4, 0.24, hz1 - hz0), solid(PALETTE.roof, { standard: true, roughness: 0.7 }));
  ridge.position.set(cx, eaveY + rise + 0.05, roofMidZ);
  ridge.castShadow = true;
  scene.add(ridge);

  // gable ends
  const gableShape = new THREE.Shape();
  gableShape.moveTo(HOUSE.x0 - 0.02, eaveY);
  gableShape.lineTo(HOUSE.x1 + 0.02, eaveY);
  gableShape.lineTo(cx, eaveY + rise);
  gableShape.closePath();
  const gableGeo = new THREE.ShapeGeometry(gableShape);
  uvScale(gableGeo, 1 / WALL_UV, 1 / WALL_UV);
  for (const z of [HOUSE.z0 + 0.02, HOUSE.z1 - 0.02]) {
    const gm = new THREE.Mesh(gableGeo, siding);
    gm.position.z = z;
    gm.castShadow = true;
    scene.add(gm);
  }

  // chimney
  wallBox(cx + 1.6, cx + 2.6, -1.6, -0.6, eaveY - 1.2, eaveY + rise + 1.15, brick, false);
  const cap = boxAt(1.2, 0.14, 1.2, solid(0x9c9384), cx + 2.1, eaveY + rise + 1.15, -1.1);
  scene.add(cap);

  // -------------------------------------------------------------------------
  // front stoop, porch roof and back deck
  // -------------------------------------------------------------------------
  const porch = HOUSE.porch;
  const porchSlab = boxAt(porch.x1 - porch.x0, HOUSE.floorY + 0.1, porch.z1 - porch.z0, solid(0xd9d1c0), (porch.x0 + porch.x1) / 2, -0.1, (porch.z0 + porch.z1) / 2);
  scene.add(porchSlab);
  col.addFloor(porch.x0, porch.x1, porch.z0, porch.z1, HOUSE.floorY, 'porch');
  // deck boards on top
  const porchTopGeo = new THREE.PlaneGeometry(porch.x1 - porch.x0, porch.z1 - porch.z0);
  porchTopGeo.rotateX(-Math.PI / 2);
  uvScale(porchTopGeo, 1, 1);
  const porchTop = new THREE.Mesh(porchTopGeo, textured(assets.wood, 0xb9925f));
  porchTop.position.set((porch.x0 + porch.x1) / 2, HOUSE.floorY + 0.005, (porch.z0 + porch.z1) / 2);
  porchTop.receiveShadow = true;
  scene.add(porchTop);

  // stoop steps down to the lawn
  for (let i = 0; i < 3; i++) {
    const top = HOUSE.floorY - (i + 1) * 0.15;
    const x1 = porch.x1 + (i + 1) * 0.24;
    const step = boxAt(0.24, top + 0.1, porch.z1 - porch.z0 - 0.2, solid(PALETTE.stone), x1 - 0.12, -0.1, (porch.z0 + porch.z1) / 2);
    scene.add(step);
    col.addFloor(x1 - 0.24, x1, porch.z0 + 0.1, porch.z1 - 0.1, top, 'stoop');
  }

  // porch gable roof (a small cross gable facing the lawn) + posts
  const pgEave = 3.15;
  const pgApex = pgEave + 1.02;
  const pzMid = (porch.z0 + porch.z1) / 2;
  const phalf = (porch.z1 - porch.z0) / 2 + 0.34;
  const pRise = pgApex - pgEave;
  const pSlope = Math.hypot(phalf, pRise);
  const pAng = Math.atan2(pRise, phalf);
  const px0 = -9.9;
  const px1 = porch.x1 + 0.06;
  for (const dir of [1, -1] as const) {
    const g = new THREE.BoxGeometry(px1 - px0, 0.18, pSlope);
    uvScale(g, (px1 - px0) / 2.4, pSlope / 2.4);
    const m = new THREE.Mesh(g, roofMat);
    m.rotation.x = dir * pAng;
    m.position.set((px0 + px1) / 2, (pgEave + pgApex) / 2, pzMid + (dir * phalf) / 2);
    m.castShadow = true;
    m.receiveShadow = true;
    scene.add(m);
  }
  scene.add(boxAt(px1 - px0, 0.2, 0.34, solid(PALETTE.roof, { standard: true, roughness: 0.7 }), (px0 + px1) / 2, pgApex - 0.08, pzMid));
  const tri = new THREE.Shape();
  tri.moveTo(-phalf, 0);
  tri.lineTo(phalf, 0);
  tri.lineTo(0, pRise);
  tri.closePath();
  const triGeo = new THREE.ShapeGeometry(tri);
  uvScale(triGeo, 1 / WALL_UV, 1 / WALL_UV);
  const triMesh = new THREE.Mesh(triGeo, siding);
  triMesh.rotation.y = Math.PI / 2;
  triMesh.position.set(px1, pgEave, pzMid);
  triMesh.castShadow = true;
  scene.add(triMesh);
  scene.add(boxAt(0.16, 0.2, phalf * 2, trim, px1 - 0.07, pgEave - 0.08, pzMid));
  for (const z of [porch.z0 + 0.12, porch.z1 - 0.12]) {
    scene.add(boxAt(0.12, 3.15 - HOUSE.floorY, 0.12, trim, porch.x1 - 0.18, HOUSE.floorY, z));
    col.addWall(porch.x1 - 0.24, porch.x1 - 0.12, z - 0.06, z + 0.06, HOUSE.floorY, 3.15);
  }
  // porch railing on the open sides
  for (const z of [porch.z0, porch.z1]) {
    scene.add(boxAt(porch.x1 - porch.x0, 0.09, 0.09, trim, (porch.x0 + porch.x1) / 2, HOUSE.floorY + 0.9, z));
    col.addWall(porch.x0, porch.x1, z - 0.06, z + 0.06, HOUSE.floorY, HOUSE.floorY + 1.0);
    for (let x = porch.x0 + 0.2; x < porch.x1 - 0.1; x += 0.4) {
      scene.add(boxAt(0.07, 0.9, 0.07, trim, x, HOUSE.floorY, z));
    }
  }

  // shutters + apron trim framing the lawn-facing (east) windows
  const shutterMat = solid(0x2f5d52);
  const eastWindows: readonly (readonly [number, number, number, number])[] = [
    [-4.9, -2.5, 1.45, 2.7],
    [-4.9, -2.5, upperY + 0.8, upperY + 1.9],
    [2.1, 4.2, upperY + 0.8, upperY + 1.9],
  ];
  for (const [za, zb, yb, yt] of eastWindows) {
    const h = yt - yb;
    for (const zc of [za - 0.3, zb + 0.3]) {
      scene.add(boxAt(0.09, h + 0.16, 0.5, shutterMat, HOUSE.x1 + 0.05, yb - 0.08, zc));
    }
  }

  // back deck
  const deck = HOUSE.deck;
  scene.add(boxAt(deck.x1 - deck.x0, HOUSE.floorY + 0.1, deck.z1 - deck.z0, solid(0xc4a878), (deck.x0 + deck.x1) / 2, -0.1, (deck.z0 + deck.z1) / 2));
  col.addFloor(deck.x0, deck.x1, deck.z0, deck.z1, HOUSE.floorY, 'deck');
  for (let i = 0; i < 3; i++) {
    const top = HOUSE.floorY - (i + 1) * 0.14;
    const x0 = deck.x0 - (i + 1) * 0.26;
    scene.add(boxAt(0.26, top + 0.1, deck.z1 - deck.z0 - 0.2, solid(PALETTE.stone), x0 + 0.13, -0.1, (deck.z0 + deck.z1) / 2));
    col.addFloor(x0, x0 + 0.26, deck.z0 + 0.1, deck.z1 - 0.1, top, 'deck-step');
  }

  // -------------------------------------------------------------------------
  // interior partition (kitchen divider)
  // -------------------------------------------------------------------------
  wallBox(HOUSE.i0, -10.6, 2.2 - 0.12, 2.2 + 0.12, HOUSE.floorY, slabY, interior);
  wallBox(HOUSE.i0, -10.6, 2.06, 2.34, HOUSE.floorY, HOUSE.floorY + 0.02, trimDark, false);

  // -------------------------------------------------------------------------
  // stairs
  // -------------------------------------------------------------------------
  const steps = 16;
  const riseStep = (upperY - HOUSE.floorY) / steps;
  const runStep = (s.x1 - s.x0) / steps;
  for (let i = 0; i < steps; i++) {
    const top = HOUSE.floorY + (i + 1) * riseStep;
    const x1 = s.x1 - i * runStep;
    const x0 = x1 - runStep;
    scene.add(boxAt(runStep + 0.02, top - HOUSE.floorY + 0.02, s.z1 - s.z0, stairWood, x1 - runStep / 2, HOUSE.floorY, (s.z0 + s.z1) / 2));
    void x0;
  }
  col.addRamp(s.x0, s.x1, s.z0, s.z1, upperY, HOUSE.floorY, 'x', 'stairs');
  // handrail on the room side of the flight
  const railLen = Math.hypot(s.x1 - s.x0, upperY - HOUSE.floorY);
  const railAngle = Math.atan2(upperY - HOUSE.floorY, s.x0 - s.x1);
  const rail = new THREE.Mesh(new THREE.BoxGeometry(railLen, 0.08, 0.08), trim);
  rail.position.set((s.x0 + s.x1) / 2, (HOUSE.floorY + upperY) / 2 + 0.95, s.z1 - 0.06);
  rail.rotation.z = railAngle;
  rail.castShadow = true;
  scene.add(rail);
  for (let i = 0; i <= 6; i++) {
    const t = i / 6;
    const x = s.x1 + (s.x0 - s.x1) * t;
    const y = HOUSE.floorY + (upperY - HOUSE.floorY) * t;
    scene.add(boxAt(0.06, 0.95, 0.06, trim, x, y, s.z1 - 0.06));
  }
  col.addWall(s.x0, s.x1, s.z1 - 0.12, s.z1, HOUSE.floorY, upperY + 1.0);

  // upper landing railing around the stairwell
  scene.add(boxAt(s.x1 - s.x0, 0.09, 0.09, trim, (s.x0 + s.x1) / 2, upperY + 0.95, s.z1));
  col.addWall(s.x0, s.x1, s.z1 - 0.1, s.z1 + 0.02, upperY, upperY + 1.05);
  scene.add(boxAt(0.09, 0.09, s.z1 - HOUSE.j0, trim, s.x1, upperY + 0.95, (HOUSE.j0 + s.z1) / 2));
  col.addWall(s.x1 - 0.02, s.x1 + 0.1, HOUSE.j0, s.z1, upperY, upperY + 1.05);
  for (let x = s.x0 + 0.15; x < s.x1; x += 0.45) {
    scene.add(boxAt(0.06, 0.95, 0.06, trim, x, upperY, s.z1));
  }

  // -------------------------------------------------------------------------
  // furniture
  // -------------------------------------------------------------------------
  const fabricSofa = solid(0x6f8ba3);
  const fabricCushion = solid(0x88a6bd);
  const woodDark = solid(0x6b4c33);
  const woodLight = solid(0xb9915c);
  const metal = solid(0x8f979c, { standard: true, roughness: 0.4, metalness: 0.6 });

  const furniture = (
    x0: number,
    x1: number,
    z0: number,
    z1: number,
    y0: number,
    y1: number,
    mat: THREE.Material,
    climbable = true,
  ): THREE.Mesh => {
    const m = new THREE.Mesh(new THREE.BoxGeometry(x1 - x0, y1 - y0, z1 - z0), mat);
    m.position.set((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2);
    m.castShadow = true;
    m.receiveShadow = true;
    scene.add(m);
    col.addWall(x0, x1, z0, z1, y0, y1);
    if (climbable && y1 - HOUSE.floorY <= 1.0) col.addFloor(x0, x1, z0, z1, y1, 'furniture');
    return m;
  };

  // rug
  const rugGeo = new THREE.PlaneGeometry(4.2, 3.0);
  rugGeo.rotateX(-Math.PI / 2);
  const rug = new THREE.Mesh(rugGeo, textured(assets.carpet, 0xb8574e));
  rug.position.set(-13.4, HOUSE.floorY + 0.008, -2.6);
  rug.receiveShadow = true;
  scene.add(rug);

  // sofa facing the TV on the north-west wall
  furniture(-16.9, -11.9, -1.5, -0.4, HOUSE.floorY, HOUSE.floorY + 0.45, fabricSofa);
  furniture(-16.9, -11.9, -1.75, -1.3, HOUSE.floorY + 0.45, HOUSE.floorY + 1.05, fabricCushion, false);
  furniture(-16.9, -11.6, -1.35, -0.55, HOUSE.floorY + 0.45, HOUSE.floorY + 0.62, fabricCushion, false);
  furniture(-16.9, -16.2, -1.5, -0.4, HOUSE.floorY, HOUSE.floorY + 0.68, fabricCushion, false);
  furniture(-12.4, -11.7, -1.5, -0.4, HOUSE.floorY, HOUSE.floorY + 0.68, fabricCushion, false);

  // coffee table
  furniture(-14.6, -12.8, -4.4, -3.2, HOUSE.floorY + 0.34, HOUSE.floorY + 0.42, woodLight, false);
  for (const [dx, dz] of [[-14.5, -4.3], [-12.9, -4.3], [-14.5, -3.3], [-12.9, -3.3]] as const) {
    scene.add(boxAt(0.08, 0.34, 0.08, woodDark, dx + 0.05, HOUSE.floorY, dz + 0.05));
  }

  // TV unit against the west wall
  furniture(HOUSE.i0, HOUSE.i0 + 0.5, -4.6, -1.8, HOUSE.floorY, HOUSE.floorY + 0.55, woodDark);
  const tv = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.85, 1.5), solid(0x22262b, { standard: true, roughness: 0.35 }));
  tv.position.set(HOUSE.i0 + 0.58, HOUSE.floorY + 1.35, -3.2);
  tv.castShadow = true;
  scene.add(tv);
  col.addWall(HOUSE.i0 + 0.5, HOUSE.i0 + 0.66, -3.95, -2.45, HOUSE.floorY + 0.9, HOUSE.floorY + 1.8);

  // side table + lamp
  furniture(-10.4, -9.4, -4.4, -3.4, HOUSE.floorY, HOUSE.floorY + 0.58, woodLight);
  scene.add(cylinderAt(0.055, 0.075, 0.75, metal, -9.9, HOUSE.floorY + 0.58, -3.9));
  const lampShade = cylinderAt(0.28, 0.16, 0.42, solid(0xf7e6bb, { emissive: 0xffe6a8, emissiveIntensity: 0.35 }), -9.9, HOUSE.floorY + 1.3, -3.9);
  scene.add(lampShade);

  // kitchen: counters along the north wall + island + fridge
  const counterTop = solid(0xe6e1d4, { standard: true, roughness: 0.5 });
  const cabinet = solid(0xd8ccb4);
  furniture(HOUSE.i0, -10.8, HOUSE.j1 - 0.66, HOUSE.j1, HOUSE.floorY, HOUSE.floorY + 0.86, cabinet, false);
  furniture(HOUSE.i0, -10.8, HOUSE.j1 - 0.7, HOUSE.j1, HOUSE.floorY + 0.86, HOUSE.floorY + 0.92, counterTop, false);
  furniture(-13.6, -11.2, 3.9, 4.95, HOUSE.floorY, HOUSE.floorY + 0.86, cabinet, false);
  furniture(-13.7, -11.1, 3.85, 5.0, HOUSE.floorY + 0.86, HOUSE.floorY + 0.92, counterTop, false);
  furniture(HOUSE.i0, HOUSE.i0 + 0.75, 5.2, 6.0, HOUSE.floorY, HOUSE.floorY + 1.85, solid(0xd8dde0, { standard: true, roughness: 0.35, metalness: 0.25 }), false);
  // sink + faucet
  scene.add(boxAt(0.5, 0.02, 0.5, metal, -13.0, HOUSE.floorY + 0.925, HOUSE.j1 - 0.35));
  scene.add(cylinderAt(0.03, 0.03, 0.34, metal, -13.0, HOUSE.floorY + 0.92, HOUSE.j1 - 0.62));
  // upper cabinets
  furniture(HOUSE.i0, -10.8, HOUSE.j1 - 0.36, HOUSE.j1, HOUSE.floorY + 1.6, HOUSE.floorY + 2.35, cabinet, false);

  // dining table + chairs
  furniture(-12.4, -10.2, 0.1, 1.5, HOUSE.floorY + 0.72, HOUSE.floorY + 0.8, woodLight, false);
  for (const [x, z] of [[-12.25, 0.25], [-10.35, 0.25], [-12.25, 1.35], [-10.35, 1.35]] as const) {
    scene.add(boxAt(0.08, 0.72, 0.08, woodDark, x, HOUSE.floorY, z));
  }
  for (const [x, z] of [[-11.3, -0.35], [-11.3, 1.95]] as const) {
    furniture(x - 0.24, x + 0.24, z - 0.24, z + 0.24, HOUSE.floorY, HOUSE.floorY + 0.46, woodDark);
    furniture(x - 0.24, x + 0.24, z - 0.26, z - 0.2, HOUSE.floorY + 0.46, HOUSE.floorY + 0.95, woodDark, false);
  }

  // potted plant by the door
  scene.add(cylinderAt(0.22, 0.16, 0.4, solid(PALETTE.terracotta), -9.0, HOUSE.floorY, -3.0));
  const leaves = new THREE.Mesh(new THREE.IcosahedronGeometry(0.42, 0), solid(0x3f8a35));
  leaves.position.set(-9.0, HOUSE.floorY + 0.82, -3.0);
  leaves.castShadow = true;
  scene.add(leaves);

  // -------------------------------------------------------------------------
  // upstairs bedroom
  // -------------------------------------------------------------------------
  const bedX = -12.6;
  const bedZ = -1.2;
  furniture(bedX - 0.9, bedX + 0.9, bedZ - 1.1, bedZ + 1.1, upperY, upperY + 0.45, solid(0xf0e6d2));
  furniture(bedX - 0.9, bedX + 0.9, bedZ - 1.15, bedZ - 1.0, upperY, upperY + 0.85, woodDark, false);
  furniture(bedX - 0.85, bedX + 0.85, bedZ - 0.9, bedZ + 1.05, upperY + 0.45, upperY + 0.56, solid(0x9fb6c9), false);
  furniture(bedX - 0.7, bedX - 0.2, bedZ - 0.75, bedZ - 0.25, upperY + 0.45, upperY + 0.6, solid(0xffffff), false);
  furniture(bedX + 0.2, bedX + 0.7, bedZ - 0.75, bedZ - 0.25, upperY + 0.45, upperY + 0.6, solid(0xffffff), false);
  furniture(bedX + 1.15, bedX + 1.65, bedZ - 1.1, bedZ - 0.6, upperY, upperY + 0.55, woodDark);
  scene.add(cylinderAt(0.16, 0.12, 0.3, solid(0xf3e3b8, { emissive: 0xffe9bb, emissiveIntensity: 0.5 }), bedX + 1.4, upperY + 0.55, bedZ - 0.85));

  const rug2 = new THREE.Mesh(new THREE.PlaneGeometry(3.6, 2.6), textured(assets.carpet, 0x8c9a6c));
  rug2.rotation.x = -Math.PI / 2;
  rug2.position.set(-15.6, upperY + 0.008, 2.2);
  rug2.receiveShadow = true;
  scene.add(rug2);

  // wardrobe + low dresser along the west wall (kept short so the room reads as
  // a room instead of one giant slab)
  furniture(HOUSE.i0, HOUSE.i0 + 0.55, 1.1, 2.7, upperY, upperY + 1.92, woodLight, false);
  furniture(HOUSE.i0, HOUSE.i0 + 0.55, 1.55, 2.25, upperY + 0.95, upperY + 0.99, woodDark, false);
  furniture(HOUSE.i0, HOUSE.i0 + 0.5, 3.1, 4.4, upperY, upperY + 0.92, woodDark, false);
  furniture(HOUSE.i0, HOUSE.i0 + 0.5, 3.4, 4.1, upperY + 0.4, upperY + 0.46, solid(0xf0e6d2), false);
  furniture(-17.4, -15.6, 5.4, 6.1, upperY, upperY + 0.76, woodLight);
  furniture(-16.2, -15.8, 4.4, 4.9, upperY, upperY + 0.5, woodDark);
  scene.add(sphereAt(0.3, solid(0x4f9c3a), -16.0, upperY + 0.8, 4.65, 8));

  // -------------------------------------------------------------------------
  // doors (leafs drawn open)
  // -------------------------------------------------------------------------
  const doorLeaf = (x: number, z: number, w: number, rotY: number): void => {
    const g = new THREE.BoxGeometry(0.05, 2.05, w);
    const m = new THREE.Mesh(g, woodDark);
    m.position.set(x, HOUSE.floorY + 1.03, z);
    m.rotation.y = rotY;
    m.castShadow = true;
    scene.add(m);
  };
  doorLeaf(HOUSE.x1 - 0.16, fd + 0.6, 1.0, 0.9);
  doorLeaf(HOUSE.x0 + 0.16, bd - 0.58, 1.0, -0.9);

  // -------------------------------------------------------------------------
  // lights
  // -------------------------------------------------------------------------
  const lights: THREE.Light[] = [];
  const addLight = (x: number, y: number, z: number, intensity: number): void => {
    const l = new THREE.PointLight(0xffdcae, intensity, 9, 2);
    l.position.set(x, y, z);
    scene.add(l);
    lights.push(l);
  };
  addLight(-13.0, HOUSE.slabY - 0.25, -2.4, 9);
  addLight(-12.5, HOUSE.slabY - 0.25, 3.6, 7);
  addLight(-13.0, eaveY - 0.85, 0.4, 8);

  // ceiling lamp fixtures
  for (const [x, y, z] of [[-13.0, HOUSE.slabY - 0.12, -2.4], [-12.5, HOUSE.slabY - 0.12, 3.6], [-13.0, eaveY - 0.72, 0.4]] as const) {
    scene.add(cylinderAt(0.02, 0.02, 0.12, solid(0x333333), x, y, z));
    scene.add(cylinderAt(0.16, 0.26, 0.2, solid(0xfaf0d4, { emissive: 0xfff0c8, emissiveIntensity: 0.6 }), x, y - 0.2, z));
  }

  return {
    lights,
    update(_dt: number): void {
      void _dt;
    },
  };
}

