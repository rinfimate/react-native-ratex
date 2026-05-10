// RatexEngine.swift — Swift wrapper around the ratex_parse_and_layout C ABI.

import Foundation
import UIKit

public enum RatexError: Error, LocalizedError {
    case parseError(String)
    case nullResult

    public var errorDescription: String? {
        switch self {
        case .parseError(let msg): return "Ratex parse error: \(msg)"
        case .nullResult:          return "Ratex returned null with no error message"
        }
    }
}

public final class RatexEngine {
    public static let shared = RatexEngine()
    private init() {}

    public func parse(
        _ latex: String,
        displayMode: Bool = true,
        color: UIColor = .black,
        traitCollection: UITraitCollection? = nil
    ) throws -> DisplayList {
        let resolved = traitCollection.map { color.resolvedColor(with: $0) } ?? color
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)

        // Call the C FFI from the uniffi-generated xcframework
        var ffiColor = RatexFfiColor(r: Float(r), g: Float(g), b: Float(b), a: Float(a))
        let result = withUnsafePointer(to: &ffiColor) { colorPtr in
            var opts = RatexFfiOptions(
                struct_size: MemoryLayout<RatexFfiOptions>.size,
                display_mode: displayMode ? 1 : 0,
                color: colorPtr
            )
            return ratex_parse_and_layout(latex, &opts)
        }
        guard result.error_code == 0, let ptr = result.data else {
            let msg = ratex_get_last_error().map { String(cString: $0) } ?? "unknown error"
            throw RatexError.parseError(msg)
        }
        defer { ratex_free_display_list(ptr) }
        let json = String(cString: ptr)
        do {
            return try JSONDecoder().decode(DisplayList.self, from: Data(json.utf8))
        } catch {
            throw RatexError.parseError("JSON decode failed: \(error)")
        }
    }
}
