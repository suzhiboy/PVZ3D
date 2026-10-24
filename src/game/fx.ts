/**
 * Tiny CPU particle bursts (dirt when planting, dust when a zombie falls, gold
 * sparks when sun is collected). Each burst is one Points object that fades and
 * removes itself; concurrent bursts are capped so a busy wave cannot flood the
 * scene with draw calls.
 */
import * as THREE from 'three';

export interface BurstOpts {
  count?: number;
  color?: number;
  size?: number;
  /** initial horizontal+vertical speed spread */
  speed?: number;
  /** extra upward bias */
  up?: number;
  life?: number;
  gravity?: number;
}

interface Burst {
  points: THREE.Points;
  vel: Float32Array;
  life: number;
  maxLife: number;
  gravity: number;
  material: THREE.PointsMaterial;
}

const MAX_BURSTS = 14;

export class Fx {
  private readonly bursts: Burst[] = [];
  private readonly scene: THREE.Scene;

  constructor(scene: THREE.Scene) {
    this.scene = scene;
  }

  burst(x: number, y: number, z: number, opts: BurstOpts = {}): void {
    const count = Math.max(3, Math.min(40, opts.count ?? 12));
    const speed = opts.speed ?? 1.6;
    const up = opts.up ?? 1.4;
    const life = opts.life ?? 0.7;
    const gravity = opts.gravity ?? 6;

    const positions = new Float32Array(count * 3);
    const vel = new Float32Array(count * 3);
    for (let i = 0; i < count; i++) {
      positions[i * 3] = x + (Math.random() - 0.5) * 0.24;
      positions[i * 3 + 1] = y + Math.random() * 0.18;
      positions[i * 3 + 2] = z + (Math.random() - 0.5) * 0.24;
      const a = Math.random() * Math.PI * 2;
      const r = speed * (0.35 + Math.random() * 0.65);
      vel[i * 3] = Math.cos(a) * r;
      vel[i * 3 + 1] = up * (0.4 + Math.random() * 0.8);
      vel[i * 3 + 2] = Math.sin(a) * r;
    }

    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    const material = new THREE.PointsMaterial({
      color: opts.color ?? 0x9c7a4a,
      size: opts.size ?? 0.11,
      transparent: true,
      opacity: 1,
      depthWrite: false,
      sizeAttenuation: true,
    });
    const points = new THREE.Points(geo, material);
    points.frustumCulled = false;
    this.scene.add(points);

    this.bursts.push({ points, vel, life, maxLife: life, gravity, material });
    while (this.bursts.length > MAX_BURSTS) {
      const old = this.bursts.shift();
      if (old) this.dispose(old);
    }
  }

  /** golden sparkle used when sun is picked up */
  sparkle(x: number, y: number, z: number): void {
    this.burst(x, y, z, { count: 14, color: 0xffe680, size: 0.09, speed: 1.9, up: 2.4, life: 0.55, gravity: 2.5 });
  }

  update(dt: number): void {
    for (let i = this.bursts.length - 1; i >= 0; i--) {
      const b = this.bursts[i];
      b.life -= dt;
      if (b.life <= 0) {
        this.bursts.splice(i, 1);
        this.dispose(b);
        continue;
      }
      const pos = b.points.geometry.getAttribute('position') as THREE.BufferAttribute;
      const arr = pos.array as Float32Array;
      for (let p = 0; p < arr.length; p += 3) {
        b.vel[p + 1] -= b.gravity * dt;
        arr[p] += b.vel[p] * dt;
        arr[p + 1] += b.vel[p + 1] * dt;
        arr[p + 2] += b.vel[p + 2] * dt;
      }
      pos.needsUpdate = true;
      b.material.opacity = Math.max(0, b.life / b.maxLife);
    }
  }

  disposeAll(): void {
    for (const b of this.bursts) this.dispose(b);
    this.bursts.length = 0;
  }

  private dispose(b: Burst): void {
    this.scene.remove(b.points);
    b.points.geometry.dispose();
    b.material.dispose();
  }
}
