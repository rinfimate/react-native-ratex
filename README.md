# react-native-ratex

> **LaTeX renderer for React Native and React Native Web. No DOM. No WebView. Pure Rust.**

[![npm](https://img.shields.io/npm/v/react-native-ratex)](https://www.npmjs.com/package/react-native-ratex)
[![license](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
![platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20Android%20%7C%20Web-brightgreen)

## Why react-native-ratex?

Every other LaTeX solution for React Native requires MathJax running in a WebView, a DOM renderer, or a server-side SVG generator. That means slow startup, heavy bundles, and broken native builds.

**react-native-ratex** wraps [RaTeX](https://github.com/rinfimate/RaTeX) — a pure Rust LaTeX engine — as a React Native Turbo Module. The Rust code compiles natively for iOS and Android, and to WASM for the browser. No DOM. No WebView. Works fully offline.

| | react-native-ratex | MathJax WebView | KaTeX DOM |
|---|:---:|:---:|:---:|
| iOS native | ✅ | ❌ | ❌ |
| Android native | ✅ | ❌ | ❌ |
| Web (WASM) | ✅ | ✅ | ✅ |
| No DOM | ✅ | ❌ | ❌ |
| No WebView | ✅ | ❌ | ❌ |
| Offline | ✅ | ⚠️ | ❌ |

---

## Installation

```sh
# npm
npm install react-native-ratex react-native-svg

# yarn
yarn add react-native-ratex react-native-svg
```

> **Requirements:**
> - **Android:** React Native ≥ 0.73, New Architecture enabled. On RN 0.73–0.75 set `newArchEnabled=true` in `android/gradle.properties` — it is the default from RN 0.76+.
> - **iOS:** React Native ≥ 0.73 with New Architecture. On RN 0.73–0.75 add `ENV['RCT_NEW_ARCH_ENABLED'] = '1'` to your `Podfile` before `use_react_native!`, then run `npx pod-install`.
> - **Web:** any bundler supporting WebAssembly (Metro, Vite, webpack).

---

## Usage

### Simple render

```typescript
import { useState, useEffect } from 'react';
import { View } from 'react-native';
import { SvgXml } from 'react-native-svg';
import { renderToSvg, uniffiInitAsync } from 'react-native-ratex';

export default function LatexView() {
  const [svg, setSvg] = useState<string | null>(null);

  useEffect(() => {
    async function run() {
      // uniffiInitAsync is a no-op on native and loads the WASM module on web.
      // Always await it before rendering so the same code works on both platforms.
      await uniffiInitAsync();
      try {
        setSvg(renderToSvg(String.raw`\frac{-b \pm \sqrt{b^2-4ac}}{2a}`, true, 40));
      } catch (e) {
        console.error('Render failed:', e);
      }
    }
    run();
  }, []);

  return <View>{svg && <SvgXml xml={svg} width="100%" height={80} />}</View>;
}
```

`renderToSvg` is **synchronous** on native — no async overhead after init.

### Multiple formulas

```typescript
import { renderToSvg, uniffiInitAsync } from 'react-native-ratex';
import { SvgXml } from 'react-native-svg';

const FORMULAS = [
  String.raw`E = mc^2`,
  String.raw`\frac{1}{2} + \frac{1}{3} = \frac{5}{6}`,
  String.raw`\int_0^\infty e^{-x^2}\,dx = \frac{\sqrt{\pi}}{2}`,
];

await uniffiInitAsync();
const svgs = FORMULAS.map(f => renderToSvg(f, true, 40));
```

---

## ⚠️ Always use `String.raw` for LaTeX strings

Hermes (React Native's JS engine) converts certain backslash sequences to control characters before passing strings through the native bridge:

| JS sequence | Control char | Affected LaTeX commands |
|------------|-------------|------------------------|
| `\f` | form feed (0x0C) | `\frac`, `\footnote` |
| `\t` | tab (0x09) | `\text`, `\theta`, `\tau`, `\times` |
| `\r` | CR (0x0D) | `\right`, `\rho`, `\rm` |
| `\b` | backspace (0x08) | `\bar`, `\beta`, `\bf` |
| `\v` | vtab (0x0B) | `\vec`, `\varphi`, `\vee` |

**Always use `String.raw` template literals** to pass LaTeX strings:

```typescript
// ✅ Correct — String.raw preserves backslashes literally
renderToSvg(String.raw`\frac{1}{2} + \frac{1}{3}`, true, 40)
renderToSvg(String.raw`\theta + \phi = \pi`, true, 40)
renderToSvg(String.raw`\vec{v} \cdot \vec{u}`, true, 40)

// ❌ Wrong — \f becomes form feed (0x0C), \t becomes tab, etc.
renderToSvg('\\frac{1}{2}', true, 40)   // \f → form feed on Android/iOS
renderToSvg('\\theta', true, 40)         // \t → tab on Android/iOS
```

> **Note:** The library includes a Rust-level guard that converts known control characters back to their LaTeX equivalents. For **dynamic strings** (e.g. from an API or user input) where `String.raw` isn't available, use:
> ```typescript
> const BS = String.fromCharCode(92); // literal backslash
> const formula = `${BS}frac{1}{2} + ${BS}frac{1}{3}`;
> ```

---

## API

| Function | Description |
|---|---|
| `renderToSvg(latex, displayMode, fontSize)` | Render LaTeX to a self-contained SVG string |
| `renderToView(latex, displayMode)` | Render LaTeX to a JSON DisplayList string |
| `uniffiInitAsync()` | Load WASM on web; no-op on native. Call once before rendering |

### `renderToSvg(latex, displayMode, fontSize)`

| Parameter | Type | Description |
|-----------|------|-------------|
| `latex` | `string` | LaTeX source — use `String.raw` |
| `displayMode` | `boolean` | `true` for block/display math (`$$`), `false` for inline (`$`) |
| `fontSize` | `number` | Font size in user units (recommended: 40) |

Returns a self-contained SVG string with embedded glyph outlines. No external fonts required. Pass directly to `<SvgXml>` from `react-native-svg`.

### `renderToView(latex, displayMode)`

Returns a versioned JSON DisplayList string for custom native view rendering. Useful when you want to draw with Canvas/CoreGraphics rather than SVG.

---

## Metro Configuration

Add to `metro.config.js`:

```js
const { getDefaultConfig } = require('expo/metro-config'); // or @react-native/metro-config
const { mergeConfig } = require('@react-native/metro-config');
const path = require('path');

const config = getDefaultConfig(__dirname);

// Serve .wasm files as assets (required for web WASM bundle)
config.resolver.assetExts = [...config.resolver.assetExts, 'wasm'];

// Prevent Metro from using the browser/WASM entry on native
config.resolver.resolverMainFields = ['react-native', 'main', 'index'];

// On web, route to the WASM entry point
const originalResolveRequest = config.resolver.resolveRequest;
config.resolver.resolveRequest = (context, moduleName, platform) => {
  if (moduleName === 'react-native-ratex' && platform === 'web') {
    return {
      filePath: path.resolve(__dirname, 'node_modules/react-native-ratex/lib/module/index.web.js'),
      type: 'sourceFile',
    };
  }
  return originalResolveRequest
    ? originalResolveRequest(context, moduleName, platform)
    : context.resolveRequest(context, moduleName, platform);
};

module.exports = mergeConfig(config, {});
```

---

## Platform Support

| Platform | Status | Min RN | Notes |
|----------|--------|--------|-------|
| Android | ✅ | 0.73 | New Architecture required |
| iOS | ✅ | 0.73 | New Architecture required |
| Web | ✅ | any | Via WASM |

### Android

Set `newArchEnabled=true` in `android/gradle.properties` (default from RN 0.76+):

```properties
newArchEnabled=true
```

---

## Dev Setup

### Prerequisites

| Tool | Purpose |
|------|---------|
| [Rust](https://rustup.rs) | Compile the Rust crate |
| [Node.js](https://nodejs.org) ≥ 18 | JS toolchain |
| Android Studio + NDK 27 | Android cross-compilation |
| [cargo-ndk](https://github.com/bbqsrc/cargo-ndk) | Android NDK target helper (`cargo install cargo-ndk`) |
| Xcode ≥ 15 | iOS builds (macOS only) |
| [wasm-pack](https://rustwasm.github.io/wasm-pack/) | WASM build |

### Building

```sh
# Install dependencies
npm install

# Generate TypeScript + C++ + Android + iOS bindings
npm run ubrn:generate

# Build native libraries
npm run ubrn:android   # Android (arm64, armeabi-v7a, x86, x86_64)
npm run ubrn:ios       # iOS xcframework (macOS + Xcode required)
npm run ubrn:web       # WASM for web

# Compile TypeScript
npm run prepare
```

---

## License

MIT © 2026 Rochanglien Infimate — see [LICENSE](LICENSE)

## Credits

Built on [RaTeX](https://github.com/rinfimate/RaTeX) (fork of [@erweixin/RaTeX](https://github.com/erweixin/RaTeX)). Wrapper pattern based on [react-native-ariel](https://github.com/rinfimate/ariel). Uses [uniffi-bindgen-react-native](https://github.com/jhugman/uniffi-bindgen-react-native) for the Rust↔JS bridge.
