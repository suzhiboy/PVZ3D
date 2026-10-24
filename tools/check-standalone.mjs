/** Throwaway diagnostic: is the inlined bundle in dist/pvz3d.html intact? */
import { readFile, writeFile, readdir, mkdir } from 'node:fs/promises';
import path from 'node:path';

const ROOT = 'D:/PVZ3D';
const html = await readFile(path.join(ROOT, 'dist/pvz3d.html'), 'utf8');

const open = '<script type="module">';
const i = html.indexOf(open);
const j = html.indexOf('</script>', i);
const inline = html.slice(i + open.length, j);

const jsName = (await readdir(path.join(ROOT, 'dist/assets'))).filter((f) => f.endsWith('.js'))[0];
const orig = await readFile(path.join(ROOT, 'dist/assets', jsName), 'utf8');

await mkdir(path.join(ROOT, '.tmp'), { recursive: true });
await writeFile(path.join(ROOT, '.tmp/inline.mjs'), inline, 'utf8');

const count = (s, sub) => s.split(sub).length - 1;
console.log('inline chars   ', inline.length);
console.log('original chars ', orig.length);
console.log('identical      ', inline.length === orig.length && inline === orig);
console.log('raw </script   ', count(inline, '</script>'), count(inline, '</script '));
console.log('<!-- sequences ', count(inline, '<!--'));
console.log('</style        ', count(inline, '</style'));
console.log('first 60       ', JSON.stringify(inline.slice(0, 60)));
console.log('last 60        ', JSON.stringify(inline.slice(-60)));
console.log('head tag       ', JSON.stringify(html.slice(0, 120)));
