import assert from 'node:assert/strict';
import test from 'node:test';

import {
  BACK_YARD,
  COLS,
  FRONT_YARD,
  POOL,
  TILE,
  YARDS,
} from '../src/world/layout.ts';

const yards = [FRONT_YARD, BACK_YARD];

test('grid constants match the lawn extents', () => {
  assert.equal(COLS, 9);
  for (const y of yards) {
    assert.equal(y.cols, COLS);
    assert.ok(Math.abs((y.x1 - y.x0) - y.cols * TILE) < 1e-6, `${y.name} width`);
    assert.ok(Math.abs((y.z1 - y.z0) - y.rows * TILE) < 1e-6, `${y.name} depth`);
  }
});

test('every cell centre maps back to its own indices', () => {
  for (const y of yards) {
    for (let c = 0; c < y.cols; c++) {
      for (let r = 0; r < y.rows; r++) {
        const { x, z } = y.cellCenter(c, r);
        assert.equal(y.colAt(x), c, `${y.name} col ${c}`);
        assert.equal(y.rowAt(z), r, `${y.name} row ${r}`);
        assert.ok(y.inside(x, z), `${y.name} cell ${c},${r} inside`);
      }
    }
  }
});

test('inside rejects points outside the lawn and honours padding', () => {
  const y = FRONT_YARD;
  assert.equal(y.inside(0, 0), true);
  assert.equal(y.inside(y.x0 - 1, 0), false);
  assert.equal(y.inside(0, y.z1 + 1), false);
  assert.equal(y.inside(y.x0 + 0.2, 0, 0.5), false);
});

test('column 0 is the house side on both lawns', () => {
  assert.ok(Math.abs(FRONT_YARD.colX(0) - FRONT_YARD.x0) < TILE, 'front col 0 near x0');
  assert.ok(Math.abs(BACK_YARD.colX(0) - BACK_YARD.x1) < TILE, 'back col 0 near x1');
  assert.ok(Math.abs(FRONT_YARD.colX(8) - FRONT_YARD.x1) < TILE);
  assert.ok(Math.abs(BACK_YARD.colX(8) - BACK_YARD.x0) < TILE);
});

test('zombies walk from the spawn line toward the house', () => {
  for (const y of yards) {
    const dir = y.zombieDir;
    assert.equal(Math.sign(y.goalX - y.spawnX), dir, `${y.name} direction`);
    // the mower line must sit between the spawn and the house
    const mowerAhead = (y.mowerX - y.spawnX) * dir;
    const goalAhead = (y.goalX - y.spawnX) * dir;
    assert.ok(mowerAhead > 0 && mowerAhead < goalAhead, `${y.name} mower before goal`);
  }
});

test('the front lawn is dry, the back lawn has the two pool rows', () => {
  assert.deepEqual([...FRONT_YARD.waterRows], []);
  assert.deepEqual([...BACK_YARD.waterRows], [2, 3]);
  for (let r = 0; r < BACK_YARD.rows; r++) {
    assert.equal(BACK_YARD.isWaterRow(r), r === 2 || r === 3);
  }
});

test('the pool surface sits inside the back lawn', () => {
  assert.ok(POOL.x0 > BACK_YARD.x0 && POOL.x1 < BACK_YARD.x1);
  assert.ok(POOL.z0 > BACK_YARD.z0 && POOL.z1 < BACK_YARD.z1);
  assert.ok(POOL.floorY < POOL.wadeY && POOL.wadeY < POOL.surfaceY);
  assert.ok(POOL.surfaceY < 0.02, 'water below the lawn surface');
});

test('the yard registry exposes both lawns', () => {
  assert.equal(YARDS.front, FRONT_YARD);
  assert.equal(YARDS.back, BACK_YARD);
});
