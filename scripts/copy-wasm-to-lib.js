#!/usr/bin/env node
// After bob build, copy wasm-bindgen output into lib/module so the
// browser export (lib/module/index.web.js) can resolve its relative imports.

const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const src  = path.join(root, 'src', 'generated', 'web', 'wasm-bindgen');
const dest = path.join(root, 'lib', 'module', 'generated', 'web', 'wasm-bindgen');

if (!fs.existsSync(src)) {
  console.log('[ratex] copy-wasm-to-lib: src/generated/web/wasm-bindgen not found — skipping (run yarn ubrn:web first)');
  process.exit(0);
}

fs.mkdirSync(dest, { recursive: true });
let copied = 0;
for (const file of fs.readdirSync(src)) {
  if (file.startsWith('.')) continue; // skip dotfiles (.gitignore etc)
  fs.copyFileSync(path.join(src, file), path.join(dest, file));
  copied++;
}
console.log(`[ratex] Copied ${copied} wasm-bindgen files → lib/module/generated/web/wasm-bindgen/`);
