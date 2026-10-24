/**
 * A one-pass screen grade: the scene is drawn into a half-float target, then a
 * fullscreen quad pushes saturation and contrast up, warms the highlights and
 * darkens the corners. Doing it here rather than with a CSS `filter` keeps the
 * canvas a normal element — a filtered canvas forces an offscreen compositor
 * pass that could come back half-painted (and it did, in headless captures).
 */
import * as THREE from 'three';

const VERT = /* glsl */ `
varying vec2 vUv;
void main() {
  vUv = uv;
  gl_Position = vec4(position.xy, 0.0, 1.0);
}
`;

const FRAG = /* glsl */ `
uniform sampler2D tDiffuse;
uniform float uSaturation;
uniform float uContrast;
uniform float uVignette;
uniform float uWarm;
varying vec2 vUv;

void main() {
  vec3 c = texture2D(tDiffuse, vUv).rgb;

  // contrast around mid grey, in the (already tone-mapped) linear buffer
  c = max(c, 0.0);
  c = (c - 0.2) * uContrast + 0.2;

  float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
  c = mix(vec3(luma), c, uSaturation);

  // warm the light, cool the shade: the two-tone look of the original art
  c *= mix(vec3(1.0), vec3(1.045, 1.0, 0.945), uWarm * smoothstep(0.25, 1.0, luma));
  c *= mix(vec3(1.0), vec3(0.965, 0.995, 1.05), uWarm * (1.0 - smoothstep(0.0, 0.35, luma)));

  float d = distance(vUv, vec2(0.5));
  c *= 1.0 - uVignette * smoothstep(0.36, 1.02, d * 1.28);

  // The scene was rendered into a linear target, so the display transform that
  // a built-in material would get from <colorspace_fragment> has to happen here.
  c = pow(max(c, 0.0), vec3(1.0 / 2.2));

  gl_FragColor = vec4(c, 1.0);
}
`;

export class Grade {
  private readonly target: THREE.WebGLRenderTarget;
  private readonly quadScene = new THREE.Scene();
  private readonly quadCamera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
  private readonly material: THREE.ShaderMaterial;
  private readonly renderer: THREE.WebGLRenderer;

  constructor(renderer: THREE.WebGLRenderer) {
    this.renderer = renderer;
    this.target = new THREE.WebGLRenderTarget(1, 1, {
      type: THREE.HalfFloatType,
      depthBuffer: true,
      stencilBuffer: false,
    });
    this.material = new THREE.ShaderMaterial({
      vertexShader: VERT,
      fragmentShader: FRAG,
      uniforms: {
        tDiffuse: { value: this.target.texture },
        uSaturation: { value: 1.16 },
        uContrast: { value: 1.07 },
        uVignette: { value: 0.28 },
        uWarm: { value: 0.55 },
      },
      depthTest: false,
      depthWrite: false,
    });
    const quad = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), this.material);
    quad.frustumCulled = false;
    this.quadScene.add(quad);
  }

  setSize(width: number, height: number): void {
    const dpr = this.renderer.getPixelRatio();
    this.target.setSize(Math.max(1, Math.round(width * dpr)), Math.max(1, Math.round(height * dpr)));
  }

  render(scene: THREE.Scene, camera: THREE.Camera): void {
    this.renderer.setRenderTarget(this.target);
    this.renderer.render(scene, camera);
    this.renderer.setRenderTarget(null);
    this.renderer.render(this.quadScene, this.quadCamera);
  }
}
