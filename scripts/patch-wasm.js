#!/usr/bin/env node
// Patches wasm-pack's --target web output so Metro can bundle it.
// Metro bundles for web in CommonJS mode; import.meta is a SyntaxError in that context.

const fs = require('fs');
const path = require('path');

const file = path.join(__dirname, '..', 'src', 'generated', 'web', 'wasm-bindgen', 'react_native_ratex.js');

if (!fs.existsSync(file)) {
  console.error('[ratex] patch-wasm: file not found:', file);
  process.exit(1);
}

const before = fs.readFileSync(file, 'utf8');
const after = before.replace(/import\.meta\.url/g, "''");

if (before === after) {
  console.log('[ratex] patch-wasm: nothing to patch');
} else {
  fs.writeFileSync(file, after, 'utf8');
  console.log('[ratex] patch-wasm: replaced import.meta.url with empty string');
}

const wasmDir = path.join(__dirname, '..', 'src', 'generated', 'web', 'wasm-bindgen');

const wasmPkgJson = path.join(wasmDir, 'package.json');
if (fs.existsSync(wasmPkgJson)) {
  fs.rmSync(wasmPkgJson);
  console.log('[ratex] patch-wasm: removed wasm-bindgen/package.json');
}

const wasmGitIgnore = path.join(wasmDir, '.gitignore');
if (fs.existsSync(wasmGitIgnore)) {
  fs.rmSync(wasmGitIgnore);
  console.log('[ratex] patch-wasm: removed wasm-bindgen/.gitignore');
}
