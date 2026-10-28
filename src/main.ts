/** Composition root: renderer, world, player, game rules, HUD, main loop. */
import * as THREE from 'three';
import './ui/style.css';
import { audio } from './core/audio.ts';
import { DebugOverlay, exposeAutomation, flags, markReady } from './core/debug.ts';
import { Input } from './core/input.ts';
import { Loop } from './core/loop.ts';
import { Game } from './game/game.ts';
import { LEVELS, seedCapFor, seedPoolFor, type PlantKind } from './game/types.ts';
import { Player } from './player/player.ts';
import { Grade } from './render/grade.ts';
import { Hud, type PanelInfo, type PanelKind } from './ui/hud.ts';
import { SPAWNS } from './world/layout.ts';
import { buildWorld } from './world/world.ts';

const canvas = document.getElementById('view') as HTMLCanvasElement;
const params = new URLSearchParams(location.search);
const shotParam = params.get('shot');
const shotMode = shotParam !== null;
const shotLimit = shotMode ? Number(shotParam) || Infinity : 0;

const renderer = new THREE.WebGLRenderer({
  canvas,
  antialias: true,
  powerPreference: 'high-performance',
  // headless capture reads the back buffer after the last draw
  preserveDrawingBuffer: shotMode,
});
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
if (shotMode) {
  // static scene: bake the shadow map once instead of every software-rendered frame
  renderer.shadowMap.autoUpdate = false;
  renderer.shadowMap.needsUpdate = true;
}
renderer.toneMapping = THREE.NeutralToneMapping;
renderer.toneMappingExposure = 1.0;
renderer.outputColorSpace = THREE.SRGBColorSpace;

// Saturation, contrast, warm/cool split and the vignette, in one shader pass.
const grade = new Grade(renderer);

const world = buildWorld();
const { scene, camera } = world;

const input = new Input(canvas);
const player = new Player(camera, world.collision, input);
player.spawn(SPAWNS.front.x, SPAWNS.front.y, SPAWNS.front.z, SPAWNS.front.yaw);
player.onStep = (surface) => {
  if (surface === 'water') audio.play('splash', 0.4);
  else audio.play('step', surface === 'stone' ? 1.1 : surface === 'wood' ? 0.85 : 0.7);
};

// A crash must be visible to the screenshot harness instead of a silent blank frame.
function reportError(msg: string): void {
  document.title = msg;
  const boot = document.getElementById('boot');
  if (boot) {
    boot.classList.remove('gone');
    boot.textContent = msg;
  }
}
window.addEventListener('error', (e) => {
  reportError(`ERR ${e.message} @${(e.filename ?? '').split('/').pop()}:${e.lineno}`);
});
window.addEventListener('unhandledrejection', (e) => {
  reportError(`ERR ${String((e as PromiseRejectionEvent).reason)}`);
});

// URL-driven camera placement, used by the screenshot harness.
const at = params.get('at');
if (at) {
  const [ax, az] = at.split(',').map(Number);
  player.spawn(ax, world.collision.highestFloor(ax, az) ?? 0, az, player.yaw);
}
const yawParam = params.get('yaw');
if (yawParam !== null) player.yaw = (Number(yawParam) * Math.PI) / 180;
const pitchParam = params.get('pitch');
if (pitchParam !== null) player.pitch = (Number(pitchParam) * Math.PI) / 180;

// ---------------------------------------------------------------------------
// game + hud
// ---------------------------------------------------------------------------

const levelParam = params.get('level') ?? LEVELS[0].id;
let levelIndex = Math.max(0, LEVELS.findIndex((l) => l.id === levelParam));
const hudRoot = document.getElementById('hud') as HTMLElement;
const hud = new Hud(hudRoot);
let shotInfo: HTMLElement | null = null;
if (shotMode) {
  // self-documenting stills: query + live camera are painted into the frame so a
  // captured PNG can be checked against the scenario that was requested
  shotInfo = document.createElement('div');
  shotInfo.id = 'shotinfo';
  hudRoot.appendChild(shotInfo);
}
const game = new Game(world, player, camera, LEVELS[levelIndex], shotMode);

/** Plants the player may bring into this yard (see `seedPoolFor`). */
function seedPool(): PlantKind[] {
  return seedPoolFor(LEVELS[levelIndex].yard);
}
function seedCap(): number {
  return seedCapFor(LEVELS[levelIndex].yard);
}

/** `?seeds=a,b,c` — replay a hand, and lets the harness capture one. */
function readSeedsParam(): PlantKind[] | null {
  const raw = params.get('seeds');
  if (!raw) return null;
  const pool = seedPool();
  const picked = raw
    .split(',')
    .map((s) => s.trim())
    .filter((s): s is PlantKind => pool.includes(s as PlantKind));
  return picked.length ? [...new Set(picked)].slice(0, seedCap()) : null;
}

let activeSeeds: PlantKind[] = readSeedsParam() ?? LEVELS[levelIndex].seeds.slice();
game.applySeeds(activeSeeds);
hud.buildSeeds(activeSeeds);

let started = shotMode;
let lastState = game.state;

// ---------------------------------------------------------------------------
// level progress + level picker (front yard / backyard)
// ---------------------------------------------------------------------------

const PROGRESS_KEY = 'pvz3d.progress';
const doneLevels = loadProgress();

function loadProgress(): Set<string> {
  try {
    const raw = localStorage.getItem(PROGRESS_KEY);
    if (!raw) return new Set();
    const parsed = JSON.parse(raw) as { done?: unknown };
    return new Set(Array.isArray(parsed.done) ? parsed.done.filter((d): d is string => typeof d === 'string') : []);
  } catch {
    return new Set();
  }
}

function markLevelDone(id: string): void {
  if (doneLevels.has(id)) return;
  doneLevels.add(id);
  try {
    localStorage.setItem(PROGRESS_KEY, JSON.stringify({ done: [...doneLevels] }));
  } catch {
    // storage can be unavailable (private mode); progress is cosmetic
  }
}

function pickLevel(id: string): void {
  const p = new URLSearchParams();
  p.set('level', id);
  location.search = p.toString();
}

function showIntro(): void {
  const lv = LEVELS[levelIndex];
  const final = levelIndex >= LEVELS.length - 1 && doneLevels.has(lv.id);
  hud.showPanel('intro', {
    ...PANELS.intro,
    title: final ? '全部通关！' : lv.name,
    body:
      `${lv.subtitle}\n` +
      'WASD 走动 · 点击画面锁定鼠标转视角 · 1-7 选植物 · ' +
      '准星对准草格按 F（或左键）种下 · E 收阳光 · Q 铲除 · Esc 暂停',
    button: '开始这一关',
  });
  hud.showLevelPicker(
    LEVELS.map((l, i) => ({
      id: l.id,
      name: l.name,
      subtitle: l.subtitle,
      done: doneLevels.has(l.id),
      current: i === levelIndex,
    })),
    pickLevel,
  );
}

function goToLevel(index: number): void {
  const next = LEVELS[index] ?? LEVELS[0];
  const p = new URLSearchParams(location.search);
  p.set('level', next.id);
  p.delete('shot');
  p.delete('warp');
  p.delete('plant');
  p.delete('seeds');
  p.delete('panel');
  location.search = p.toString();
}

/** Pre-battle hand: pick the packets before the zombies show up. */
function openSeedChooser(): void {
  const lv = LEVELS[levelIndex];
  hud.showPanel('intro', {
    title: '选择种子',
    body:
      `${lv.name}：最多带 ${seedCap()} 张种子进场。\n` +
      '阳光有限，先想好开局顺序——数字键 1-7 对应卡槽，F 或左键种下。',
    button: '开战',
    secondary: '返回选关',
  });
  hud.showSeedChooser(seedPool(), activeSeeds, seedCap());
}

function beginBattle(picked: PlantKind[]): void {
  activeSeeds = picked.slice();
  game.applySeeds(activeSeeds);
  hud.buildSeeds(activeSeeds);
  started = true;
  hud.showPanel(null);
  audio.unlock();
  input.requestLock();
}

hud.onSeedsConfirm = (picked) => beginBattle(picked);

hud.onSelect = (kind) => {
  if (!started || game.state !== 'playing') return;
  game.selectSeed(game.selected === kind ? null : kind);
  audio.play('select', 0.5);
};

hud.onPrimary = () => {
  if (!started) {
    // intro -> seed chooser; the chooser's own primary button starts the fight
    openSeedChooser();
    return;
  }
  if (game.state === 'won') {
    const next = levelIndex + 1;
    if (next < LEVELS.length) {
      goToLevel(next);
      return;
    }
    levelIndex = 0;
  }
  goToLevel(levelIndex);
};

hud.onSecondary = () => {
  if (hud.choosingSeeds) showIntro();
  else if (game.state === 'won') goToLevel(levelIndex);
  else if (hud.visiblePanel === 'paused') pickLevel(game.level.id);
};

const PANELS: Record<Exclude<PanelKind, null>, PanelInfo> = {
  intro: {
    title: LEVELS[0].name,
    body: '僵尸要来吃你的脑子了。用 1-6 选植物，按 F 或左键种在脚下的格子里，按 E 收集阳光。',
    button: '开始游戏',
  },
  won: {
    title: '关卡完成！',
    body: '院子守住了，脑袋还在。',
    button: '下一关',
    secondary: '重玩本关',
  },
  lost: {
    title: '僵尸吃掉了你的脑子',
    body: '再试一次吧，这次多带点向日葵。',
    button: '再来一局',
  },
  paused: {
    title: '暂停',
    body: '按 Esc 继续游戏。',
    button: '继续',
    secondary: '选关',
  },
};

if (!shotMode) {
  showIntro();
} else if (params.get('panel') === 'intro') {
  // lets the screenshot harness capture the menu itself
  showIntro();
} else if (params.get('panel') === 'seeds') {
  showIntro();
  openSeedChooser();
}

// Screenshot tooling: pre-simulate `warp` seconds and pre-place plants.
const warp = Number(params.get('warp') ?? 0);
const plantParam = params.get('plant');
if (plantParam) {
  for (const spec of plantParam.split(',')) {
    const [c, r, kind] = spec.split(':');
    if (!kind) continue;
    game.forcePlant(Number(c), Number(r), kind as PlantKind);
  }
}
if (warp > 0) {
  const steps = Math.min(60 * 240, Math.round(warp * 60));
  for (let i = 0; i < steps; i++) game.update(1 / 60);
}
// sync the camera to the requested spawn/look: the loop freezes player movement
// in shot mode, so nothing else would apply yaw/pitch to the camera matrix
player.update(0);

function openPanel(kind: PanelKind, info?: PanelInfo): void {
  hud.showPanel(kind, info);
}

// ---------------------------------------------------------------------------
// loop
// ---------------------------------------------------------------------------

function resize(): void {
  const w = window.innerWidth;
  const h = window.innerHeight;
  renderer.setSize(w, h, false);
  grade.setSize(w, h);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
}
window.addEventListener('resize', resize);
resize();

canvas.addEventListener('pointerdown', () => {
  audio.unlock();
  if (started && game.state === 'playing') input.requestLock();
});

document.addEventListener('pointerlockchange', () => {
  if (!input.locked && started && game.state === 'playing') openPanel('paused', PANELS.paused);
  else if (input.locked) openPanel(null);
});

const overlay = new DebugOverlay(() => {
  const p = player.position;
  return [
    `fps ${loop.fps.toFixed(0)}`,
    `pos ${p.x.toFixed(1)} ${p.y.toFixed(2)} ${p.z.toFixed(1)}`,
    `yaw ${((player.yaw * 180) / Math.PI).toFixed(0)} pitch ${((player.pitch * 180) / Math.PI).toFixed(0)}`,
    `ground ${player.onGround ? 'y' : 'n'} water ${player.inWater ? 'y' : 'n'}`,
    `sun ${game.sun} z ${game.hud().zombiesAlive}`,
    flags.scenario ? `scenario ${flags.scenario}` : '',
  ]
    .filter(Boolean)
    .join('\n');
});

function handleKeys(): void {
  if (!started) {
    if (input.wasPressed('Enter') || input.wasPressed('Space')) hud.pressPrimary();
    return;
  }
  const playing = game.state === 'playing';
  if (playing) {
    for (let i = 0; i < activeSeeds.length; i++) {
      if (input.wasPressed(`Digit${i + 1}`)) {
        const kind = activeSeeds[i];
        game.selectSeed(game.selected === kind ? null : kind);
        audio.play('select', 0.5);
      }
    }
    if (input.wasPressed('KeyE')) game.interact();
    if (input.wasPressed('KeyQ')) game.digHere();
    if (input.wasPressed('KeyF') || (input.locked && input.wasPressed('Mouse0'))) game.plantHere();
    if (input.wheel !== 0 && activeSeeds.length > 0) {
      const i = game.selected ? activeSeeds.indexOf(game.selected) : -1;
      const next = activeSeeds[(i + (input.wheel > 0 ? 1 : activeSeeds.length - 1)) % activeSeeds.length];
      game.selectSeed(next);
    }
  }
}

let framesLeft = shotLimit;

const loop = new Loop(
  (dt) => {
    handleKeys();
    const paused = hud.visiblePanel !== null;
    // shot mode freezes the simulation after the pre-roll so slow software
    // rendering cannot advance the level (and end it) while frames are drawn
    if (started && !paused && !shotMode) {
      player.update(dt);
      game.update(dt);
    }
    world.update(dt);
    overlay.update(dt);
    hud.render(game.hud());
    if (game.state !== lastState) {
      lastState = game.state;
      if (game.state !== 'playing') {
        input.releaseLock();
        if (game.state === 'won') markLevelDone(game.level.id);
        if (!shotMode) {
          const kind = game.state === 'won' ? 'won' : 'lost';
          const finalWin = kind === 'won' && levelIndex >= LEVELS.length - 1;
          openPanel(
            kind,
            finalWin
              ? {
                  ...PANELS.won,
                  title: '全部通关！',
                  body: '前院、后院、泳池都守住了。僵尸再也不敢来这片草坪。',
                  button: '再来一轮',
                }
              : PANELS[kind],
          );
        }
        audio.play(game.state === 'won' ? 'win' : 'lose');
      }
    }
    input.endFrame();
  },
  () => {
    if (shotInfo) {
      // the diagnostic overlay would sit on top of the panel art
      shotInfo.style.display = hud.visiblePanel ? 'none' : 'block';
      const c = camera.position;
      const pp = player.position;
      shotInfo.textContent =
        `cam ${c.x.toFixed(2)},${c.y.toFixed(2)},${c.z.toFixed(2)} yaw ${((player.yaw * 180) / Math.PI).toFixed(0)} ` +
        `feet ${pp.x.toFixed(2)},${pp.y.toFixed(2)},${pp.z.toFixed(2)}\n` +
        `${JSON.stringify(game.snapshot())}\n${decodeURIComponent(location.search)}`;
    }
    grade.render(scene, camera);
    if (shotMode && Number.isFinite(framesLeft) && --framesLeft <= 0) {
      loop.stop();
      const gl = renderer.getContext();
      const w = gl.drawingBufferWidth;
      const h = gl.drawingBufferHeight;
      const px = new Uint8Array(4);
      gl.readPixels(w >> 1, h >> 1, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, px);
      const cam = camera.position;
      document.title = `SHOT ${w}x${h} px=${px[0]},${px[1]},${px[2]} cam=${cam.x.toFixed(1)},${cam.y.toFixed(1)},${cam.z.toFixed(1)} yaw=${((player.yaw * 180) / Math.PI).toFixed(0)} ${JSON.stringify(game.snapshot())}`;
    }
  },
);
loop.start();

const boot = document.getElementById('boot');
if (shotMode) {
  // still-image mode: no fade, no timers, the loop parks after N frames
  boot?.remove();
} else {
  requestAnimationFrame(() => boot?.classList.add('gone'));
  setTimeout(() => boot?.remove(), 1200);
}
markReady();

exposeAutomation({
  player,
  world,
  renderer,
  camera,
  game,
  spawn(label: 'front' | 'back' | 'house' = 'front'): void {
    const s = SPAWNS[label];
    player.spawn(s.x, s.y, s.z, s.yaw);
  },
  look(yaw: number, pitch: number): void {
    player.yaw = yaw;
    player.pitch = pitch;
  },
  teleport(x: number, z: number): void {
    player.spawn(x, world.collision.highestFloor(x, z) ?? 0, z, player.yaw);
  },
  snapshot(): Record<string, number | string> {
    return game.snapshot();
  },
});
