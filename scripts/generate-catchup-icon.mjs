// Optional maintainer tool; normal builds use the committed PNG.
// Pass an isolated @resvg/resvg-js installation path as the first argument.
import { createRequire } from 'node:module';
import { readFileSync, writeFileSync } from 'node:fs';

const require = createRequire(import.meta.url);
const { Resvg } = require(process.argv[2] || '@resvg/resvg-js');
const source = new URL('../images/catchup-history.svg', import.meta.url);
const output = new URL('../images/catchup-history.png', import.meta.url);
const renderer = new Resvg(readFileSync(source), {
  fitTo: { mode: 'width', value: 64 },
});
writeFileSync(output, renderer.render().asPng());
console.log('catchup-history.png: 64x64 transparent Material history icon');
