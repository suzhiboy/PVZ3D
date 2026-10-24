/** Builds the playable scene graph and the collision world that mirrors it. */
import * as THREE from 'three';
import { Collision } from '../core/collision.ts';
import { createEnvironment } from './environment.ts';
import type { Environment } from './environment.ts';
import { buildHouse } from './house.ts';
import { buildTerrain } from './terrain.ts';
import { buildScenery } from './scenery.ts';
import type { HouseResult } from './house.ts';
import type { Terrain } from './terrain.ts';

export interface World {
  scene: THREE.Scene;
  camera: THREE.PerspectiveCamera;
  collision: Collision;
  terrain: Terrain;
  environment: Environment;
  house: HouseResult;
  update(dt: number): void;
}

export function buildWorld(): World {
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(74, 16 / 9, 0.06, 420);
  camera.rotation.order = 'YXZ';

  const env = createEnvironment(scene);
  const collision = new Collision();
  const terrain = buildTerrain(scene, collision);
  const house = buildHouse(scene, collision);
  buildScenery(scene, collision);

  return {
    scene,
    camera,
    collision,
    terrain,
    environment: env,
    house,
    update(dt: number): void {
      env.update(dt);
      terrain.update(dt);
      house.update(dt);
    },
  };
}

