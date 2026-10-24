import assert from 'node:assert/strict';
import test from 'node:test';
import * as THREE from 'three';

import { Fx } from '../src/game/fx.ts';

test('a burst adds one Points object and drops it when it expires', () => {
  const scene = new THREE.Scene();
  const fx = new Fx(scene);
  fx.burst(1, 2, 3, { count: 8, life: 0.5 });
  assert.equal(scene.children.length, 1);
  const points = scene.children[0] as THREE.Points;
  const pos = points.geometry.getAttribute('position') as THREE.BufferAttribute;
  assert.equal(pos.count, 8);

  // particles start around the requested point
  assert.ok(Math.abs(pos.getX(0) - 1) < 0.3);
  assert.ok(Math.abs(pos.getZ(0) - 3) < 0.3);

  const before = pos.getY(0);
  fx.update(0.1);
  assert.ok(pos.getY(0) > before, 'particles are thrown upwards');

  fx.update(1);
  assert.equal(scene.children.length, 0, 'expired bursts are removed');
});

test('sparkle is a shorter, brighter burst than the default', () => {
  const scene = new THREE.Scene();
  const fx = new Fx(scene);
  fx.sparkle(0, 1, 0);
  const points = scene.children[0] as THREE.Points;
  const mat = points.material as THREE.PointsMaterial;
  assert.ok(mat.transparent);
  assert.ok(mat.opacity === 1);
  fx.disposeAll();
  assert.equal(scene.children.length, 0);
});

test('concurrent bursts are capped', () => {
  const scene = new THREE.Scene();
  const fx = new Fx(scene);
  for (let i = 0; i < 40; i++) fx.burst(0, 0, 0, { count: 4, life: 5 });
  assert.ok(scene.children.length <= 14, `capped at 14, got ${scene.children.length}`);
  fx.disposeAll();
  assert.equal(scene.children.length, 0);
});
