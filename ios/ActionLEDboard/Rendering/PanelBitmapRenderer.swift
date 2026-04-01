import CoreGraphics
import UIKit

/// Renders 32×32 PNGs for BK-Light (32×32 hardware). 16×32 requires agreed protocol bytes — do not guess dimensions here.
enum PanelBitmapRenderer {
    static let panelSize = CGSize(width: 32, height: 32)

    /// Default line/text color on the panel: amber `#ff9900` (see `docs/reference/DISPLAY-DESIGN.md`).
    static let defaultTextForeground = UIColor(red: 1, green: 153 / 255, blue: 0, alpha: 1)

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

    /// Multi-line text bitmap (black background, amber text by default) for message / calendar / flight summary.
    static func renderLines(_ lines: [String], background: UIColor = .black, foreground: UIColor = defaultTextForeground) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: panelSize, format: format)
        let img = renderer.image { ctx in
            background.setFill()
            ctx.fill(CGRect(origin: .zero, size: panelSize))
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let font = UIFont.monospacedSystemFont(ofSize: 5, weight: .medium)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: foreground,
                .paragraphStyle: paragraph,
            ]
            let text = lines.joined(separator: "\n") as NSString
            let inset = CGRect(x: 0, y: 2, width: panelSize.width, height: panelSize.height - 4)
            text.draw(with: inset, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
        }
        return img.pngData()
    }
}
