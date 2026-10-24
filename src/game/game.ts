/**
 * The match: lawn grid, plants, zombies, peas, suns, mowers and waves.
 *
 * The whole level runs off the fixed 60 Hz step that `main.ts` feeds in, so the
 * simulation is deterministic and headless scenarios can fast-forward it.
 */
import * as THREE from 'three';
import type { World } from '../world/world.ts';
import type { Player } from '../player/player.ts';
import { BACK_YARD, FRONT_YARD, POOL, type Yard } from '../world/layout.ts';
import { PLANT_DEFS, ZOMBIE_DEFS, type LevelDef, type PlantDef, type PlantKind, type WaveDef, type ZombieKind } from './types.ts';
import { buildPlantModel, buildZombieModel, type ZombieModel } from './models.ts';
import { Fx } from './fx.ts';
import { audio } from '../core/audio.ts';
import { getAssets } from '../core/materials.ts';

export type GameState = 'playing' | 'won' | 'lost';

export interface SeedSlot {
  kind: PlantKind;
  def: PlantDef;
  ready: boolean;
  /** 1 = just used, 0 = ready */
  cooldown01: number;
  affordable: boolean;
  selected: boolean;
}

export interface HudData {
  sun: number;
  seeds: SeedSlot[];
  levelName: string;
  levelSubtitle: string;
  waveLabel: string;
  progress: number;
  zombiesAlive: number;
  zombiesLeft: number;
  state: GameState;
  hint: string;
  selectedName: string;
  aimValid: boolean;
  hasAim: boolean;
}

interface Plant {
  kind: PlantKind;
  def: PlantDef;
  c: number;
  r: number;
  x: number;
  z: number;
  hp: number;
  maxHp: number;
  timer: number;
  age: number;
  armed: boolean;
  chewing: number;
  group: THREE.Group;
  dead: boolean;
}

interface Zombie {
  kind: ZombieKind;
  hp: number;
  maxHp: number;
  x: number;
  z: number;
  r: number;
  speed: number;
  dps: number;
  model: ZombieModel;
  phase: number;
  eatX: number | null;
  frozen: number;
  dying: number;
  dead: boolean;
}

interface Pea {
  x: number;
  z: number;
  y: number;
  r: number;
  dir: number;
  damage: number;
  freeze: boolean;
  mesh: THREE.Mesh;
  dead: boolean;
}

interface Sun {
  x: number;
  y: number;
  z: number;
  vy: number;
  landed: boolean;
  life: number;
  value: number;
  group: THREE.Group;
  collected: boolean;
}

interface Mower {
  r: number;
  x: number;
  z: number;
  active: boolean;
  spent: boolean;
  group: THREE.Group;
}

const PLANT_Y = 0.02;
const SUN_AUTO_RADIUS = 1.5;
const ZOMBIE_HIT_W = 0.45;

function key(c: number, r: number): string {
  return `${c},${r}`;
}

export class Game {
  readonly level: LevelDef;
  readonly yard: Yard;
  state: GameState = 'playing';
  sun: number;
  selected: PlantKind | null = null;

  private readonly scene: THREE.Scene;
  private readonly player: Player;
  private readonly camera: THREE.PerspectiveCamera;

  private plants = new Map<string, Plant>();
  /** lily pads: permanent cell fixtures that let land plants stand on water */
  private pads = new Map<string, Plant>();
  private zombies: Zombie[] = [];
  private peas: Pea[] = [];
  private suns: Sun[] = [];
  private mowers: Mower[] = [];

  private cooldown = new Map<PlantKind, number>();
  private time = 0;
  private spawnQueue: { t: number; kind: ZombieKind; lane: number; wave: number }[] = [];
  private waveLabel = '';
  private waveIndex = 0;
  private skyTimer = 0;

  private highlight: THREE.Mesh;
  private readonly fx: Fx;
  private ghost: THREE.Group | null = null;
  private aimCell: { c: number; r: number } | null = null;
  private aimOk = false;

  private cameraDir = new THREE.Vector3();
  private groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), -0.02);
  private tmpV = new THREE.Vector3();
  private shotMode: boolean;

  constructor(world: World, player: Player, camera: THREE.PerspectiveCamera, level: LevelDef, shotMode = false) {
    this.scene = world.scene;
    this.player = player;
    this.camera = camera;
    this.level = level;
    this.shotMode = shotMode;
    this.yard = level.yard === 'back' ? BACK_YARD : FRONT_YARD;
    this.sun = level.sunStart;

    const hlGeo = new THREE.PlaneGeometry(1.5, 1.5);
    hlGeo.rotateX(-Math.PI / 2);
    this.highlight = new THREE.Mesh(
      hlGeo,
      new THREE.MeshBasicMaterial({ color: 0x8dff6a, transparent: true, opacity: 0.42, depthWrite: false }),
    );
    this.highlight.visible = false;
    this.highlight.renderOrder = 4;
    this.scene.add(this.highlight);

    this.buildMowers();
    this.buildQueue();
    this.fx = new Fx(this.scene);
    this.skyTimer = 5;
  }

  // -------------------------------------------------------------------------
  // setup
  // -------------------------------------------------------------------------

  private buildMowers(): void {
    const mat = new THREE.MeshStandardMaterial({ color: 0xc0392b, roughness: 0.55, metalness: 0.15 });
    const dark = new THREE.MeshStandardMaterial({ color: 0x2f3338, roughness: 0.8 });
    for (let r = 0; r < this.yard.rows; r++) {
      if (this.yard.isWaterRow(r)) continue;
      const g = new THREE.Group();
      const body = new THREE.Mesh(new THREE.BoxGeometry(0.7, 0.3, 0.56), mat);
      body.position.y = 0.28;
      body.castShadow = true;
      g.add(body);
      const deck = new THREE.Mesh(new THREE.BoxGeometry(0.44, 0.16, 0.44), mat);
      deck.position.set(-0.08, 0.48, 0);
      g.add(deck);
      const bar = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.06, 0.5), dark);
      bar.position.set(0.36, 0.56, 0);
      g.add(bar);
      for (const dz of [-0.24, 0.24]) {
        for (const dx of [-0.22, 0.22]) {
          const wheel = new THREE.Mesh(new THREE.CylinderGeometry(0.16, 0.16, 0.1, 12), dark);
          wheel.rotation.x = Math.PI / 2;
          wheel.position.set(dx, 0.16, dz);
          g.add(wheel);
        }
      }
      const x = this.yard.mowerX;
      const z = this.yard.rowZ(r);
      g.position.set(x, 0, z);
      g.rotation.y = this.yard.zombieDir > 0 ? Math.PI : 0;
      this.scene.add(g);
      this.mowers.push({ r, x, z, active: false, spent: false, group: g });
    }
  }

  private buildQueue(): void {
    const q: { t: number; kind: ZombieKind; lane: number; wave: number }[] = [];
    const waves: WaveDef[] = this.level.waves;
    for (let wi = 0; wi < waves.length; wi++) {
      const w = waves[wi];
      let slot = 0;
      for (const sp of w.spawns) {
        const count = sp.count ?? 1;
        const gap = sp.gap ?? 2.5;
        for (let i = 0; i < count; i++) {
          q.push({
            t: w.at + i * gap + (sp.lane === undefined ? slot++ * 0.4 : 0),
            kind: sp.kind,
            lane: sp.lane ?? Math.floor(Math.random() * this.yard.rows),
            wave: wi,
          });
        }
      }
    }
    q.sort((a, b) => a.t - b.t);
    this.spawnQueue = q;
  }

  // -------------------------------------------------------------------------
  // player interaction
  // -------------------------------------------------------------------------

  /** Which lawn cell the crosshair points at, if any. */
  aim(): { c: number; r: number } | null {
    this.camera.getWorldDirection(this.cameraDir);
    if (this.cameraDir.y > -0.02) return null;
    this.camera.getWorldPosition(this.tmpV);
    const denom = this.cameraDir.y;
    const t = (this.groundPlane.constant * -1 - this.tmpV.y) / denom;
    if (!Number.isFinite(t) || t < 0 || t > 14) return null;
    const x = this.tmpV.x + this.cameraDir.x * t;
    const z = this.tmpV.z + this.cameraDir.z * t;
    if (!this.yard.inside(x, z, -0.05)) return null;
    const c = this.yard.colAt(x);
    const r = this.yard.rowAt(z);
    if (c < 0 || c >= this.yard.cols || r < 0 || r >= this.yard.rows) return null;
    return { c, r };
  }

  selectSeed(kind: PlantKind | null): void {
    if (kind && !this.level.seeds.includes(kind)) kind = null;
    this.selected = kind;
    if (kind) {
      const cd = this.cooldown.get(kind) ?? 0;
      if (cd > 0.01 || this.sun < PLANT_DEFS[kind].cost) {
        audio.play('deny', 0.5);
        return;
      }
      audio.play('select', 0.7);
      this.attachGhost(kind);
    } else {
      this.attachGhost(null);
    }
  }

  private attachGhost(kind: PlantKind | null): void {
    if (this.ghost) {
      this.scene.remove(this.ghost);
      this.ghost = null;
    }
    if (!kind) return;
    const g = buildPlantModel(kind);
    g.traverse((o) => {
      const m = (o as THREE.Mesh).material as THREE.Material | undefined;
      if (m) {
        m.transparent = true;
        m.opacity = 0.55;
        m.depthWrite = false;
      }
    });
    g.visible = false;
    this.ghost = g;
    this.scene.add(g);
  }

  private canPlant(c: number, r: number, kind: PlantKind): boolean {
    if (!this.yard.inside(this.yard.colX(c), this.yard.rowZ(r), -0.1)) return false;
    const def = PLANT_DEFS[kind];
    const water = this.yard.isWaterRow(r);
    const k = key(c, r);
    if (def.water) {
      // lily pads need open water
      if (!water || this.plants.has(k) || this.pads.has(k)) return false;
    } else if (water && !this.pads.has(k)) {
      // land plants only stand on a lily pad
      return false;
    } else if (this.plants.has(k)) {
      return false;
    }
    const cost = def.cost;
    if (this.sun < cost) return false;
    if ((this.cooldown.get(kind) ?? 0) > 0.01) return false;
    return true;
  }

  /** Height a plant or its preview sits at in the given cell. */
  private plantYAt(c: number, r: number): number {
    if (!this.yard.isWaterRow(r)) return PLANT_Y;
    return POOL.surfaceY + (this.pads.has(key(c, r)) ? 0.07 : 0.02);
  }

  plantAt(c: number, r: number, kind: PlantKind): boolean {
    if (!this.canPlant(c, r, kind)) {
      audio.play('deny', 0.5);
      return false;
    }
    const def = PLANT_DEFS[kind];
    this.sun -= def.cost;
    this.cooldown.set(kind, def.recharge);
    const { x, z } = this.yard.cellCenter(c, r);
    const group = buildPlantModel(kind);
    group.position.set(x, this.plantYAt(c, r), z);
    group.rotation.y = this.yard.zombieDir > 0 ? Math.PI : 0;
    this.scene.add(group);
    const plant: Plant = {
      kind,
      def,
      c,
      r,
      x,
      z,
      hp: def.hp,
      maxHp: def.hp,
      timer: kind === 'sunflower' ? 6 : 0,
      age: 0,
      armed: kind !== 'potatomine',
      chewing: 0,
      group,
      dead: false,
    };
    if (def.water) this.pads.set(key(c, r), plant);
    else this.plants.set(key(c, r), plant);
    this.fx.burst(x, this.plantYAt(c, r) + 0.05, z, {
      count: 12,
      color: 0x8a6a44,
      size: 0.1,
      speed: 1.5,
      up: 1.7,
      life: 0.55,
      gravity: 7,
    });
    audio.play('plant', 0.8);
    if (kind === 'cherrybomb') audio.play('groan', 0.5);
    return true;
  }

  /** plants the currently selected seed at the aimed cell */
  plantHere(): boolean {
    if (!this.selected || !this.aimCell) return false;
    return this.plantAt(this.aimCell.c, this.aimCell.r, this.selected);
  }

  digHere(): boolean {
    if (!this.aimCell) return false;
    const k = key(this.aimCell.c, this.aimCell.r);
    const p = this.plants.get(k);
    if (p) {
      this.removePlant(p, false);
      audio.play('hit', 0.6);
      return true;
    }
    const pad = this.pads.get(k);
    if (pad) {
      this.pads.delete(k);
      this.scene.remove(pad.group);
      audio.play('hit', 0.6);
      return true;
    }
    return false;
  }

  /** Collect the sun the player is looking at (or standing on). */
  interact(): boolean {
    const best = this.sunInReach();
    if (!best) {
      audio.play('deny', 0.35);
      return false;
    }
    this.collect(best);
    return true;
  }

  private sunInReach(): Sun | null {
    let best: Sun | null = null;
    let bestScore = Infinity;
    this.camera.getWorldPosition(this.tmpV);
    this.camera.getWorldDirection(this.cameraDir);
    for (const s of this.suns) {
      if (s.collected) continue;
      const dx = s.x - this.player.position.x;
      const dz = s.z - this.player.position.z;
      if (dx * dx + dz * dz < SUN_AUTO_RADIUS * SUN_AUTO_RADIUS) return s;
      const vx = s.x - this.tmpV.x;
      const vy = s.y + 0.25 - this.tmpV.y;
      const vz = s.z - this.tmpV.z;
      const dist = Math.hypot(vx, vy, vz);
      if (dist > 9) continue;
      const dot = (vx * this.cameraDir.x + vy * this.cameraDir.y + vz * this.cameraDir.z) / dist;
      if (dot < 0.86) continue;
      if (dist < bestScore) {
        bestScore = dist;
        best = s;
      }
    }
    return best;
  }

  private collect(s: Sun): void {
    s.collected = true;
    this.sun += s.value;
    audio.play('sun', 0.7);
    this.fx.sparkle(s.x, s.y + 0.1, s.z);
    this.scene.remove(s.group);
  }

  // -------------------------------------------------------------------------
  // simulation
  // -------------------------------------------------------------------------

  update(dt: number): void {
    this.fx.update(dt);
    if (this.state !== 'playing') {
      this.updateVisuals(dt, true);
      return;
    }
    this.time += dt;

    this.updateAim();
    for (const [k, v] of this.cooldown) {
      const next = v - dt;
      if (next <= 0) this.cooldown.delete(k);
      else this.cooldown.set(k, next);
    }
    this.spawnWaves();
    this.updatePlants(dt);
    this.updateZombies(dt);
    this.updatePeas(dt);
    this.updateMowers(dt);
    this.updateSuns(dt);
    this.updateVisuals(dt, false);
    this.checkEnd();
  }

  private updateAim(): void {
    this.aimCell = this.aim();
    if (this.selected && this.aimCell) {
      this.aimOk = this.canPlant(this.aimCell.c, this.aimCell.r, this.selected);
      const { x, z } = this.yard.cellCenter(this.aimCell.c, this.aimCell.r);
      this.highlight.position.set(x, 0.06, z);
      this.highlight.visible = true;
      (this.highlight.material as THREE.MeshBasicMaterial).color.setHex(this.aimOk ? 0x8dff6a : 0xff6a5a);
      if (this.ghost) {
        this.ghost.visible = true;
        this.ghost.position.set(x, this.plantYAt(this.aimCell.c, this.aimCell.r) + (this.aimOk ? 0 : 0.02), z);
      }
    } else {
      this.aimOk = false;
      this.highlight.visible = false;
      if (this.ghost) this.ghost.visible = false;
    }
  }

  private spawnWaves(): void {
    while (this.spawnQueue.length > 0 && this.spawnQueue[0].t <= this.time) {
      const s = this.spawnQueue.shift();
      if (!s) break;
      this.spawnZombie(s.kind, s.lane);
      const w = this.level.waves[s.wave];
      if (w && w.label && this.waveIndex <= s.wave) {
        this.waveLabel = w.label;
        this.waveIndex = s.wave + 1;
      }
    }
  }

  private spawnZombie(kind: ZombieKind, lane: number): void {
    const def = ZOMBIE_DEFS[kind];
    const model = buildZombieModel(kind);
    const z = this.yard.rowZ(lane);
    const x = this.yard.spawnX;
    const jitter = (Math.random() - 0.5) * 1.2;
    model.group.position.set(x, 0, z + jitter * 0.15);
    model.group.rotation.y = this.yard.zombieDir > 0 ? 0 : Math.PI;
    this.scene.add(model.group);
    this.zombies.push({
      kind,
      hp: def.hp,
      maxHp: def.hp,
      x,
      z: z + jitter * 0.15,
      r: lane,
      speed: def.speed * (0.92 + Math.random() * 0.16),
      dps: def.dps,
      model,
      phase: Math.random() * 6,
      eatX: null,
      frozen: 0,
      dying: 0,
      dead: false,
    });
    audio.play('groan', 0.45);
  }

  private updatePlants(dt: number): void {
    for (const p of this.plants.values()) {
      if (p.dead) continue;
      p.age += dt;
      if (p.chewing > 0) p.chewing -= dt;
      switch (p.kind) {
        case 'sunflower':
          p.timer -= dt;
          if (p.timer <= 0) {
            p.timer = 9.5;
            this.dropSun(p.x + (Math.random() - 0.5) * 0.3, p.z + (Math.random() - 0.5) * 0.3, p.x, 0.35, true);
          }
          break;
        case 'peashooter':
        case 'snowpea':
        case 'repeater':
        case 'threepeater': {
          const rows: number[] = p.kind === 'threepeater' ? [p.r - 1, p.r, p.r + 1] : [p.r];
          let target = false;
          for (const rr of rows) {
            if (rr < 0 || rr >= this.yard.rows) continue;
            if (this.laneHasZombie(rr, p.x)) {
              target = true;
              break;
            }
          }
          if (!target) {
            p.timer = Math.min(p.timer, 0.25);
            break;
          }
          p.timer -= dt;
          if (p.timer <= 0) {
            const cad = p.def.cadence ?? 1.4;
            p.timer = cad;
            const shots = p.kind === 'repeater' ? 2 : 1;
            for (let i = 0; i < shots; i++) {
              for (const rr of rows) {
                if (rr < 0 || rr >= this.yard.rows) continue;
                this.firePea(p.x + 0.45, this.yard.rowZ(rr), rr, p.def.shot ?? 25, p.kind === 'snowpea', i * 0.09);
              }
            }
            audio.play('shoot', 0.35);
          }
          break;
        }
        case 'potatomine':
          if (!p.armed && p.age > 8) {
            p.armed = true;
            audio.play('select', 0.4);
          }
          if (p.armed) {
            const z = this.zombieNear(p.x, p.z, 0.85);
            if (z) {
              this.explode(p.x, p.z, 1.3, 1800);
              this.removePlant(p, true);
            }
          }
          break;
        case 'cherrybomb':
          if (p.age > 1.1) {
            this.explode(p.x, p.z, 2.4, 1800);
            this.removePlant(p, true);
          }
          break;
        case 'chomper':
          if (p.chewing > 0) break;
          {
            const z = this.zombieNear(p.x, p.z, 1.1);
            if (z) {
              this.killZombie(z, true);
              p.chewing = 18;
              audio.play('chomp', 0.8);
            }
          }
          break;
        default:
          break;
      }
    }
  }

  private laneHasZombie(r: number, fromX: number): boolean {
    for (const z of this.zombies) {
      if (z.dead || z.r !== r) continue;
      const ahead = (z.x - fromX) * this.attackDir();
      if (ahead > -0.2) return true;
    }
    return false;
  }

  private attackDir(): number {
    // peas fly away from the house: opposite of the zombies' walking direction
    return -this.yard.zombieDir;
  }

  private zombieNear(x: number, z: number, radius: number): Zombie | null {
    for (const zb of this.zombies) {
      if (zb.dead) continue;
      if (Math.abs(zb.z - z) > 0.9) continue;
      if (Math.abs(zb.x - x) <= radius) return zb;
    }
    return null;
  }

  private firePea(x: number, z: number, r: number, damage: number, freeze: boolean, delay: number): void {
    const geo = new THREE.SphereGeometry(freeze ? 0.11 : 0.1, 10, 8);
    const mat = new THREE.MeshStandardMaterial({
      color: freeze ? 0xa8e4f5 : 0x7fd44f,
      roughness: 0.45,
      emissive: freeze ? 0x2a6a80 : 0x1d4a12,
      emissiveIntensity: 0.35,
    });
    const mesh = new THREE.Mesh(geo, mat);
    mesh.position.set(x, 0.86, z);
    this.scene.add(mesh);
    this.peas.push({ x, z, y: 0.86, r, dir: this.attackDir(), damage, freeze, mesh, dead: false });
    void delay;
  }

  private updatePeas(dt: number): void {
    for (const p of this.peas) {
      if (p.dead) continue;
      p.x += p.dir * 9.5 * dt;
      p.mesh.position.x = p.x;
      if (!this.yard.inside(p.x, p.z, 0.2) && Math.abs(p.x - this.yard.x1) > 1.2 && Math.abs(p.x - this.yard.x0) > 1.2) {
        this.killPea(p);
        continue;
      }
      for (const z of this.zombies) {
        if (z.dead) continue;
        if (z.r !== p.r) continue;
        if (Math.abs(z.x - p.x) > ZOMBIE_HIT_W) continue;
        this.damageZombie(z, p.damage);
        if (p.freeze) z.frozen = 3.2;
        audio.play('hit', 0.28);
        this.killPea(p);
        break;
      }
    }
    this.peas = this.peas.filter((p) => !p.dead);
  }

  private killPea(p: Pea): void {
    p.dead = true;
    this.scene.remove(p.mesh);
    p.mesh.geometry.dispose();
  }

  private updateZombies(dt: number): void {
    const dir = this.yard.zombieDir;
    for (const z of this.zombies) {
      if (z.dead) continue;
      if (z.dying > 0) {
        z.dying -= dt;
        z.model.group.rotation.x = Math.min(Math.PI / 2.06, (1 - z.dying) * 2.4);
        z.model.group.position.y = Math.max(-0.5, -((1 - z.dying) * 0.6));
        if (z.dying <= 0) this.finishZombie(z);
        continue;
      }
      if (z.frozen > 0) z.frozen -= dt;
      const slowed = z.frozen > 0 ? 0.45 : 1;
      const target = this.plantToEat(z, dir);
      if (target) {
        z.eatX = target.x;
        target.hp -= z.dps * dt;
        z.phase += dt * 9;
        if (target.hp <= 0) this.removePlant(target, true);
        continue;
      }
      z.eatX = null;
      z.x += dir * z.speed * slowed * dt;
      z.phase += dt * (3.4 + z.speed * 2);
      z.model.group.position.x = z.x;
      z.model.group.position.z = z.z;
      const m = z.model;
      const swing = Math.sin(z.phase) * 0.42;
      m.legL.rotation.x = swing;
      m.legR.rotation.x = -swing;
      m.armL.rotation.z = -0.1 + Math.sin(z.phase * 0.5) * 0.09;
      m.armR.rotation.z = -0.1 - Math.sin(z.phase * 0.5) * 0.09;
      m.group.position.y = Math.abs(Math.sin(z.phase)) * 0.035;

      if (dir < 0 ? z.x < this.yard.goalX : z.x > this.yard.goalX) this.breach(z);
    }
    this.zombies = this.zombies.filter((z) => !z.dead);
  }

  private plantToEat(z: Zombie, dir: number): Plant | null {
    let best: Plant | null = null;
    for (const p of this.plants.values()) {
      if (p.dead || p.r !== z.r) continue;
      if (p.kind === 'lilypad') continue;
      const ahead = (p.x - z.x) * dir;
      if (ahead < 0 || ahead > 0.78) continue;
      if (!best || Math.abs(p.x - z.x) < Math.abs(best.x - z.x)) best = p;
    }
    return best;
  }

  private breach(z: Zombie): void {
    const m = this.mowers.find((mm) => mm.r === z.r && !mm.spent && !mm.active);
    if (m) {
      m.active = true;
      audio.play('mower', 0.9);
      return;
    }
    this.state = 'lost';
    audio.play('lose', 1);
    z.x = this.yard.goalX;
  }

  private updateMowers(dt: number): void {
    const dir = this.attackDir();
    for (const m of this.mowers) {
      if (!m.active || m.spent) continue;
      m.x += dir * 11 * dt;
      m.group.position.x = m.x;
      for (const z of this.zombies) {
        if (z.dead || z.r !== m.r) continue;
        if (Math.abs(z.x - m.x) < 0.9) this.killZombie(z, true);
      }
      if (m.x > this.yard.x1 + 2 || m.x < this.yard.x0 - 2) {
        m.spent = true;
        m.group.visible = false;
      }
    }
  }

  private updateSuns(dt: number): void {
    this.skyTimer -= dt;
    if (this.skyTimer <= 0) {
      this.skyTimer = this.level.skySun + Math.random() * 4;
      const c = Math.floor(Math.random() * this.yard.cols);
      const r = Math.floor(Math.random() * this.yard.rows);
      const { x, z } = this.yard.cellCenter(c, r);
      this.dropSun(x, z, x, 8.5, false);
    }
    for (const s of this.suns) {
      if (s.collected) continue;
      if (!s.landed) {
        s.y -= s.vy * dt;
        const ground = 0.32;
        if (s.y <= ground) {
          s.y = ground;
          s.landed = true;
        }
      } else {
        s.life -= dt;
        if (s.life <= 0) {
          s.collected = true;
          this.scene.remove(s.group);
          continue;
        }
      }
      s.group.position.set(s.x, s.y + Math.sin(this.time * 2 + s.x) * 0.04, s.z);
      const dx = s.x - this.player.position.x;
      const dz = s.z - this.player.position.z;
      if (dx * dx + dz * dz < SUN_AUTO_RADIUS * SUN_AUTO_RADIUS && s.y < 2.2) this.collect(s);
    }
    this.suns = this.suns.filter((s) => !s.collected);
  }

  private dropSun(x: number, z: number, fromX: number, y: number, fromPlant: boolean): void {
    const g = new THREE.Group();
    const core = new THREE.Mesh(
      new THREE.IcosahedronGeometry(0.26, 1),
      new THREE.MeshStandardMaterial({ color: 0xffd23f, emissive: 0xffb000, emissiveIntensity: 1.1, roughness: 0.35 }),
    );
    core.castShadow = false;
    g.add(core);
    const halo = new THREE.Sprite(
      new THREE.SpriteMaterial({ map: getAssets().glow, color: 0xffe27a, transparent: true, opacity: 0.75, depthWrite: false }),
    );
    halo.scale.set(1.5, 1.5, 1);
    g.add(halo);
    g.position.set(x, y, z);
    this.scene.add(g);
    const s: Sun = {
      x,
      y,
      z,
      vy: fromPlant ? 0.7 : 1.5,
      landed: false,
      life: 13,
      value: 25,
      group: g,
      collected: false,
    };
    void fromX;
    this.suns.push(s);
  }

  private explode(x: number, z: number, radius: number, damage: number): void {
    audio.play('explode', 1);
    for (const zb of this.zombies) {
      if (zb.dead) continue;
      if (Math.hypot(zb.x - x, zb.z - z) <= radius) this.damageZombie(zb, damage);
    }
    const ring = new THREE.Mesh(
      new THREE.SphereGeometry(radius * 0.75, 16, 12),
      new THREE.MeshBasicMaterial({ color: 0xffd05a, transparent: true, opacity: 0.55, depthWrite: false }),
    );
    ring.position.set(x, 0.6, z);
    this.scene.add(ring);
    const start = performance.now();
    const fade = (): void => {
      const k = (performance.now() - start) / 420;
      if (k >= 1) {
        this.scene.remove(ring);
        ring.geometry.dispose();
        (ring.material as THREE.Material).dispose();
        return;
      }
      ring.scale.setScalar(1 + k * 0.9);
      (ring.material as THREE.MeshBasicMaterial).opacity = 0.55 * (1 - k);
      requestAnimationFrame(fade);
    };
    requestAnimationFrame(fade);
  }

  private damageZombie(z: Zombie, amount: number): void {
    if (z.dead) return;
    z.hp -= amount;
    z.model.group.scale.setScalar(1 + Math.max(0, 0.03));
    if (z.hp <= 0) this.killZombie(z, false);
  }

  private killZombie(z: Zombie, instant: boolean): void {
    if (z.dead) return;
    z.model.group.scale.setScalar(1);
    if (instant) {
      this.finishZombie(z);
      return;
    }
    z.dying = 0.55;
  }

  private finishZombie(z: Zombie): void {
    if (z.dead) return;
    z.dead = true;
    this.fx.burst(z.x, 0.7, z.z, { count: 16, color: 0xb9c69a, size: 0.13, speed: 2.1, up: 1.8, life: 0.75, gravity: 5.5 });
    this.scene.remove(z.model.group);
  }

  private removePlant(p: Plant, killed: boolean): void {
    if (p.dead) return;
    p.dead = true;
    this.plants.delete(key(p.c, p.r));
    this.scene.remove(p.group);
    if (killed) audio.play('chomp', 0.35);
  }

  private updateVisuals(dt: number, frozen: boolean): void {
    void dt;
    if (frozen) return;
    // sunflower heads follow the player a little
    const px = this.player.position.x;
    for (const p of this.plants.values()) {
      if (p.kind !== 'sunflower') continue;
      const head = p.group.children[p.group.children.length - 1];
      if (head) head.rotation.y = THREE.MathUtils.clamp(Math.atan2(0, px - p.x) * 0.2, -0.35, 0.35);
    }
  }

  private checkEnd(): void {
    if (this.state !== 'playing') return;
    if (this.spawnQueue.length === 0 && this.zombies.length === 0 && this.time > 5) {
      this.state = 'won';
      audio.play('win', 1);
    }
  }

  // -------------------------------------------------------------------------
  // hud + automation
  // -------------------------------------------------------------------------

  hud(): HudData {
    const seeds: SeedSlot[] = this.level.seeds.map((kind) => {
      const def = PLANT_DEFS[kind];
      const cd = this.cooldown.get(kind) ?? 0;
      return {
        kind,
        def,
        ready: cd <= 0.01,
        cooldown01: cd > 0 ? Math.min(1, cd / def.recharge) : 0,
        affordable: this.sun >= def.cost,
        selected: this.selected === kind,
      };
    });
    const total = this.level.waves.length;
    const progress = total === 0 ? 0 : Math.min(1, this.waveIndex / total);
    return {
      sun: Math.floor(this.sun),
      seeds,
      levelName: this.level.name,
      levelSubtitle: this.level.subtitle,
      waveLabel: this.waveLabel,
      progress,
      zombiesAlive: this.zombies.filter((z) => !z.dead).length,
      zombiesLeft: this.spawnQueue.length,
      state: this.state,
      hint: this.hintText(),
      selectedName: this.selected ? PLANT_DEFS[this.selected].name : '',
      aimValid: this.aimOk,
      hasAim: this.aimCell !== null,
    };
  }

  private hintText(): string {
    if (this.state === 'won') return '关卡完成！';
    if (this.state === 'lost') return '僵尸进屋了…';
    if (this.selected) {
      if (!this.aimCell) return '看向草地格来放置植物';
      if (!this.aimOk) {
        return this.sun < (PLANT_DEFS[this.selected]?.cost ?? 0) ? '阳光不足' : '这一格不能种';
      }
      return '左键 / E 种下';
    }
    return '1-6 选择植物 · 走近阳光自动收集 · E 收集准星下的阳光';
  }

  snapshot(): Record<string, number | string> {
    return {
      state: this.state,
      sun: Math.floor(this.sun),
      plants: this.plants.size + this.pads.size,
      zombies: this.zombies.filter((z) => !z.dead).length,
      peas: this.peas.length,
      suns: this.suns.length,
      queued: this.spawnQueue.length,
      time: Math.round(this.time * 10) / 10,
      wave: this.waveIndex,
      mowers: this.mowers.filter((m) => !m.spent).length,
      level: this.level.id,
      aim: this.aimCell ? `${this.aimCell.c},${this.aimCell.r}` : '-',
      shot: this.shotMode ? 1 : 0,
    };
  }

  /** debug helper: fill a cell without paying */
  forcePlant(c: number, r: number, kind: PlantKind): void {
    this.sun += PLANT_DEFS[kind].cost;
    this.cooldown.delete(kind);
    this.plantAt(c, r, kind);
  }
}

