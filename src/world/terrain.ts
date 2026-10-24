/**
 * Ground, lawns, street and pool. The two lawns are instanced quad grids so a
 * single draw call renders 45/54 tiles with per-tile tint and rotation.
 */
import * as THREE from 'three';
import type { Collision } from '../core/collision.ts';
import { getAssets, solid, textured, uvScale } from '../core/materials.ts';
import { mulberry32 } from '../core/mathx.ts';
import { BACK_YARD, FRONT_YARD, HOUSE, POOL, STREET, TILE, type Yard } from './layout.ts';
import { cylinderAt, planeAt } from './parts.ts';
import { boxAt } from './parts.ts';

export interface LawnTiles {
  readonly yard: Yard;
  readonly mesh: THREE.InstancedMesh;
  /** True when (c,r) is a plantable grass tile drawn by this mesh. */
  hasTile(c: number, r: number): boolean;
  worldOf(c: number, r: number, out?: THREE.Vector3): THREE.Vector3;
  /** Cell under a world position, clamped to the lawn. */
  cellAt(x: number, z: number): { c: number; r: number; inside: boolean };
}

export interface Terrain {
  front: LawnTiles;
  back: LawnTiles;
  water: THREE.Mesh;
  highlight: THREE.Mesh;
  update(dt: number): void;
}

/**
 * Split a rectangle into up to four pieces around a rectangular hole, so a
 * lawn / ground floor can leave the pool basin open.
 */
function splitAroundHole(
  rect: { x0: number; x1: number; z0: number; z1: number },
  hole: { x0: number; x1: number; z0: number; z1: number },
): { x0: number; x1: number; z0: number; z1: number }[] {
  const hx0 = Math.max(hole.x0, rect.x0);
  const hx1 = Math.min(hole.x1, rect.x1);
  const hz0 = Math.max(hole.z0, rect.z0);
  const hz1 = Math.min(hole.z1, rect.z1);
  if (hx0 >= hx1 || hz0 >= hz1) return [rect];
  const out = [
    { x0: rect.x0, x1: hx0, z0: rect.z0, z1: rect.z1 },
    { x0: hx1, x1: rect.x1, z0: rect.z0, z1: rect.z1 },
    { x0: hx0, x1: hx1, z0: rect.z0, z1: hz0 },
    { x0: hx0, x1: hx1, z0: hz1, z1: rect.z1 },
  ];
  return out.filter((p) => p.x1 - p.x0 > 1e-4 && p.z1 - p.z0 > 1e-4);
}

function buildLawn(scene: THREE.Scene, col: Collision, yard: Yard, seed: number): LawnTiles {
  const assets = getAssets();
  const cells: { c: number; r: number }[] = [];
  for (let r = 0; r < yard.rows; r++) {
    for (let c = 0; c < yard.cols; c++) {
      if (!yard.cellWater(c, r)) cells.push({ c, r });
    }
  }

  const geo = new THREE.PlaneGeometry(TILE * 1.004, TILE * 1.004);
  geo.rotateX(-Math.PI / 2);
  const mat = textured(assets.lawnTile);
  const inst = new THREE.InstancedMesh(geo, mat, cells.length);
  inst.name = `lawn-${yard.name}`;
  inst.receiveShadow = true;
  inst.castShadow = false;

  const rnd = mulberry32(seed);
  const m = new THREE.Matrix4();
  const q = new THREE.Quaternion();
  const pos = new THREE.Vector3();
  const scl = new THREE.Vector3(1, 1, 1);
  const base = new THREE.Color();
  const white = new THREE.Color(1, 1, 1);

  const tileKey = new Set<string>();
  cells.forEach((cell, i) => {
    const { x, z } = yard.cellCenter(cell.c, cell.r);
    const rot = Math.floor(rnd() * 4) * (Math.PI / 2);
    q.setFromAxisAngle(new THREE.Vector3(0, 1, 0), rot);
    pos.set(x, 0.014, z);
    m.compose(pos, q, scl);
    inst.setMatrixAt(i, m);

    const dark = (cell.c + cell.r) % 2 === 0;
    const jitter = 0.97 + rnd() * 0.06;
    base.copy(white);
    if (dark) base.multiplyScalar(0.855);
    base.multiplyScalar(jitter);
    inst.setColorAt(i, base);
    tileKey.add(`${cell.c},${cell.r}`);
  });
  inst.instanceMatrix.needsUpdate = true;
  if (inst.instanceColor) inst.instanceColor.needsUpdate = true;
  scene.add(inst);

  // One flat collision plane per lawn keeps the player at ground level — split
  // around the pool so the water rows fall through to the wading floor.
  const lawnRect = { x0: yard.x0, x1: yard.x1, z0: yard.z0, z1: yard.z1 };
  const poolHole = { x0: POOL.x0, x1: POOL.x1, z0: POOL.z0, z1: POOL.z1 };
  for (const p of splitAroundHole(lawnRect, poolHole)) {
    col.addFloor(p.x0, p.x1, p.z0, p.z1, 0, `lawn-${yard.name}`);
  }

  return {
    yard,
    mesh: inst,
    hasTile(c: number, r: number): boolean {
      return tileKey.has(`${c},${r}`);
    },
    worldOf(c: number, r: number, out = new THREE.Vector3()): THREE.Vector3 {
      const p = yard.cellCenter(c, r);
      return out.set(p.x, 0.014, p.z);
    },
    cellAt(x: number, z: number): { c: number; r: number; inside: boolean } {
      const c = yard.colAt(x);
      const r = yard.rowAt(z);
      return {
        c: Math.max(0, Math.min(yard.cols - 1, c)),
        r: Math.max(0, Math.min(yard.rows - 1, r)),
        inside: yard.inside(x, z),
      };
    },
  };
}

function createWater(assets: ReturnType<typeof getAssets>): THREE.Mesh {
  const noise = assets.waterNoise;
  noise.wrapS = THREE.RepeatWrapping;
  noise.wrapT = THREE.RepeatWrapping;

  const mat = new THREE.ShaderMaterial({
    transparent: true,
    uniforms: {
      uTime: { value: 0 },
      uNoise: { value: noise },
      uDeep: { value: new THREE.Color(0x1e7fae) },
      uShallow: { value: new THREE.Color(0x74d8e8) },
      uSky: { value: new THREE.Color(0xcfeaf7) },
    },
    vertexShader: /* glsl */ `
      varying vec3 vWorld;
      varying vec2 vUv;
      void main() {
        vUv = uv;
        vec4 w = modelMatrix * vec4(position, 1.0);
        vWorld = w.xyz;
        gl_Position = projectionMatrix * viewMatrix * w;
      }
    `,
    fragmentShader: /* glsl */ `
      precision highp float;
      uniform float uTime;
      uniform sampler2D uNoise;
      uniform vec3 uDeep;
      uniform vec3 uShallow;
      uniform vec3 uSky;
      varying vec3 vWorld;
      varying vec2 vUv;
      void main() {
        vec2 p = vWorld.xz * 0.42;
        float n1 = texture2D(uNoise, p + vec2(uTime * 0.012, uTime * 0.008)).r;
        float n2 = texture2D(uNoise, p * 2.7 + vec2(-uTime * 0.02, uTime * 0.014)).r;
        float ripple = n1 * 0.62 + n2 * 0.38;

        vec3 viewDir = normalize(cameraPosition - vWorld);
        float fres = pow(1.0 - clamp(viewDir.y, 0.0, 1.0), 2.6);

        vec3 col = mix(uDeep, uShallow, smoothstep(0.28, 0.78, ripple));
        col = mix(col, uSky, fres * 0.62);

        // sparkles where the fine noise peaks
        float sparkle = pow(max(0.0, n2 - 0.72) * 3.2, 2.4);
        col += vec3(1.0, 0.99, 0.9) * sparkle * 0.85;

        float alpha = mix(0.72, 0.94, fres) + sparkle * 0.4;
        gl_FragColor = vec4(col, clamp(alpha, 0.0, 1.0));
      }
    `,
  });

  const x0 = POOL.x0;
  const x1 = POOL.x1;
  const z0 = POOL.z0;
  const z1 = POOL.z1;
  const geo = new THREE.PlaneGeometry(x1 - x0, z1 - z0);
  geo.rotateX(-Math.PI / 2);
  const mesh = new THREE.Mesh(geo, mat);
  mesh.position.set((x0 + x1) / 2, POOL.surfaceY, (z0 + z1) / 2);
  mesh.name = 'pool-water';
  mesh.renderOrder = 2;
  return mesh;
}

export function buildTerrain(scene: THREE.Scene, col: Collision): Terrain {
  const assets = getAssets();

  // --- base grass ----------------------------------------------------------
  // One big lawn patch with the pool cut out of it, so the water surface and
  // the pool shell are actually visible instead of being buried under grass.
  const groundRect = { x0: -86, x1: 54, z0: -55, z1: 55 };
  const groundHole = { x0: POOL.x0, x1: POOL.x1, z0: POOL.z0, z1: POOL.z1 };
  for (const p of splitAroundHole(groundRect, groundHole)) {
    const g = new THREE.PlaneGeometry(p.x1 - p.x0, p.z1 - p.z0, 1, 1);
    g.rotateX(-Math.PI / 2);
    uvScale(g, (p.x1 - p.x0) / 6.4, (p.z1 - p.z0) / 6.1);
    const patch = new THREE.Mesh(g, textured(assets.grass));
    patch.position.set((p.x0 + p.x1) / 2, -0.02, (p.z0 + p.z1) / 2);
    patch.receiveShadow = true;
    patch.name = 'ground';
    scene.add(patch);
    col.addFloor(p.x0, p.x1, p.z0, p.z1, 0, 'ground');
  }

  // --- lawns ---------------------------------------------------------------
  const front = buildLawn(scene, col, FRONT_YARD, 91);
  const back = buildLawn(scene, col, BACK_YARD, 137);

  // --- paved surfaces ------------------------------------------------------
  const concrete = textured(assets.concrete);
  const pave = (
    x0: number,
    x1: number,
    z0: number,
    z1: number,
    y: number,
    uScale = 1,
    tile = true,
  ): THREE.Mesh => {
    const g = new THREE.PlaneGeometry(x1 - x0, z1 - z0);
    g.rotateX(-Math.PI / 2);
    uvScale(g, (x1 - x0) / 2.4 * uScale, (z1 - z0) / 2.4 * uScale);
    const m = new THREE.Mesh(g, concrete);
    m.position.set((x0 + x1) / 2, y, (z0 + z1) / 2);
    m.receiveShadow = true;
    if (tile) col.addFloor(x0, x1, z0, z1, y, 'paving');
    return m;
  };

  // street-side walk + kerb + road
  scene.add(pave(7.2, 8.55, -26, 26, 0.05));
  scene.add(boxAt(0.18, 0.16, 52, solid(0xd8d3c4), 8.47, 0.0, 0));

  const roadGeo = new THREE.PlaneGeometry(STREET.roadX1 - STREET.roadX0, STREET.z1 - STREET.z0);
  roadGeo.rotateX(-Math.PI / 2);
  uvScale(roadGeo, 3, 18);
  const road = new THREE.Mesh(roadGeo, textured(assets.asphalt));
  road.position.set((STREET.roadX0 + STREET.roadX1) / 2, 0.008, 0);
  road.receiveShadow = true;
  scene.add(road);

  const dashTex = assets.stripe.clone();
  dashTex.wrapS = THREE.RepeatWrapping;
  dashTex.wrapT = THREE.RepeatWrapping;
  dashTex.repeat.set(1, 9);
  dashTex.needsUpdate = true;
  const dash = planeAt(
    0.16,
    (STREET.z1 - STREET.z0) * 0.86,
    textured(dashTex, 0xffffff, { transparent: true, depthWrite: false }),
    (STREET.roadX0 + STREET.roadX1) / 2 + 0.9,
    0.02,
    0,
  );
  scene.add(dash);

  scene.add(pave(STREET.roadX1, STREET.roadX1 + 1.2, -26, 26, 0.05));

  // front walkway along the north edge of the lawn, porch to street
  scene.add(pave(-6.5, 7.2, -5.0, -4.02, 0.05));

  // backyard patio between the house and the pool lawn
  scene.add(pave(-20.42, HOUSE.x0, -4.9, 4.9, 0.05));

  // --- foundation beds -----------------------------------------------------
  const soilMat = textured(assets.soil);
  const soilGeo = new THREE.PlaneGeometry(0.62, 13);
  soilGeo.rotateX(-Math.PI / 2);
  uvScale(soilGeo, 0.5, 4);
  const frontBed = new THREE.Mesh(soilGeo, soilMat);
  frontBed.position.set(HOUSE.x1 + 0.31, 0.02, 0);
  frontBed.receiveShadow = true;
  scene.add(frontBed);
  const backBed = new THREE.Mesh(soilGeo, soilMat);
  backBed.position.set(HOUSE.x0 - 0.31, 0.02, 0);
  backBed.receiveShadow = true;
  scene.add(backBed);

  // --- pool ----------------------------------------------------------------
  const water = createWater(assets);
  scene.add(water);

  const x0 = POOL.x0;
  const x1 = POOL.x1;
  const z0 = POOL.z0;
  const z1 = POOL.z1;
  const copingMat = textured(assets.coping);
  const copingW = 0.34;
  const copingY = 0.035;

  const poolFloorGeo = new THREE.PlaneGeometry(x1 - x0, z1 - z0);
  poolFloorGeo.rotateX(-Math.PI / 2);
  uvScale(poolFloorGeo, 5, 2);
  const poolFloor = new THREE.Mesh(poolFloorGeo, textured(assets.poolFloor));
  poolFloor.position.set((x0 + x1) / 2, POOL.floorY, (z0 + z1) / 2);
  poolFloor.receiveShadow = true;
  scene.add(poolFloor);

  const wallMat = textured(assets.poolFloor, 0xdff2f8);
  const shell = new THREE.Group();
  shell.add(boxAt(x1 - x0, 1.6, 0.2, wallMat, (x0 + x1) / 2, POOL.floorY, z0 - 0.1));
  shell.add(boxAt(x1 - x0, 1.6, 0.2, wallMat, (x0 + x1) / 2, POOL.floorY, z1 + 0.1));
  shell.add(boxAt(0.2, 1.6, z1 - z0, wallMat, x0 - 0.1, POOL.floorY, (z0 + z1) / 2));
  shell.add(boxAt(0.2, 1.6, z1 - z0, wallMat, x1 + 0.1, POOL.floorY, (z0 + z1) / 2));
  scene.add(shell);

  // coping ring
  const cg = (w: number, d: number, x: number, z: number): THREE.Mesh => {
    const g = new THREE.BoxGeometry(w, 0.22, d);
    const uv = g.getAttribute('uv') as THREE.BufferAttribute;
    for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * 2, uv.getY(i) * 0.4);
    uv.needsUpdate = true;
    const m = new THREE.Mesh(g, copingMat);
    m.position.set(x, copingY - 0.11, z);
    m.receiveShadow = true;
    m.castShadow = true;
    return m;
  };
  scene.add(cg(x1 - x0 + copingW * 2, copingW, (x0 + x1) / 2, z0 - copingW / 2));
  scene.add(cg(x1 - x0 + copingW * 2, copingW, (x0 + x1) / 2, z1 + copingW / 2));
  scene.add(cg(copingW, z1 - z0, x0 - copingW / 2, (z0 + z1) / 2));
  scene.add(cg(copingW, z1 - z0, x1 + copingW / 2, (z0 + z1) / 2));
  col.addFloor(x0 - copingW, x1 + copingW, z0 - copingW, z0, copingY, 'coping');
  col.addFloor(x0 - copingW, x1 + copingW, z1, z1 + copingW, copingY, 'coping');
  col.addFloor(x0 - copingW, x0, z0, z1, copingY, 'coping');
  col.addFloor(x1, x1 + copingW, z0, z1, copingY, 'coping');

  // pool ladder at the east end
  const ladderMat = solid(0xd9dde0, { standard: true, metalness: 0.7, roughness: 0.3 });
  for (const off of [-0.28, 0.28]) {
    const rail = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.035, 1.5, 8), ladderMat);
    rail.position.set(x1 - 0.12, 0.55, (z0 + z1) / 2 + off);
    rail.castShadow = true;
    scene.add(rail);
  }
  for (let i = 0; i < 3; i++) {
    const rung = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.56, 8), ladderMat);
    rung.rotation.x = Math.PI / 2;
    rung.position.set(x1 - 0.12, 0.05 - i * 0.36, (z0 + z1) / 2);
    scene.add(rung);
  }

  // wading floor + water volume for movement checks
  col.addFloor(x0, x1, z0, z1, POOL.wadeY, 'pool');
  col.addWater({ x0, x1, z0, z1 });

  // --- hover highlight -----------------------------------------------------
  const hg = new THREE.PlaneGeometry(TILE * 0.96, TILE * 0.96);
  hg.rotateX(-Math.PI / 2);
  const highlight = new THREE.Mesh(
    hg,
    new THREE.MeshBasicMaterial({
      map: assets.highlight,
      transparent: true,
      depthWrite: false,
      opacity: 0.9,
    }),
  );
  highlight.position.y = 0.05;
  highlight.visible = false;
  highlight.renderOrder = 3;
  scene.add(highlight);

  // Poolside planters for flavour.
  scene.add(cylinderAt(0.3, 0.24, 0.5, solid(0xb9694b), x0 + 0.6, 0.03, z0 - 0.75));
  scene.add(cylinderAt(0.3, 0.24, 0.5, solid(0xb9694b), x1 - 0.6, 0.03, z0 - 0.75));

  const waterMat = water.material as THREE.ShaderMaterial;
  return {
    front,
    back,
    water,
    highlight,
    update(dt: number): void {
      waterMat.uniforms.uTime.value += dt;
    },
  };
}
