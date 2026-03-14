import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

struct ImageMattingService {
    enum MattingError: LocalizedError {
        case cannotCreateCGImage
        case cannotCreateMask
        case renderFailed

        var errorDescription: String? {
            switch self {
            case .cannotCreateCGImage:
                return "无法读取图片像素。"
            case .cannotCreateMask:
                return "未识别到清晰的人像主体，请尝试更换图片。"
            case .renderFailed:
                return "处理失败，请重试。"
            }
        }
    }

    private let ciContext = CIContext(options: [.cacheIntermediates: false])

    func process(image: UIImage, background color: UIColor) throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw MattingError.cannotCreateCGImage
        }

        let mask = try personMask(for: cgImage, orientation: image.cgImageOrientation)

        let inputImage = CIImage(cgImage: cgImage)
        let targetSize = inputImage.extent.size
        let resizedMask = resizeMask(mask, to: targetSize)
        let refinedMask = soften(mask: resizedMask)

        let background = CIImage(color: CIColor(color: color))
            .cropped(to: inputImage.extent)

        let blend = CIFilter.blendWithMask()
        blend.inputImage = inputImage
        blend.backgroundImage = background
        blend.maskImage = refinedMask

        guard let output = blend.outputImage,
              let renderedCGImage = ciContext.createCGImage(output, from: output.extent) else {
            throw MattingError.renderFailed
        }

        return UIImage(cgImage: renderedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func personMask(for cgImage: CGImage, orientation: CGImagePropertyOrientation) throws -> CIImage {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        request.usesCPUOnly = false

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
        try handler.perform([request])

        guard let pixelBuffer = request.results?.first?.pixelBuffer else {
            throw MattingError.cannotCreateMask
        }

        return CIImage(cvPixelBuffer: pixelBuffer)
    }

    private func resizeMask(_ mask: CIImage, to targetSize: CGSize) -> CIImage {
        let scaleX = targetSize.width / mask.extent.width
        let scaleY = targetSize.height / mask.extent.height
        let scaled = mask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let clamp = CIFilter.affineClamp()
        clamp.inputImage = scaled
        clamp.transform = .identity
        let clamped = clamp.outputImage ?? scaled

        let lanczos = CIFilter.lanczosScaleTransform()
        lanczos.inputImage = clamped
        lanczos.scale = 1
        lanczos.aspectRatio = 1
        return lanczos.outputImage?.cropped(to: CGRect(origin: .zero, size: targetSize)) ?? scaled
    }

    private func soften(mask: CIImage) -> CIImage {
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = mask
        blur.radius = 1.2

        let blurred = blur.outputImage?.cropped(to: mask.extent) ?? mask

        let controls = CIFilter.colorControls()
        controls.inputImage = blurred
        controls.contrast = 1.15
        controls.brightness = 0
        controls.saturation = 0

        return controls.outputImage?.cropped(to: mask.extent) ?? mask
    }
}

private extension UIImage {
    var cgImageOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
