// DisplayList.swift — Swift mirror of ratex-types DisplayList / DisplayItem

import Foundation

public struct DisplayList: Codable {
    public let width: Double
    public let height: Double
    public let depth: Double
    public let items: [DisplayItem]
}

public enum DisplayItem: Codable {
    case glyphPath(GlyphPathData)
    case line(LineData)
    case rect(RectData)
    case path(PathData)

    private enum TypeKey: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let tag = try decoder.container(keyedBy: TypeKey.self).decode(String.self, forKey: .type)
        switch tag {
        case "GlyphPath": self = .glyphPath(try GlyphPathData(from: decoder))
        case "Line":      self = .line(try LineData(from: decoder))
        case "Rect":      self = .rect(try RectData(from: decoder))
        case "Path":      self = .path(try PathData(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: try decoder.container(keyedBy: TypeKey.self),
                debugDescription: "Unknown DisplayItem type: \(tag)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .glyphPath(let d): try d.encode(to: encoder)
        case .line(let d):      try d.encode(to: encoder)
        case .rect(let d):      try d.encode(to: encoder)
        case .path(let d):      try d.encode(to: encoder)
        }
    }
}

public struct GlyphPathData: Codable {
    public let x: Double
    public let y: Double
    public let scale: Double
    public let font: String
    public let charCode: UInt32
    public let commands: [PathCommand]
    public let color: RatexColor

    enum CodingKeys: String, CodingKey {
        case x, y, scale, font
        case charCode = "char_code"
        case commands, color
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        x        = try c.decode(Double.self,  forKey: .x)
        y        = try c.decode(Double.self,  forKey: .y)
        scale    = try c.decode(Double.self,  forKey: .scale)
        font     = try c.decode(String.self,  forKey: .font)
        charCode = try c.decode(UInt32.self,  forKey: .charCode)
        commands = try c.decodeIfPresent([PathCommand].self, forKey: .commands) ?? []
        color    = try c.decode(RatexColor.self, forKey: .color)
    }
}

public struct LineData: Codable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let thickness: Double
    public let color: RatexColor
    public let dashed: Bool

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        x         = try c.decode(Double.self,  forKey: .x)
        y         = try c.decode(Double.self,  forKey: .y)
        width     = try c.decode(Double.self,  forKey: .width)
        thickness = try c.decode(Double.self,  forKey: .thickness)
        color     = try c.decode(RatexColor.self, forKey: .color)
        dashed    = try c.decodeIfPresent(Bool.self, forKey: .dashed) ?? false
    }
}

public struct RectData: Codable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public let color: RatexColor
}

public struct PathData: Codable {
    public let x: Double
    public let y: Double
    public let commands: [PathCommand]
    public let fill: Bool
    public let color: RatexColor
}

public enum PathCommand: Codable {
    case moveTo(x: Double, y: Double)
    case lineTo(x: Double, y: Double)
    case cubicTo(x1: Double, y1: Double, x2: Double, y2: Double, x: Double, y: Double)
    case quadTo(x1: Double, y1: Double, x: Double, y: Double)
    case close

    private enum TypeKey: String, CodingKey { case type }
    private struct XY:    Codable { let x, y: Double }
    private struct Cubic: Codable { let x1, y1, x2, y2, x, y: Double }
    private struct Quad:  Codable { let x1, y1, x, y: Double }

    public init(from decoder: Decoder) throws {
        let tag = try decoder.container(keyedBy: TypeKey.self).decode(String.self, forKey: .type)
        switch tag {
        case "MoveTo":  let d = try XY(from: decoder);    self = .moveTo(x: d.x, y: d.y)
        case "LineTo":  let d = try XY(from: decoder);    self = .lineTo(x: d.x, y: d.y)
        case "CubicTo": let d = try Cubic(from: decoder); self = .cubicTo(x1: d.x1, y1: d.y1, x2: d.x2, y2: d.y2, x: d.x, y: d.y)
        case "QuadTo":  let d = try Quad(from: decoder);  self = .quadTo(x1: d.x1, y1: d.y1, x: d.x, y: d.y)
        case "Close":   self = .close
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: try decoder.container(keyedBy: TypeKey.self),
                debugDescription: "Unknown PathCommand type: \(tag)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: TypeKey.self)
        switch self {
        case .moveTo(let x, let y):
            try c.encode("MoveTo", forKey: .type); try XY(x: x, y: y).encode(to: encoder)
        case .lineTo(let x, let y):
            try c.encode("LineTo", forKey: .type); try XY(x: x, y: y).encode(to: encoder)
        case .cubicTo(let x1, let y1, let x2, let y2, let x, let y):
            try c.encode("CubicTo", forKey: .type); try Cubic(x1: x1, y1: y1, x2: x2, y2: y2, x: x, y: y).encode(to: encoder)
        case .quadTo(let x1, let y1, let x, let y):
            try c.encode("QuadTo", forKey: .type); try Quad(x1: x1, y1: y1, x: x, y: y).encode(to: encoder)
        case .close:
            try c.encode("Close", forKey: .type)
        }
    }
}

public struct RatexColor: Codable {
    public let r: Float
    public let g: Float
    public let b: Float
    public let a: Float
    public static let black = RatexColor(r: 0, g: 0, b: 0, a: 1)
}
