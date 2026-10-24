import assert from 'node:assert/strict';
import test from 'node:test';

import {
  Collision,
  EYE_HEIGHT,
  PLAYER_RADIUS,
  STEP_HEIGHT,
  floorHeight,
} from '../src/core/collision.ts';

test('groundAt picks the floor under the feet', () => {
  const col = new Collision();
  col.addFloor(-5, 5, -5, 5, 0, 'lawn');
  assert.equal(col.groundAt(0, 0, 0), 0);
  assert.equal(col.groundAt(9, 0, 0), null);
});

test('groundAt ignores floors above the step allowance', () => {
  const col = new Collision();
  col.addFloor(-5, 5, -5, 5, 0);
  col.addFloor(-2, 2, -2, 2, 3.2, 'roof');
  assert.equal(col.groundAt(0, 0, 0), 0);
  // standing on the roof, the same query returns the roof
  assert.equal(col.groundAt(0, 0, 3.2), 3.2);
});

test('a floor within the step height can be climbed', () => {
  const col = new Collision();
  col.addFloor(0, 2, 0, 2, 0);
  col.addFloor(2, 4, 0, 2, STEP_HEIGHT - 0.01);
  assert.equal(col.groundAt(2.5, 1, 0), STEP_HEIGHT - 0.01);
});

test('ramps interpolate between the two heights', () => {
  const col = new Collision();
  const f = col.addRamp(0, 2, 0, 1, 0, 4, 'x', 'stairs');
  assert.equal(floorHeight(f, 0, 0.5), 0);
  assert.equal(floorHeight(f, 2, 0.5), 4);
  assert.equal(floorHeight(f, 1, 0.5), 2);

  const g = col.addRamp(0, 1, 0, 2, 1, 3, 'z');
  assert.equal(floorHeight(g, 0.5, 0), 1);
  assert.equal(floorHeight(g, 0.5, 2), 3);
});

test('walls only block inside the vertical span of the body', () => {
  const col = new Collision();
  col.addWall(-1, 1, -1, 1, 1.2, 2.0);
  assert.equal(col.blocked(0, 0, 0), true, 'wall at chest height blocks');

  col.walls.length = 0;
  col.addWall(-1, 1, -1, 1, 0, 0.4); // a low slab
  assert.equal(col.blocked(0, 0, 0), false, 'slabs below the step are walkable');

  col.walls.length = 0;
  col.addWall(-1, 1, -1, 1, 3.4, 4.0); // ceiling
  assert.equal(col.blocked(0, 0, 0), false, 'geometry above the head is free');
  assert.equal(col.blocked(0, 0, 3.4), true, 'but blocks once you stand on it');
});

test('blocked respects the cylinder radius', () => {
  const col = new Collision();
  col.addWall(1, 2, -1, 1, 0, 2);
  assert.equal(col.blocked(1 - PLAYER_RADIUS - 0.01, 0, 0), false);
  assert.equal(col.blocked(1 - PLAYER_RADIUS + 0.01, 0, 0), true);
});

test('slide stops before a wall instead of tunnelling', () => {
  const col = new Collision();
  col.addWall(1, 2, -5, 5, 0, 2);
  const p = col.slide({ x: 0, z: 0 }, 1.4, 0, 0);
  assert.ok(p.x < 1, `blocked before the wall (x=${p.x})`);
  assert.ok(p.x > 0.5, `but still moved (x=${p.x})`);
  // sliding along the wall keeps the z motion
  const q = col.slide({ x: 1 - PLAYER_RADIUS - 0.02, z: 0 }, 0.3, 0.5, 0);
  assert.ok(Math.abs(q.z - 0.5) < 1e-9, 'z motion survives');
  assert.ok(q.x < 1, 'x stays out of the wall');
});

test('water rects report containment', () => {
  const col = new Collision();
  col.addWater({ x0: -1, x1: 1, z0: -1, z1: 1 });
  assert.equal(col.inWater(0, 0), true);
  assert.equal(col.inWater(1.5, 0), false);
});

test('eye height sits below the collision height', () => {
  assert.ok(EYE_HEIGHT < 1.75);
});
