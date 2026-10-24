/**
 * Screenshot harness: boots a throwaway vite dev server, then drives headless
 * Edge with SwiftShader to write one PNG per named camera position.
 *
 *   node tools/shots.mjs            # every shot
 *   node tools/shots.mjs pool house # only those (substring match)
 *   node tools/shots.mjs --dom      # dump the DOM once (runtime-error smoke test)
 *
 * Headless Edge cannot run inside the DSH file sandbox, so this script must be
 * launched from an unconfined shell.
 */
import { spawn } from 'node:child_process';
import { mkdir, readdir, rm, stat } from 'node:fs/promises';
import path from 'node:path';
import { createServer } from 'vite';
const ROOT = process.cwd();
const OUT = path.join(ROOT, '.shots');
const PORT = 5199;
const EDGE = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';

/** name ->camera query. yaw/pitch in degrees, `at` is world x,z. */
const SHOTS = [
  { name: '01-porch', at: '-7.6,-0.55', yaw: -90, pitch: -4, frames: 0 },
  { name: '02-lawn', at: '1.6,0.4', yaw: -104, pitch: -6 },
  { name: '03-house', at: '2.6,3.1', yaw: 88, pitch: 3 },
  { name: '04-street', at: '11.6,0.4', yaw: 92, pitch: 3 },
  { name: '05-backyard', at: '-20.6,3.4', yaw: 96, pitch: -4, level: 'back-1' },
  { name: '06-pool', at: '-25.4,0.0', yaw: 90, pitch: -8, level: 'back-1' },
  { name: '07-back-house', at: '-31.5,-0.2', yaw: -92, pitch: 2, level: 'back-1' },
  { name: '08-living', at: '-9.4,-0.6', yaw: 92, pitch: 0 },
  { name: '09-kitchen', at: '-12.2,3.4', yaw: 78, pitch: -2 },
  { name: '10-upstairs', at: '-12.4,3.9', yaw: 92, pitch: -4 },
  // gameplay shots: pre-planted seeds + fast-forwarded simulation
  {
    name: '11-front-play',
    at: '-5.0,0.2',
    yaw: -92,
    pitch: -9,
    level: 'front-1',
    warp: 46,
    plant: '0:0:sunflower,0:1:sunflower,0:2:sunflower,1:0:peashooter,1:1:peashooter,1:2:peashooter,2:0:wallnut,2:1:peashooter,2:2:peashooter',
  },
  {
    name: '12-front-close',
    at: '1.0,3.4',
    yaw: 78,
    pitch: -8,
    level: 'front-1',
    warp: 30,
    plant: '0:0:sunflower,1:0:peashooter,1:1:potatomine,2:1:peashooter,3:2:sunflower,1:3:wallnut',
  },
  {
    name: '13-back-play',
    at: '-23.4,4.2',
    yaw: -70,
    pitch: -8,
    level: 'back-1',
    warp: 40,
    plant: '0:0:sunflower,0:1:sunflower,0:2:lilypad,0:3:lilypad,1:1:threepeater,1:2:lilypad,2:2:peashooter,3:0:wallnut',
  },
  // close-ups for model review
  {
    name: '14-plant-close',
    at: '-2.4,-2.3',
    yaw: 92,
    pitch: -16,
    level: 'front-1',
    warp: 3,
    plant: '0:1:sunflower,1:1:peashooter,1:2:snowpea,2:1:wallnut,2:2:potatomine,3:1:cherrybomb,4:1:repeater',
  },
  {
    name: '15-zombie-close',
    at: '1.4,0.2',
    yaw: -96,
    pitch: -6,
    level: 'front-1',
    warp: 62,
    plant: '0:0:sunflower,0:1:sunflower,0:2:sunflower',
  },
  {
    // full-level playthrough used as the headless win test (`--dom 16-win`)
    name: '16-win',
    at: '-5.6,0.2',
    yaw: -92,
    pitch: -6,
    level: 'front-1',
    warp: 210,
    plant:
      '0:0:sunflower,0:1:sunflower,0:2:sunflower,0:3:sunflower,0:4:wallnut,' +
      '1:0:peashooter,1:1:peashooter,1:2:peashooter,1:3:peashooter,1:4:peashooter,' +
      '2:0:peashooter,2:1:peashooter,2:2:peashooter,2:3:peashooter,2:4:peashooter',
  },
  {
    // back yard with a planted pool: lily pads first, then plants on top
    name: '17-back-win',
    at: '-32.6,0.2',
    yaw: -88,
    pitch: -8,
    level: 'back-1',
    warp: 285,
    plant:
      '0:0:sunflower,0:1:sunflower,0:4:sunflower,0:5:sunflower,' +
      '1:0:peashooter,1:1:peashooter,1:4:peashooter,1:5:peashooter,' +
      '2:0:peashooter,2:1:peashooter,2:4:peashooter,2:5:peashooter,' +
      '1:2:lilypad,1:3:lilypad,1:2:peashooter,1:3:peashooter,' +
      '2:2:lilypad,2:3:lilypad,2:2:threepeater,2:3:threepeater,' +
      '3:0:wallnut,3:5:wallnut',
  },
  {
    // afternoon level with buckets and repeaters (`--dom 18-front2-win`)
    name: '18-front2-win',
    at: '1.6,0.0',
    yaw: 92,
    pitch: -6,
    level: 'front-2',
    warp: 260,
    plant:
      '0:0:sunflower,0:1:sunflower,0:2:sunflower,0:3:sunflower,0:4:sunflower,' +
      '1:0:peashooter,1:1:peashooter,1:2:peashooter,1:3:peashooter,1:4:peashooter,' +
      '2:0:repeater,2:1:repeater,2:2:repeater,2:3:repeater,2:4:repeater,' +
      '3:0:wallnut,3:2:wallnut,3:4:wallnut',
  },
  {
    // straight down at the pool surface (used to check the water shading)
    name: '19-pool-water',
    at: '-25.4,0.0',
    yaw: 90,
    pitch: -70,
    level: 'back-1',
  },
  {
    // the level menu itself: front yard / backyard picker over the live scene
    name: '20-menu',
    at: '-3.2,0.6',
    yaw: -96,
    pitch: -5,
    panel: 'intro',
  },
  {
    // same menu with the pool level selected, from the patio
    name: '21-menu-backyard',
    at: '-20.9,2.6',
    yaw: 96,
    pitch: -6,
    level: 'back-1',
    panel: 'intro',
  },
  {
    // the plant cast from the zombie side: plants face +X, so this shows faces
    name: '22-plant-front',
    at: '6.6,0.2',
    yaw: 88,
    pitch: -10,
    level: 'front-1',
    warp: 3,
    plant:
      '5:0:sunflower,6:0:peashooter,7:0:snowpea,8:0:repeater,' +
      '5:1:cherrybomb,6:1:potatomine,7:1:threepeater,8:1:chomper,' +
      '5:2:wallnut,6:2:tallnut,7:2:lilypad,8:2:sunflower',
  },
  {
    // zombies walking into the defence, seen head-on
    name: '23-zombie-front',
    at: '6.6,0.4',
    yaw: 88,
    pitch: -4,
    level: 'front-2',
    warp: 56,
    plant: '2:0:peashooter,2:1:peashooter,3:0:sunflower,3:1:sunflower,1:2:wallnut,2:2:wallnut',
  },
];

const args = process.argv.slice(2);
const domMode = args.includes('--dom');
const filters = args.filter((a) => !a.startsWith('--'));

function want(name) {
  if (filters.length === 0) return true;
  return filters.some((f) => name.includes(f));
}

await mkdir(OUT, { recursive: true });

const server = await createServer({
  configFile: false,
  root: ROOT,
  logLevel: 'warn',
  server: { host: '127.0.0.1', port: PORT, strictPort: true },
});
await server.listen();
console.log(`dev server on http://127.0.0.1:${PORT}/`);

function urlFor(shot) {
  if (!shot) return `http://127.0.0.1:${PORT}/`;
  const q = new URLSearchParams();
  if (shot.at) q.set('at', shot.at);
  if (shot.yaw !== undefined) q.set('yaw', String(shot.yaw));
  if (shot.pitch !== undefined) q.set('pitch', String(shot.pitch));
  if (shot.level) q.set('level', shot.level);
  if (shot.warp !== undefined) q.set('warp', String(shot.warp));
  if (shot.plant) q.set('plant', shot.plant);
  if (shot.panel) q.set('panel', shot.panel);
  q.set('shot', String(shot.frames ?? 0));
  return `http://127.0.0.1:${PORT}/?${q.toString()}`;
}

function runEdge(extra, timeoutMs = 260000, profileTag = 'shared') {
  const profile = path.join(OUT, `profile-${profileTag}`);
  return new Promise((resolve) => {
    const child = spawn(
      EDGE,
      [
        '--headless=new',
        '--no-sandbox',
        '--disable-gpu',
        '--use-angle=swiftshader',
        '--enable-unsafe-swiftshader',
        '--no-first-run',
        '--no-default-browser-check',
        '--hide-scrollbars',
        '--mute-audio',
        '--disable-extensions',
        '--disable-background-networking',
        `--user-data-dir=${profile}`,
        ...extra,
      ],
      { stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true },
    );
    let out = '';
    let err = '';
    child.stdout.on('data', (d) => {
      out += d.toString();
    });
    child.stderr.on('data', (d) => {
      err += d.toString();
    });
    const timer = setTimeout(() => {
      child.kill('SIGKILL');
    }, timeoutMs);
    child.on('exit', (code) => {
      clearTimeout(timer);
      resolve({ code, out, err });
    });
    child.on('error', (e) => {
      clearTimeout(timer);
      resolve({ code: -1, out: '', err: String(e) });
    });
  });
}

async function fileSize(p) {
  try {
    const s = await stat(p);
    return s.size;
  } catch {
    return 0;
  }
}

try {
  if (domMode) {
    const picked = SHOTS.find((s) => want(s.name)) ?? SHOTS[0];
    const res = await runEdge(
      ['--dump-dom', '--virtual-time-budget=6000', urlFor({ ...picked, frames: 2 })],
      120000,
      'dom',
    );
    const title = /<title>([^<]*)<\/title>/i.exec(res.out)?.[1] ?? '(no title)';
    console.log(`title: ${title}`);
    const bootMatch = /<div id="boot"[^>]*>([^<]*)</i.exec(res.out);
    console.log(`boot: ${bootMatch ? bootMatch[1] : '(none)'}`);
    console.log(`dom bytes: ${res.out.length}`);
    const fatal = /ERR /.test(title);
    if (res.err && !fatal) {
      const noise = res.err
        .split(/\r?\n/)
        .filter((l) => /error|crash|fail/i.test(l))
        .slice(0, 6)
        .join('\n');
      if (noise) console.log(`stderr hints:\n${noise}`);
    }
    process.exitCode = fatal ? 1 : 0;
  } else {
    // clear only the PNGs this run is about to re-render, so a partial run
    // keeps the rest of the gallery and a failure is still obvious
    const targets = new Set(SHOTS.filter((s) => want(s.name)).map((s) => `${s.name}.png`));
    for (const f of await readdir(OUT)) {
      if (f.endsWith('.png') && targets.has(f)) await rm(path.join(OUT, f), { force: true });
      // every shot gets a throwaway profile: a reused one lets Edge attach to a
      // leftover instance and screenshot the previous page instead
      if (f.startsWith('profile')) await rm(path.join(OUT, f), { recursive: true, force: true });
    }
    let failures = 0;
    for (const shot of SHOTS) {
      if (!want(shot.name)) continue;
      const png = path.join(OUT, `${shot.name}.png`);
      const t0 = Date.now();
      const shotUrl = urlFor(shot);
      console.log(`url ${shotUrl}`);
      const res = await runEdge(
        [
          `--screenshot=${png}`,
          '--window-size=960,540',
          '--virtual-time-budget=400',
          '--run-all-compositor-stages-before-draw',
          '--disable-new-content-rendering-timeout',
          urlFor(shot),
        ],
        260000,
        shot.name,
      );
      const size = await fileSize(png);
      const ms = Date.now() - t0;
      if (size > 0) {
        console.log(`${shot.name.padEnd(14)} ${String(size).padStart(7)} B  ${ms} ms`);
      } else {
        failures += 1;
        console.log(`${shot.name.padEnd(14)} FAILED code=${res.code} ${ms} ms`);
        const hint = res.err.split(/\r?\n/).filter(Boolean).slice(-4).join(' | ');
        if (hint) console.log(`   ${hint}`);
      }
    }
    process.exitCode = failures > 0 ? 1 : 0;
  }
} finally {
  await server.close();
}






