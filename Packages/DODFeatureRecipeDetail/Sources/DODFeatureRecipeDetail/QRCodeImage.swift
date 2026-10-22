#if os(iOS) && canImport(UIKit)
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// DUT-977 — renders a QR code for the tent card.
enum QRCodeImage {

    /// `nil` only if Core Image fails. `scale` multiplies the native module grid so edges stay sharp.
    static func make(from string: String, scale: CGFloat = 10) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
#endif
