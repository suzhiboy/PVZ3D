import assert from 'node:assert/strict';
import test from 'node:test';

import { LEVELS, PLANT_DEFS, ZOMBIE_DEFS, levelById } from '../src/game/types.ts';
import { YARDS } from '../src/world/layout.ts';

test('level ids are unique and resolvable', () => {
  const ids = LEVELS.map((l) => l.id);
  assert.equal(new Set(ids).size, ids.length);
  for (const id of ids) assert.equal(levelById(id).id, id);
  assert.equal(levelById('does-not-exist').id, LEVELS[0].id);
});

test('levels start with enough sun for a first plant', () => {
  for (const level of LEVELS) {
    const cheapest = Math.min(...level.seeds.map((s) => PLANT_DEFS[s].cost));
    assert.ok(level.sunStart >= cheapest, `${level.id} can afford ${cheapest}`);
    assert.ok(level.skySun > 0, `${level.id} drops sky sun`);
  }
});

test('every seed is a real plant with a cost', () => {
  for (const level of LEVELS) {
    assert.ok(level.seeds.length > 0, `${level.id} has seeds`);
    assert.equal(new Set(level.seeds).size, level.seeds.length, `${level.id} seeds unique`);
    for (const kind of level.seeds) {
      assert.ok(PLANT_DEFS[kind], `${level.id} knows ${kind}`);
      assert.ok(PLANT_DEFS[kind].cost > 0);
      assert.ok(PLANT_DEFS[kind].recharge > 0);
    }
  }
});

test('waves arrive in order and end the level', () => {
  for (const level of LEVELS) {
    assert.ok(level.waves.length >= 3, `${level.id} has several waves`);
    let previous = -1;
    for (const w of level.waves) {
      assert.ok(w.at > previous, `${level.id} wave order at ${w.at}`);
      previous = w.at;
      assert.ok(w.spawns.length > 0, `${level.id} wave ${w.at} spawns something`);
    }
  }
});

test('spawns reference real zombies and stay inside the lawn', () => {
  for (const level of LEVELS) {
    const yard = YARDS[level.yard];
    for (const w of level.waves) {
      for (const spawn of w.spawns) {
        assert.ok(ZOMBIE_DEFS[spawn.kind], `${level.id} spawns ${spawn.kind}`);
        if (spawn.lane !== undefined) {
          assert.ok(spawn.lane >= 0 && spawn.lane < yard.rows, `${level.id} lane ${spawn.lane}`);
        }
        assert.ok((spawn.count ?? 1) >= 1);
      }
    }
  }
});

test('the pool level offers lily pads, dry levels do not need them', () => {
  const pool = LEVELS.find((l) => l.yard === 'back');
  assert.ok(pool, 'a pool level exists');
  assert.ok(pool?.seeds.includes('lilypad'), 'the pool level sells lily pads');
  for (const level of LEVELS) {
    if (level.yard === 'front') assert.ok(!level.seeds.includes('lilypad'));
  }
});

test('the pool level is reachable from the front levels', () => {
  assert.ok(LEVELS.length >= 3);
  assert.deepEqual(
    LEVELS.map((l) => l.yard),
    ['front', 'front', 'back'],
  );
});
