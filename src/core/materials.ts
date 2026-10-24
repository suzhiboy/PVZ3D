/**
 * Materials are shared and cached: every texture is painted exactly once and
 * reused across the world. Texel density is varied by scaling geometry UVs
 * (see `uvScale`) rather than by cloning textures.
 */
import * as THREE from 'three';
import {
  asphaltTexture,
  brickTexture,
  carpetTexture,
  concreteTexture,
  copingTexture,
  glowTexture,
  grassTileTexture,
  hedgeTexture,
  poolFloorTexture,
  roadStripeTexture,
  shingleTexture,
  sidingTexture,
  soilTexture,
  tileHighlightTexture,
  wallTexture,
  waterNoiseTexture,
  wildGrassTexture,
  woodTexture,
} from './textures.ts';

/** Multiply a geometry's UVs so a tiled texture keeps a stable world scale. */
export function uvScale(
  geo: THREE.BufferGeometry,
  u: number,
  v: number,
  offsetU = 0,
  offsetV = 0,
): THREE.BufferGeometry {
  const uv = geo.getAttribute('uv') as THREE.BufferAttribute | undefined;
  if (!uv) return geo;
  for (let i = 0; i < uv.count; i++) {
    uv.setXY(i, uv.getX(i) * u + offsetU, uv.getY(i) * v + offsetV);
  }
  uv.needsUpdate = true;
  return geo;
}

export interface SolidOpts {
  transparent?: boolean;
  opacity?: number;
  side?: THREE.Side;
  emissive?: number;
  emissiveIntensity?: number;
  standard?: boolean;
  roughness?: number;
  metalness?: number;
  depthWrite?: boolean;
  vertexColors?: boolean;
}

const solidCache = new Map<string, THREE.Material>();

/** Cached flat-colour material (Lambert by default, cheap and soft). */
export function solid(color: number, opts: SolidOpts = {}): THREE.Material {
  const key = `${color}|${JSON.stringify(opts)}`;
  const hit = solidCache.get(key);
  if (hit) return hit;
  let mat: THREE.Material;
  if (opts.standard) {
    mat = new THREE.MeshStandardMaterial({
      color,
      roughness: opts.roughness ?? 0.65,
      metalness: opts.metalness ?? 0.05,
      transparent: opts.transparent,
      opacity: opts.opacity ?? 1,
      side: opts.side ?? THREE.FrontSide,
      emissive: opts.emissive ?? 0x000000,
      emissiveIntensity: opts.emissiveIntensity ?? 1,
      depthWrite: opts.depthWrite ?? true,
      vertexColors: opts.vertexColors ?? false,
    });
  } else {
    mat = new THREE.MeshLambertMaterial({
      color,
      transparent: opts.transparent,
      opacity: opts.opacity ?? 1,
      side: opts.side ?? THREE.FrontSide,
      emissive: opts.emissive ?? 0x000000,
      emissiveIntensity: opts.emissiveIntensity ?? 1,
      depthWrite: opts.depthWrite ?? true,
      vertexColors: opts.vertexColors ?? false,
    });
  }
  solidCache.set(key, mat);
  return mat;
}

/**
 * Toon shading for characters. A four-band gradient map turns the smooth
 * Lambert falloff into hard cel steps, which is what makes the plants and
 * zombies read as drawn art instead of shaded geometry.
 */
let gradientMap: THREE.DataTexture | null = null;

function toonRamp(): THREE.DataTexture {
  if (gradientMap) return gradientMap;
  const bands = new Uint8Array([96, 158, 210, 255]);
  const tex = new THREE.DataTexture(bands, bands.length, 1, THREE.RedFormat);
  tex.minFilter = THREE.NearestFilter;
  tex.magFilter = THREE.NearestFilter;
  tex.generateMipmaps = false;
  tex.needsUpdate = true;
  gradientMap = tex;
  return tex;
}

const toonCache = new Map<number, THREE.MeshToonMaterial>();

/** Cached cel-shaded material used by every plant and zombie. */
export function toon(color: number): THREE.MeshToonMaterial {
  const hit = toonCache.get(color);
  if (hit) return hit;
  const mat = new THREE.MeshToonMaterial({ color, gradientMap: toonRamp() });
  toonCache.set(color, mat);
  return mat;
}

const inkCache = new Map<number, THREE.MeshBasicMaterial>();

function inkMaterial(color: number): THREE.MeshBasicMaterial {
  const hit = inkCache.get(color);
  if (hit) return hit;
  const mat = new THREE.MeshBasicMaterial({ color, side: THREE.BackSide });
  inkCache.set(color, mat);
  return mat;
}

/**
 * Inverted-hull ink outlines. Every mesh large enough to own a silhouette gets
 * a back-facing shell a few centimetres larger, so the character picks up a
 * drawn contour from any angle. Tiny details (pupils, teeth, highlights) are
 * skipped via `userData.noInk` and the radius test to avoid muddy blobs.
 */
export function applyInk(root: THREE.Object3D, width = 0.012, color = 0x2b3a24): void {
  const meshes: THREE.Mesh[] = [];
  root.traverse((o) => {
    if ((o as THREE.Mesh).isMesh) meshes.push(o as THREE.Mesh);
  });
  for (const mesh of meshes) {
    if (mesh.userData.noInk) continue;
    const geo = mesh.geometry as THREE.BufferGeometry;
    if (!geo.boundingSphere) geo.computeBoundingSphere();
    const radius = geo.boundingSphere?.radius ?? 0;
    if (radius < 0.075) continue;
    const shell = new THREE.Mesh(geo, inkMaterial(color));
    shell.scale.setScalar(1 + width / Math.max(radius, 0.08));
    shell.castShadow = false;
    shell.receiveShadow = false;
    shell.userData.noInk = true;
    mesh.add(shell);
  }
}

const texturedCache = new Map<string, THREE.Material>();
export function textured(
  map: THREE.Texture,
  color = 0xffffff,
  opts: SolidOpts = {},
): THREE.Material {
  const key = `${map.uuid}|${color}|${JSON.stringify(opts)}`;
  const hit = texturedCache.get(key);
  if (hit) return hit;
  const mat = new THREE.MeshLambertMaterial({
    map,
    color,
    transparent: opts.transparent,
    opacity: opts.opacity ?? 1,
    side: opts.side ?? THREE.FrontSide,
    emissive: opts.emissive ?? 0x000000,
    emissiveIntensity: opts.emissiveIntensity ?? 1,
    depthWrite: opts.depthWrite ?? true,
    vertexColors: opts.vertexColors ?? false,
  });
  texturedCache.set(key, mat);
  return mat;
}

export interface WorldAssets {
  grass: THREE.Texture;
  lawnTile: THREE.Texture;
  soil: THREE.Texture;
  concrete: THREE.Texture;
  asphalt: THREE.Texture;
  stripe: THREE.Texture;
  siding: THREE.Texture;
  brick: THREE.Texture;
  shingle: THREE.Texture;
  wood: THREE.Texture;
  coping: THREE.Texture;
  poolFloor: THREE.Texture;
  hedge: THREE.Texture;
  wallpaper: THREE.Texture;
  carpet: THREE.Texture;
  glow: THREE.Texture;
  highlight: THREE.Texture;
  waterNoise: THREE.Texture;
}

let assets: WorldAssets | null = null;

/** Paint every world texture once. */
export function getAssets(): WorldAssets {
  if (assets) return assets;
  const fix = (t: THREE.Texture): THREE.Texture => {
    t.repeat.set(1, 1);
    return t;
  };
  assets = {
    grass: fix(wildGrassTexture()),
    lawnTile: fix(grassTileTexture()),
    soil: fix(soilTexture()),
    concrete: fix(concreteTexture()),
    asphalt: fix(asphaltTexture()),
    stripe: fix(roadStripeTexture()),
    siding: fix(sidingTexture()),
    brick: fix(brickTexture()),
    shingle: fix(shingleTexture()),
    wood: fix(woodTexture()),
    coping: fix(copingTexture()),
    poolFloor: fix(poolFloorTexture()),
    hedge: fix(hedgeTexture()),
    wallpaper: fix(wallTexture()),
    carpet: fix(carpetTexture()),
    glow: glowTexture(),
    highlight: tileHighlightTexture(),
    waterNoise: waterNoiseTexture(),
  };
  return assets;
}

/** Common palette used by the procedural props. */
export const PALETTE = {
  trim: 0xf6f1e6,
  trimShadow: 0xd9d1c0,
  darkWood: 0x6b4c33,
  roof: 0x4f5b63,
  glass: 0xb6d8e4,
  metal: 0x9aa3a8,
  leaf: 0x4e9c37,
  leafDark: 0x2f6b21,
  flowerRed: 0xe0564a,
  flowerYellow: 0xf6d34b,
  flowerPink: 0xf39ac0,
  terracotta: 0xb9694b,
  stone: 0xc7c1b2,
  water: 0x63c6dd,
  fabric: 0x7a8fa6,
  fabricWarm: 0xc9a06a,
  fabricGreen: 0x6d8f5c,
  woodLight: 0xc9a97a,
} as const;
