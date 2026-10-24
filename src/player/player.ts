/**
 * First-person gardener. Walks, sprints, jumps, wades through the pool and
 * climbs the stairs on the hand-authored collision world.
 */
import * as THREE from 'three';
import { Collision, EYE_HEIGHT, PLAYER_RADIUS, STEP_HEIGHT } from '../core/collision.ts';
import type { Input } from '../core/input.ts';
import { clamp, damp, TAU } from '../core/mathx.ts';

export type Surface = 'grass' | 'stone' | 'wood' | 'water';

const WALK_SPEED = 2.75;
const SPRINT_SPEED = 4.6;
const ACCEL = 14;
const AIR_ACCEL = 4;
const GRAVITY = 19;
const JUMP_SPEED = 5.15;
const MAX_PITCH = Math.PI / 2 - 0.06;

export class Player {
  /** Feet position. */
  readonly position = new THREE.Vector3(0, 0, 0);
  readonly velocity = new THREE.Vector3();
  yaw = 0;
  pitch = 0;
  onGround = true;
  inWater = false;
  speed = 0;
  sensitivity = 0.0021;

  /** Called when a footstep lands; the game maps it to a sound. */
  onStep: ((surface: Surface) => void) | null = null;
  surfaceAt: (x: number, z: number, y: number) => Surface = () => 'grass';

  private bobPhase = 0;
  private bobAmp = 0;
  private landDip = 0;
  private stepAccum = 0;
  private roll = 0;
  private waterCooldown = 0;

  constructor(
    private readonly camera: THREE.PerspectiveCamera,
    private readonly collision: Collision,
    private readonly input: Input,
  ) {}

  get eye(): THREE.Vector3 {
    return new THREE.Vector3(
      this.position.x,
      this.position.y + EYE_HEIGHT + this.bobOffsetY() + this.landDip,
      this.position.z,
    );
  }

  /** Unit vector the camera is looking along. */
  forward(out = new THREE.Vector3()): THREE.Vector3 {
    const cp = Math.cos(this.pitch);
    return out.set(
      -Math.sin(this.yaw) * cp,
      Math.sin(this.pitch),
      -Math.cos(this.yaw) * cp,
    );
  }

  spawn(x: number, y: number, z: number, yaw: number): void {
    this.position.set(x, y, z);
    this.velocity.set(0, 0, 0);
    this.yaw = yaw;
    this.pitch = 0;
    this.onGround = true;
    this.bobPhase = 0;
    this.landDip = 0;
    this.updateCamera(0);
  }

  update(dt: number): void {
    const input = this.input;

    // --- look ---------------------------------------------------------------
    if (input.locked) {
      this.yaw -= input.dx * this.sensitivity;
      this.pitch -= input.dy * this.sensitivity;
      this.pitch = clamp(this.pitch, -MAX_PITCH, MAX_PITCH);
      this.yaw = ((this.yaw + Math.PI) % TAU + TAU) % TAU - Math.PI;
    }

    // --- desired horizontal velocity ---------------------------------------
    let ix = 0;
    let iz = 0;
    if (input.isDown('KeyW') || input.isDown('ArrowUp')) iz -= 1;
    if (input.isDown('KeyS') || input.isDown('ArrowDown')) iz += 1;
    if (input.isDown('KeyA') || input.isDown('ArrowLeft')) ix -= 1;
    if (input.isDown('KeyD') || input.isDown('ArrowRight')) ix += 1;
    const len = Math.hypot(ix, iz);
    if (len > 0) {
      ix /= len;
      iz /= len;
    }

    const sin = Math.sin(this.yaw);
    const cos = Math.cos(this.yaw);
    // forward = (-sin, -cos), right = (cos, -sin)
    const wishX = ix * cos + iz * sin;
    const wishZ = -ix * sin + iz * cos;

    this.inWater = this.collision.inWater(this.position.x, this.position.z);
    const sprint = input.isDown('ShiftLeft') || input.isDown('ShiftRight');
    const target = (sprint ? SPRINT_SPEED : WALK_SPEED) * (this.inWater ? 0.58 : 1);
    const accel = this.onGround ? ACCEL : AIR_ACCEL;

    this.velocity.x = damp(this.velocity.x, wishX * target, accel, dt);
    this.velocity.z = damp(this.velocity.z, wishZ * target, accel, dt);

    const horizontal = Math.hypot(this.velocity.x, this.velocity.z);
    this.speed = horizontal;

    // --- jump ---------------------------------------------------------------
    if (input.wasPressed('Space') && this.onGround) {
      this.velocity.y = JUMP_SPEED * (this.inWater ? 0.72 : 1);
      this.onGround = false;
    }

    // --- horizontal collision ----------------------------------------------
    const moved = this.collision.slide(
      { x: this.position.x, z: this.position.z },
      this.velocity.x * dt,
      this.velocity.z * dt,
      this.position.y,
      PLAYER_RADIUS,
    );
    const realDx = moved.x - this.position.x;
    const realDz = moved.z - this.position.z;
    this.position.x = moved.x;
    this.position.z = moved.z;
    if (Math.abs(realDx) < Math.abs(this.velocity.x * dt) * 0.5) this.velocity.x *= 0.4;
    if (Math.abs(realDz) < Math.abs(this.velocity.z * dt) * 0.5) this.velocity.z *= 0.4;

    // --- vertical -----------------------------------------------------------
    this.velocity.y -= GRAVITY * dt;
    const ground = this.collision.groundAt(this.position.x, this.position.z, this.position.y);
    const nextY = this.position.y + this.velocity.y * dt;

    if (ground !== null && nextY <= ground) {
      if (!this.onGround && this.velocity.y < -3.5) {
        this.landDip = -clamp(-this.velocity.y * 0.012, 0, 0.1);
        this.onStep?.(this.inWater ? 'water' : this.surfaceAt(this.position.x, this.position.z, ground));
      }
      this.position.y = ground;
      this.velocity.y = 0;
      this.onGround = true;
    } else if (
      this.onGround &&
      ground !== null &&
      this.position.y > ground &&
      this.position.y - ground < STEP_HEIGHT
    ) {
      // Glue to descending stairs and small ledges instead of hopping down.
      this.position.y = ground;
      this.velocity.y = 0;
    } else {
      this.position.y = nextY;
      this.onGround = false;
    }

    // --- footsteps ----------------------------------------------------------
    if (this.onGround && horizontal > 0.35) {
      this.stepAccum += horizontal * dt;
      const stride = this.inWater ? 0.85 : sprint ? 1.15 : 0.95;
      if (this.stepAccum >= stride) {
        this.stepAccum = 0;
        const surface = this.inWater ? 'water' : this.surfaceAt(this.position.x, this.position.z, this.position.y);
        this.onStep?.(surface);
        if (this.inWater && this.waterCooldown <= 0) {
          this.waterCooldown = 0.35;
        }
      }
    } else {
      this.stepAccum = Math.min(this.stepAccum, 0.6);
    }
    this.waterCooldown = Math.max(0, this.waterCooldown - dt);

    // --- camera feel --------------------------------------------------------
    this.bobAmp = damp(this.bobAmp, this.onGround && horizontal > 0.3 ? 1 : 0, 9, dt);
    this.bobPhase += horizontal * dt * (this.inWater ? 1.4 : 2.3);
    this.landDip = damp(this.landDip, 0, 9, dt);
    const strafe = wishX;
    this.roll = damp(this.roll, clamp(-strafe * 0.014, -0.02, 0.02), 6, dt);

    this.updateCamera(dt);
  }

  private bobOffsetY(): number {
    return Math.sin(this.bobPhase * 2) * 0.038 * this.bobAmp;
  }

  private bobOffsetX(): number {
    return Math.cos(this.bobPhase) * 0.03 * this.bobAmp;
  }

  private updateCamera(_dt: number): void {
    const e = this.eye;
    const right = new THREE.Vector3(Math.cos(this.yaw), 0, -Math.sin(this.yaw));
    this.camera.position.copy(e).addScaledVector(right, this.bobOffsetX());
    this.camera.rotation.set(this.pitch, this.yaw, this.roll, 'YXZ');
  }
}
