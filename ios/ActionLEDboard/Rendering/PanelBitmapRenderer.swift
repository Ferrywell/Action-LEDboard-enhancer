import CoreGraphics
import UIKit

/// Renders 32×32 PNGs for BK-Light (32×32 hardware). 16×32 requires agreed protocol bytes — do not guess dimensions here.
enum PanelBitmapRenderer {
    static let panelSize = CGSize(width: 32, height: 32)

    /// Default line/text color on the panel: **white** on black (high contrast on discrete LEDs).
    static let defaultTextForeground = UIColor.white

    static func adjustPNG(_ data: Data, rotationDegrees: Int, brightness: CGFloat) -> Data {
        guard let ui = UIImage(data: data) else { return data }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: panelSize, format: format)
        let out = renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: panelSize))
            ctx.cgContext.translateBy(x: panelSize.width / 2, y: panelSize.height / 2)
            ctx.cgContext.rotate(by: CGFloat(rotationDegrees) * .pi / 180)
            ctx.cgContext.translateBy(x: -panelSize.width / 2, y: -panelSize.height / 2)
            ctx.cgContext.setAlpha(max(0, min(1, brightness)))
            ui.draw(in: CGRect(origin: .zero, size: panelSize))
        }
        return out.pngData() ?? data
    }

    /// Multi-line text as a **5×7 dot matrix** (one bitmap pixel ↔ one LED), matching `panel_hopper/graphics.py`.
    /// Avoids vector fonts and anti-aliasing, which map badly to discrete LEDs and looked “sheared” or unreadable.
    static func renderLines(_ lines: [String], background: UIColor = .black, foreground: UIColor = defaultTextForeground) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: panelSize, format: format)
        let img = renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setAllowsAntialiasing(false)
            cg.interpolationQuality = .none
            background.setFill()
            cg.fill(CGRect(origin: .zero, size: panelSize))

            let trimmed = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let sanitized = trimmed.map { Self.sanitizeForDotMatrix($0) }
            guard !sanitized.isEmpty else { return }

            foreground.setFill()
            let scale = pickScale(for: sanitized)
            let lineGap = max(1, scale)
            var totalHeight = 0
            for (i, line) in sanitized.enumerated() {
                totalHeight += DotMatrixFont.charHeight * scale
                if i > 0 { totalHeight += lineGap }
            }
            var y = (Int(panelSize.height) - totalHeight) / 2
            for (idx, line) in sanitized.enumerated() {
                let lineWidth = DotMatrixFont.textWidth(line) * scale
                let x = (Int(panelSize.width) - lineWidth) / 2
                drawDotMatrixLine(line, in: cg, x: x, y: y, scale: scale)
                y += DotMatrixFont.charHeight * scale
                if idx < sanitized.count - 1 { y += lineGap }
            }
        }
        return img.pngData()
    }

    /// Largest scale 1…4 so all lines fit in the inner margin (same idea as Python `create_dot_matrix_text` auto_scale).
    private static func pickScale(for lines: [String]) -> Int {
        let margin = 2
        let maxDim = Int(panelSize.width) - margin * 2
        for s in (1...4).reversed() {
            let gap = max(1, s)
            var maxW = 0
            var totalH = 0
            for (i, line) in lines.enumerated() {
                let w = DotMatrixFont.textWidth(line) * s
                maxW = max(maxW, w)
                totalH += DotMatrixFont.charHeight * s
                if i > 0 { totalH += gap }
            }
            if maxW <= maxDim && totalH <= maxDim {
                return s
            }
        }
        return 1
    }

    /// Dot-matrix glyphs are ASCII-only; replace others so width/layout matches drawing.
    private static func sanitizeForDotMatrix(_ line: String) -> String {
        String(line.uppercased().map { $0.isASCII ? $0 : Character("?") })
    }

    private static func drawDotMatrixLine(_ text: String, in cg: CGContext, x: Int, y: Int, scale: Int) {
        var cx = x
        for ch in text {
            let rows = DotMatrixFont.rows(for: ch)
            for (rowIdx, row) in rows.enumerated() {
                for (colIdx, dot) in row.enumerated() {
                    if dot == "#" {
                        let px = cx + colIdx * scale
                        let py = y + rowIdx * scale
                        cg.fill(CGRect(x: px, y: py, width: scale, height: scale))
                    }
                }
            }
            cx += (DotMatrixFont.charWidth + DotMatrixFont.charSpacing) * scale
        }
    }
}
