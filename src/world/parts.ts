/** Tiny mesh constructors used by every world builder. */
import * as THREE from 'three';

/** Axis-aligned box whose bottom sits at `y` and which is centred on x/z. */
export function boxAt(
  w: number,
  h: number,
  d: number,
  material: THREE.Material,
  x: number,
  y: number,
  z: number,
  cast = true,
  receive = true,
): THREE.Mesh {
  const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), material);
  m.position.set(x, y + h / 2, z);
  m.castShadow = cast;
  m.receiveShadow = receive;
  return m;
}

/** Horizontal quad facing +Y. */
export function planeAt(
  w: number,
  d: number,
  material: THREE.Material,
  x: number,
  y: number,
  z: number,
): THREE.Mesh {
  const g = new THREE.PlaneGeometry(w, d);
  g.rotateX(-Math.PI / 2);
  const m = new THREE.Mesh(g, material);
  m.position.set(x, y, z);
  m.receiveShadow = true;
  return m;
}

export function cylinderAt(
  radiusTop: number,
  radiusBottom: number,
  height: number,
  material: THREE.Material,
  x: number,
  y: number,
  z: number,
  segments = 14,
): THREE.Mesh {
  const m = new THREE.Mesh(
    new THREE.CylinderGeometry(radiusTop, radiusBottom, height, segments),
    material,
  );
  m.position.set(x, y + height / 2, z);
  m.castShadow = true;
  m.receiveShadow = true;
  return m;
}

export function sphereAt(
  radius: number,
  material: THREE.Material,
  x: number,
  y: number,
  z: number,
  segments = 14,
): THREE.Mesh {
  const m = new THREE.Mesh(new THREE.SphereGeometry(radius, segments, Math.max(6, segments / 2)), material);
  m.position.set(x, y, z);
  m.castShadow = true;
  m.receiveShadow = true;
  return m;
}

/** Merge a group's children into one mesh per material to cut draw calls. */
export function group(): THREE.Group {
  return new THREE.Group();
}

export function scaledBoxGeometry(w: number, h: number, d: number, u: number, v: number): THREE.BufferGeometry {
  const g = new THREE.BoxGeometry(w, h, d);
  const uv = g.getAttribute('uv') as THREE.BufferAttribute;
  for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * u, uv.getY(i) * v);
  uv.needsUpdate = true;
  return g;
}
