#!/usr/bin/env node
// Generates TypeScript + C++ bindings (JSI) and WASM bindings from the
// host-native Rust library. Works on Windows (.dll), macOS (.dylib), and Linux (.so).

const { execSync } = require('child_process');
const path = require('path');
const os = require('os');
const fs = require('fs');

const root  = path.resolve(__dirname, '..');
const crate = path.join(root, 'rust', 'ratex_wrapper');

const ext    = os.platform() === 'win32'  ? '.dll'
             : os.platform() === 'darwin' ? '.dylib'
             : '.so';
const prefix = os.platform() === 'win32' ? '' : 'lib';
const lib = path.join('target', 'debug', `${prefix}ratex_wrapper${ext}`);

// ── Step 1: Build host-native library ────────────────────────────────────────
console.log('\n[ratex] Building host library…');
execSync('cargo build --manifest-path rust/ratex_wrapper/Cargo.toml', {
  stdio: 'inherit',
  cwd: root,
});

// ── Step 2: Generate JSI (React Native) bindings ─────────────────────────────
console.log('\n[ratex] Generating JSI bindings…');
execSync(
  `npx uniffi-bindgen-react-native generate jsi bindings --library --no-format --ts-dir ../../src/generated/rn --cpp-dir ../../cpp ${lib}`,
  { stdio: 'inherit', cwd: crate }
);

// Ensure cpp/generated/ exists
const generatedDir = path.join(root, 'cpp', 'generated');
['ratex_wrapper.cpp', 'ratex_wrapper.hpp'].forEach(file => {
  const dest = path.join(generatedDir, file);
  const src  = path.join(root, 'cpp', file);
  if (!fs.existsSync(dest) && fs.existsSync(src)) {
    fs.mkdirSync(generatedDir, { recursive: true });
    fs.copyFileSync(src, dest);
    console.log(`[ratex] Copied cpp/${file} → cpp/generated/${file}`);
  }
});

// ── Step 3: Generate turbo-module glue ────────────────────────────────────────
console.log('\n[ratex] Generating turbo-module glue…');
execSync(
  `npx uniffi-bindgen-react-native generate jsi turbo-module --config ubrn.config.yaml ratex_wrapper`,
  { stdio: 'inherit', cwd: root }
);

// ── Patch RatexModule.kt: use reflection for jsCallInvokerHolder ──────────────
const ratexModuleKt = path.join(root, 'android', 'src', 'main', 'java', 'com', 'ratex', 'RatexModule.kt');
if (fs.existsSync(ratexModuleKt)) {
  let kt = fs.readFileSync(ratexModuleKt, 'utf8');
  kt = kt.replace(
    /override fun installRustCrate\(\): Boolean \{[\s\S]*?context\.jsCallInvokerHolder!!\s*\)\s*\}/,
    `override fun installRustCrate(): Boolean {
    val context = this.reactApplicationContext
    return nativeInstallRustCrate(
      context.javaScriptContextHolder!!.get(),
      resolveCallInvokerHolder(context)
    )
  }

  private fun resolveCallInvokerHolder(context: ReactApplicationContext): CallInvokerHolder {
    val direct = context.javaClass.methods.firstOrNull { it.name == "getJSCallInvokerHolder" }
    if (direct != null) return direct.invoke(context) as CallInvokerHolder
    @Suppress("DEPRECATION")
    val ci = checkNotNull(context.catalystInstance) { "No CatalystInstance" }
    return ci.javaClass.methods.first { it.name == "getJSCallInvokerHolder" }.invoke(ci) as CallInvokerHolder
  }`
  );
  fs.writeFileSync(ratexModuleKt, kt, 'utf8');
  console.log('[ratex] Patched RatexModule.kt (jsCallInvokerHolder → reflection)');
}

// ── Write RatexImpl.h stub ────────────────────────────────────────────────────
const ratexImplH = path.join(root, 'android', 'generated', 'jni', 'RatexImpl.h');
fs.mkdirSync(path.dirname(ratexImplH), { recursive: true });
if (!fs.existsSync(ratexImplH) || fs.readFileSync(ratexImplH, 'utf8').includes('kModuleName = ""')) {
  fs.writeFileSync(ratexImplH, `#pragma once
#include <ReactCommon/TurboModule.h>
#include <RatexSpec.h>
namespace facebook::react {
class RatexImpl final : public TurboModule {
public:
  static constexpr const char* kModuleName = "Ratex";
  explicit RatexImpl(std::shared_ptr<CallInvoker> jsInvoker)
      : TurboModule("Ratex", std::move(jsInvoker)) {}
};
} // namespace facebook::react
`, 'utf8');
  console.log('[ratex] Wrote android/generated/jni/RatexImpl.h');
}

// ── Step 5: Generate WASM bindings ────────────────────────────────────────────
console.log('\n[ratex] Generating WASM bindings…');
execSync(
  `npx uniffi-bindgen-react-native generate wasm bindings --library --no-format --ts-dir ../../src/generated/web --cpp-dir ../../rust_modules/wasm/src ${lib}`,
  { stdio: 'inherit', cwd: crate }
);

// ── Step 6: Generate WASM crate ───────────────────────────────────────────────
console.log('\n[ratex] Generating WASM crate…');
execSync(
  `npx uniffi-bindgen-react-native generate wasm wasm-crate --config ubrn.config.yaml ratex_wrapper`,
  { stdio: 'inherit', cwd: root }
);

// ── Fix android/CMakeLists.txt paths ─────────────────────────────────────────
const androidCMake = path.join(root, 'android', 'CMakeLists.txt');
if (fs.existsSync(androidCMake)) {
  let cmake = fs.readFileSync(androidCMake, 'utf8');
  cmake = cmake.replace(
    /# Resolve the path to the uniffi-bindgen-react-native package[\s\S]*?include_directories\(/,
    `# Resolve uniffi-bindgen-react-native includes.
set(_UNIFFI_LOCAL  "\${CMAKE_CURRENT_LIST_DIR}/../node_modules/uniffi-bindgen-react-native/cpp/includes")
set(_UNIFFI_HOISTED "\${CMAKE_CURRENT_LIST_DIR}/../../uniffi-bindgen-react-native/cpp/includes")
if(EXISTS "\${_UNIFFI_LOCAL}")
  cmake_path(SET UNIFFI_INCLUDES "\${_UNIFFI_LOCAL}" NORMALIZE)
else()
  cmake_path(SET UNIFFI_INCLUDES "\${_UNIFFI_HOISTED}" NORMALIZE)
endif()

include_directories(`
  );
  cmake = cmake.replace(/\$\{UNIFFI_BINDGEN_PATH\}\/cpp\/includes/g, '${UNIFFI_INCLUDES}');
  cmake = cmake.replace(/\$\{CMAKE_SOURCE_DIR\}\/src\/main\/jniLibs/g, '${CMAKE_CURRENT_LIST_DIR}/src/main/jniLibs');
  fs.writeFileSync(androidCMake, cmake, 'utf8');
  console.log('[ratex] Patched android/CMakeLists.txt');
}

// ── Fix backslashes in generated files (Windows) ─────────────────────────────
const webIndex = path.join(root, 'src', 'index.web.ts');
if (fs.existsSync(webIndex)) {
  let src = fs.readFileSync(webIndex, 'utf8');
  src = src.replace(/'\.\/(generated\\[^']+)'/g, (_, p) => `'./${p.replace(/\\/g, '/')}'`);
  src = src.replace(/wasm-bindgen\/index\.js/g, 'wasm-bindgen/react_native_ratex.js');
  src = src.replace(/wasm-bindgen\/index_bg\.wasm/g, 'wasm-bindgen/react_native_ratex_bg.wasm');
  fs.writeFileSync(webIndex, src, 'utf8');
}

const nativeIndex = path.join(root, 'src', 'index.tsx');
if (fs.existsSync(nativeIndex)) {
  const fixed = fs.readFileSync(nativeIndex, 'utf8').replace(/generated\\rn/g, 'generated/rn');
  fs.writeFileSync(nativeIndex, fixed, 'utf8');
}

const webBindings = path.join(root, 'src', 'generated', 'web', 'ratex_wrapper.ts');
if (fs.existsSync(webBindings)) {
  let src = fs.readFileSync(webBindings, 'utf8');
  src = src.replace(/wasm-bindgen\/index\.js/g, 'wasm-bindgen/react_native_ratex.js');
  src = src.replace(/wasm-bindgen\/index_bg\.wasm/g, 'wasm-bindgen/react_native_ratex_bg.wasm');
  fs.writeFileSync(webBindings, src, 'utf8');
}

const wasmCargo = path.join(root, 'rust_modules', 'wasm', 'Cargo.toml');
if (fs.existsSync(wasmCargo)) {
  let cargo = fs.readFileSync(wasmCargo, 'utf8');
  cargo = cargo.replace(
    /path = ".*?uniffi-runtime-javascript"/,
    'path = "../../node_modules/uniffi-bindgen-react-native/crates/uniffi-runtime-javascript"'
  );
  cargo = cargo.replace(/path = "([^"]+)"/g, (_, p) => `path = "${p.replace(/\\/g, '/')}"`);
  fs.writeFileSync(wasmCargo, cargo, 'utf8');
}

// ── Fix cpp entry backslashes ─────────────────────────────────────────────────
const cppEntry = path.join(root, 'cpp', 'react-native-ratex.cpp');
if (fs.existsSync(cppEntry)) {
  const fixed = fs.readFileSync(cppEntry, 'utf8').replace(/generated\\ratex_wrapper/g, 'generated/ratex_wrapper');
  fs.writeFileSync(cppEntry, fixed, 'utf8');
}

for (const cppFile of [
  path.join(root, 'cpp', 'generated', 'ratex_wrapper.cpp'),
  path.join(root, 'cpp', 'ratex_wrapper.cpp'),
]) {
  if (fs.existsSync(cppFile)) {
    let cpp = fs.readFileSync(cppFile, 'utf8');
    if (cpp.includes('unordered_map') && !cpp.includes('#include <unordered_map>')) {
      cpp = cpp.replace('#include <map>', '#include <map>\n#include <unordered_map>');
      fs.writeFileSync(cppFile, cpp, 'utf8');
      console.log(`[ratex] Patched ${path.relative(root, cppFile)} (added <unordered_map>)`);
    }
  }
}

// ── Fix Ratex.podspec backslash glob patterns ─────────────────────────────────
const podspec = path.join(root, 'Ratex.podspec');
if (fs.existsSync(podspec)) {
  let spec = fs.readFileSync(podspec, 'utf8');
  spec = spec.replace(/,\s*"ios\\generated\/\*\*\/[^"]*"/g, '');
  spec = spec.replace(/,\s*"cpp\\generated\/\*\*\/[^"]*"/g, '');
  fs.writeFileSync(podspec, spec, 'utf8');
}

console.log('\n[ratex] Done — bindings written to src/generated/rn/, src/generated/web/, and cpp/');
