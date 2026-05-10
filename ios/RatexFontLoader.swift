// RatexFontLoader.swift — Register KaTeX fonts with CoreText for the renderer.

import CoreText
import Foundation

public enum RatexFontLoader {

    private static let loadLock = NSLock()
    private static var _didEnsureLoad = false

    static let fontFileNames: [String] = [
        "KaTeX_AMS-Regular", "KaTeX_Caligraphic-Bold", "KaTeX_Caligraphic-Regular",
        "KaTeX_Fraktur-Bold", "KaTeX_Fraktur-Regular", "KaTeX_Main-Bold",
        "KaTeX_Main-BoldItalic", "KaTeX_Main-Italic", "KaTeX_Main-Regular",
        "KaTeX_Math-BoldItalic", "KaTeX_Math-Italic", "KaTeX_SansSerif-Bold",
        "KaTeX_SansSerif-Italic", "KaTeX_SansSerif-Regular", "KaTeX_Script-Regular",
        "KaTeX_Size1-Regular", "KaTeX_Size2-Regular", "KaTeX_Size3-Regular",
        "KaTeX_Size4-Regular", "KaTeX_Typewriter-Regular",
    ]

    @discardableResult
    public static func loadFromBundle(_ bundle: Bundle = Bundle.main) -> Int {
        var loaded = 0
        for name in fontFileNames {
            let url = bundle.url(forResource: name, withExtension: "ttf")
                ?? bundle.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
            if let url, register(url) { loaded += 1 }
        }
        return loaded
    }

    @discardableResult
    public static func ensureLoaded() -> Int {
        guard !_didEnsureLoad else { return 0 }
        loadLock.lock()
        defer { loadLock.unlock() }
        guard !_didEnsureLoad else { return 0 }
        defer { _didEnsureLoad = true }
        if isFontRegistered("KaTeX_Main-Regular") { return 0 }
        return loadFromBundle()
    }

    public static func isFontRegistered(_ postScriptName: String) -> Bool {
        let array = CTFontManagerCopyRegisteredFontDescriptors(.process, false) as NSArray
        for item in array {
            let desc = item as! CTFontDescriptor
            if let name = CTFontDescriptorCopyAttribute(desc, kCTFontNameAttribute) as? String,
               name == postScriptName { return true }
        }
        return false
    }

    private static func register(_ url: URL) -> Bool {
        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if !ok, let err = error?.takeRetainedValue() {
            let desc = CFErrorCopyDescription(err) as String
            if !desc.contains("already") && !desc.contains("duplicate") {
                print("[Ratex] font registration warning for \(url.lastPathComponent): \(desc)")
            }
        }
        return ok
    }
}
