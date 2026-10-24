/**
 * Turn the Vite build in `dist/` into one double-clickable HTML file.
 *
 * A normal production build still loads `assets/index-xxx.js` as an ES module,
 * and browsers refuse module loads from `file://` (the origin is "null"). So we
 * inline the bundle and the stylesheet into a single document; inline modules
 * have nothing to fetch, which makes the page work straight off the disk.
 */
import { readFile, writeFile, readdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(import.meta.dirname, '..');
const DIST = path.join(ROOT, 'dist');
const OUT = path.join(DIST, 'pvz3d.html');

const html = await readFile(path.join(DIST, 'index.html'), 'utf8');

const pick = async (dir, ext) => {
  const files = (await readdir(path.join(DIST, dir))).filter((f) => f.endsWith(ext));
  if (files.length === 0) throw new Error(`no ${ext} file in dist/${dir}`);
  // a build emits exactly one of each; if not, the last one wins (newest hash)
  return path.join(DIST, dir, files.sort().at(-1));
};

const jsFile = await pick('assets', '.js');
const cssFile = await pick('assets', '.css');
const js = await readFile(jsFile, 'utf8');
const css = await readFile(cssFile, 'utf8');

// `</script>` inside a string literal would end the inline block early
const safeJs = js.replaceAll('</script>', '<\\/script>');

let out = html
  // NB: the replacement MUST be a function. A string replacement expands `$&`,
  // `` $` `` and `$'` in the *bundle* (three.js really does contain `` `$` ``),
  // which splices the surrounding document into the JavaScript and breaks it.
  .replace(
    /\s*<script[^>]*src="[^"]*"[^>]*><\/script>/,
    () => `\n    <script type="module">\n${safeJs}\n    </script>`,
  )
  .replace(/\s*<link[^>]*rel="stylesheet"[^>]*>/, () => `\n    <style>\n${css}\n    </style>`);

if (!out.includes('<script type="module">')) throw new Error('could not inline the JS bundle');
if (!out.includes('<style>')) throw new Error('could not inline the stylesheet');
// the whole bundle has to survive verbatim — a `$` substitution would have
// injected document markup into it, which is exactly the bug this guards
if (!out.includes(safeJs)) throw new Error('inlined JS does not match the bundle byte for byte');
if (safeJs.includes('<!doctype html>') || safeJs.includes('<html')) {
  throw new Error('document markup leaked into the JavaScript bundle');
}

// a title marker makes it obvious which build is open, and the flag tells the
// file:// guard in <head> that inlining already made this page self-contained
out = out
  .replace('<html lang="zh-CN">', '<html lang="zh-CN" data-standalone>')
  .replace('</title>', ' · 单文件版</title>');

if (!out.includes('data-standalone')) throw new Error('could not flag the standalone build');

await writeFile(OUT, out, 'utf8');

const kb = (n) => `${(n / 1024).toFixed(0)} kB`;
console.log(`standalone: ${path.relative(ROOT, OUT)}  ${kb(Buffer.byteLength(out))}`);
console.log(`  js  ${path.basename(jsFile)} ${kb(js.length)}`);
console.log(`  css ${path.basename(cssFile)} ${kb(css.length)}`);
if (!existsSync(OUT)) process.exitCode = 1;
