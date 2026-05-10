// RatexRenderer.swift — CoreGraphics + CoreText renderer for a RaTeX DisplayList.

import CoreGraphics
import CoreText
import Foundation

public struct RatexRenderer {
    public let displayList: DisplayList
    public let fontSize: CGFloat

    public init(displayList: DisplayList, fontSize: CGFloat = 24) {
        self.displayList = displayList
        self.fontSize = fontSize
    }

    public var width:       CGFloat { CGFloat(displayList.width)  * fontSize }
    public var height:      CGFloat { CGFloat(displayList.height) * fontSize }
    public var depth:       CGFloat { CGFloat(displayList.depth)  * fontSize }
    public var totalHeight: CGFloat { height + depth }

    public func draw(in context: CGContext) {
        var fontCache: [String: CTFont] = [:]
        for item in displayList.items {
            switch item {
            case .glyphPath(let g): drawGlyph(g, in: context, fontCache: &fontCache)
            case .line(let l):      drawLine(l, in: context)
            case .rect(let r):      drawRect(r, in: context)
            case .path(let p):      drawPath(p, in: context)
            }
        }
    }

    private func pt(_ em: Double) -> CGFloat { CGFloat(em) * fontSize }

    private func cgColor(_ c: RatexColor) -> CGColor {
        CGColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: CGFloat(c.a))
    }

    private func drawGlyph(_ g: GlyphPathData, in ctx: CGContext, fontCache: inout [String: CTFont]) {
        guard let scalar = Unicode.Scalar(g.charCode) else { return }
        let char = String(Character(scalar))
        let psName = "KaTeX_\(g.font)"
        let cacheKey = "\(psName)/\(g.scale)"
        let ctFont: CTFont
        if let cached = fontCache[cacheKey] {
            ctFont = cached
        } else {
            let f = CTFontCreateWithName(psName as CFString, pt(g.scale), nil)
            fontCache[cacheKey] = f
            ctFont = f
        }
        let attrs: [CFString: Any] = [
            kCTFontAttributeName:            ctFont,
            kCTForegroundColorAttributeName: cgColor(g.color),
        ]
        let attrStr = CFAttributedStringCreate(nil, char as CFString, attrs as CFDictionary)!
        let line    = CTLineCreateWithAttributedString(attrStr)
        ctx.saveGState()
        ctx.translateBy(x: pt(g.x), y: pt(g.y))
        ctx.textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    private func drawLine(_ l: LineData, in ctx: CGContext) {
        ctx.saveGState()
        let t = max(0.5, pt(l.thickness))
        let halfT = t / 2
        if l.dashed {
            ctx.setStrokeColor(cgColor(l.color))
            ctx.setLineWidth(t)
            ctx.setLineCap(.butt)
            let dashLen = t * 3
            ctx.setLineDash(phase: 0, lengths: [dashLen, dashLen])
            ctx.move(to: CGPoint(x: pt(l.x), y: pt(l.y)))
            ctx.addLine(to: CGPoint(x: pt(l.x) + pt(l.width), y: pt(l.y)))
            ctx.strokePath()
        } else {
            ctx.setFillColor(cgColor(l.color))
            ctx.fill(CGRect(x: pt(l.x), y: pt(l.y) - halfT, width: pt(l.width), height: t))
        }
        ctx.restoreGState()
    }

    private func drawRect(_ r: RectData, in ctx: CGContext) {
        ctx.saveGState()
        ctx.setFillColor(cgColor(r.color))
        ctx.fill(CGRect(x: pt(r.x), y: pt(r.y), width: pt(r.width), height: pt(r.height)))
        ctx.restoreGState()
    }

    private func makeCGPath(from commands: [PathCommand], dx: Double = 0, dy: Double = 0) -> CGPath {
        let path = CGMutablePath()
        let ox = pt(dx), oy = pt(dy)
        for cmd in commands {
            switch cmd {
            case .moveTo(let x, let y):
                path.move(to: CGPoint(x: ox + pt(x), y: oy + pt(y)))
            case .lineTo(let x, let y):
                path.addLine(to: CGPoint(x: ox + pt(x), y: oy + pt(y)))
            case .cubicTo(let x1, let y1, let x2, let y2, let x, let y):
                path.addCurve(to:       CGPoint(x: ox + pt(x),  y: oy + pt(y)),
                              control1: CGPoint(x: ox + pt(x1), y: oy + pt(y1)),
                              control2: CGPoint(x: ox + pt(x2), y: oy + pt(y2)))
            case .quadTo(let x1, let y1, let x, let y):
                path.addQuadCurve(to:      CGPoint(x: ox + pt(x),  y: oy + pt(y)),
                                  control: CGPoint(x: ox + pt(x1), y: oy + pt(y1)))
            case .close:
                path.closeSubpath()
            }
        }
        return path
    }

    private func drawPath(_ p: PathData, in ctx: CGContext) {
        ctx.saveGState()
        let cgPath = makeCGPath(from: p.commands, dx: p.x, dy: p.y)
        ctx.addPath(cgPath)
        let color = cgColor(p.color)
        if p.fill { ctx.setFillColor(color); ctx.fillPath() }
        else       { ctx.setStrokeColor(color); ctx.strokePath() }
        ctx.restoreGState()
    }
}
