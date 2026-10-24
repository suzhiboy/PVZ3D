/**
 * Daylight setup: a painted sky dome, a warm key light with shadows and a
 * cool sky/ground bounce. Everything is procedural.
 */
import * as THREE from 'three';
import { fbm, makeNoise2D, mulberry32 } from '../core/mathx.ts';
import { applyAnisotropy } from '../core/textures.ts';

export interface Environment {
  sun: THREE.DirectionalLight;
  hemi: THREE.HemisphereLight;
  sky: THREE.Mesh;
  update(dt: number): void;
}

function paintSky(): HTMLCanvasElement {
  const w = 1024;
  const h = 512;
  const cv = document.createElement('canvas');
  cv.width = w;
  cv.height = h;
  const c = cv.getContext('2d');
  if (!c) throw new Error('2d canvas unavailable');

  const g = c.createLinearGradient(0, 0, 0, h);
  g.addColorStop(0, '#2a74cf');
  g.addColorStop(0.3, '#5fb0e8');
  g.addColorStop(0.5, '#b9e0f6');
  g.addColorStop(0.61, '#eaf5f7');
  g.addColorStop(1, '#dbe6c6');
  c.fillStyle = g;
  c.fillRect(0, 0, w, h);

  // soft high-altitude haze bands
  const rnd = mulberry32(7);
  for (let i = 0; i < 26; i++) {
    const y = h * (0.36 + rnd() * 0.2);
    const rr = 90 + rnd() * 190;
    const grad = c.createRadialGradient(rnd() * w, y, 0, rnd() * w, y, rr);
    grad.addColorStop(0, 'rgba(255,255,255,0.18)');
    grad.addColorStop(1, 'rgba(255,255,255,0)');
    c.fillStyle = grad;
    c.fillRect(0, y - rr, w, rr * 2);
  }

  // cartoon cumulus clouds: clusters of soft blobs with a brighter top
  const noise = makeNoise2D(31);
  const cloud = (cx: number, cy: number, scale: number, seed: number): void => {
    const r = mulberry32(seed);
    const puffs = 7 + Math.floor(r() * 6);
    for (let i = 0; i < puffs; i++) {
      const px = cx + (r() - 0.5) * 150 * scale;
      const py = cy + (r() - 0.5) * 34 * scale - Math.cos((i / puffs) * Math.PI) * 16 * scale;
      const pr = (26 + r() * 34) * scale;
      const grd = c.createRadialGradient(px, py, pr * 0.15, px, py, pr);
      const shade = 0.72 + fbm(noise, px * 0.01, py * 0.01, 3) * 0.3;
      grd.addColorStop(0, `rgba(255,255,255,${0.95 * shade})`);
      grd.addColorStop(0.55, `rgba(250,252,255,${0.8 * shade})`);
      grd.addColorStop(1, 'rgba(226,238,248,0)');
      c.fillStyle = grd;
      c.beginPath();
      c.ellipse(px, py, pr, pr * 0.72, 0, 0, Math.PI * 2);
      c.fill();
    }
  };
  for (let i = 0; i < 9; i++) {
    cloud(rnd() * w, h * (0.14 + rnd() * 0.22), 0.7 + rnd() * 0.8, 100 + i * 17);
  }

  return cv;
}

export function createEnvironment(scene: THREE.Scene): Environment {
  const skyTex = new THREE.CanvasTexture(paintSky());
  skyTex.colorSpace = THREE.SRGBColorSpace;
  skyTex.mapping = THREE.EquirectangularReflectionMapping;
  applyAnisotropy(4);

  const sky = new THREE.Mesh(
    new THREE.SphereGeometry(320, 32, 20),
    new THREE.MeshBasicMaterial({ map: skyTex, side: THREE.BackSide, fog: false, depthWrite: false }),
  );
  sky.name = 'sky';
  sky.frustumCulled = false;
  scene.add(sky);

  scene.fog = new THREE.Fog(0xd6e8f2, 70, 280);

  const hemi = new THREE.HemisphereLight(0xd6ecff, 0x8fa863, 0.52);
  hemi.position.set(0, 40, 0);
  scene.add(hemi);

  const sun = new THREE.DirectionalLight(0xfff0cc, 1.85);
  sun.position.set(38, 46, 26);
  sun.target.position.set(-12, 0, 0);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  sun.shadow.bias = -0.0006;
  sun.shadow.normalBias = 0.035;
  const cam = sun.shadow.camera;
  cam.left = -46;
  cam.right = 46;
  cam.top = 34;
  cam.bottom = -34;
  cam.near = 1;
  cam.far = 160;
  cam.updateProjectionMatrix();
  scene.add(sun);
  scene.add(sun.target);

  // A dim fill light opposite the key so shaded walls are not flat black.
  const fill = new THREE.DirectionalLight(0xbcd8ee, 0.22);
  fill.position.set(-30, 20, -30);
  scene.add(fill);

  return {
    sun,
    hemi,
    sky,
    update(dt: number): void {
      // Keep the dome centred on the world; nothing else animates yet.
      void dt;
    },
  };
}

