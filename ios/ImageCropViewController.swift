import UIKit

extension UIImage {
    /// 按像素坐标裁剪图片
    func cropped(to pixelRect: CGRect) -> UIImage? {
        let normalizedRect = CGRect(
            x: max(0, pixelRect.origin.x),
            y: max(0, pixelRect.origin.y),
            width: min(size.width * scale - max(0, pixelRect.origin.x), pixelRect.size.width),
            height: min(size.height * scale - max(0, pixelRect.origin.y), pixelRect.size.height)
        ).integral

        guard normalizedRect.width > 0,
              normalizedRect.height > 0,
              let cgImage,
              let cropped = cgImage.cropping(to: normalizedRect)
        else {
            return nil
        }

        return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }
}

final class ImageCropViewController: UIViewController, UIScrollViewDelegate {
    private let image: UIImage
    private let aspectRatio: CGSize
    private let completion: (UIImage) -> Void

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let maskLayer = CAShapeLayer()
    private let cropBorder = UIView()

    private var cropFrame: CGRect = .zero

    init(image: UIImage, aspectRatio: CGSize = CGSize(width: 1, height: 1), completion: @escaping (UIImage) -> Void) {
        self.image = image
        self.aspectRatio = aspectRatio
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = "裁剪"

        setupNavigation()
        setupScrollView()
        setupMask()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutCropArea()
        configureImageLayoutIfNeeded()
    }

    private func setupNavigation() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "裁剪",
            style: .done,
            target: self,
            action: #selector(cropAction)
        )
    }

    private func setupScrollView() {
        scrollView.delegate = self
        scrollView.backgroundColor = .black
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.maximumZoomScale = 6
        scrollView.minimumZoomScale = 1

        imageView.image = image
        imageView.contentMode = .scaleAspectFit

        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
    }

    private func setupMask() {
        cropBorder.layer.borderColor = UIColor.white.cgColor
        cropBorder.layer.borderWidth = 1
        cropBorder.isUserInteractionEnabled = false

        maskLayer.fillRule = .evenOdd
        maskLayer.fillColor = UIColor.black.withAlphaComponent(0.55).cgColor

        view.layer.addSublayer(maskLayer)
        view.addSubview(cropBorder)
    }

    private func layoutCropArea() {
        scrollView.frame = view.bounds

        let horizontalPadding: CGFloat = 24
        let availableWidth = view.bounds.width - horizontalPadding * 2
        let maxHeight = view.bounds.height * 0.6

        let ratio = aspectRatio.width / max(aspectRatio.height, 0.01)
        var cropWidth = availableWidth
        var cropHeight = cropWidth / ratio

        if cropHeight > maxHeight {
            cropHeight = maxHeight
            cropWidth = cropHeight * ratio
        }

        cropFrame = CGRect(
            x: (view.bounds.width - cropWidth) / 2,
            y: (view.bounds.height - cropHeight) / 2,
            width: cropWidth,
            height: cropHeight
        )

        cropBorder.frame = cropFrame

        let path = UIBezierPath(rect: view.bounds)
        path.append(UIBezierPath(rect: cropFrame))
        maskLayer.path = path.cgPath
    }

    private func configureImageLayoutIfNeeded() {
        guard imageView.frame == .zero else { return }

        let imageSize = image.size
        let scale = max(cropFrame.width / imageSize.width, cropFrame.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale

        imageView.frame = CGRect(x: 0, y: 0, width: width, height: height)
        scrollView.contentSize = imageView.bounds.size

        let offsetX = (width - cropFrame.width) / 2
        let offsetY = (height - cropFrame.height) / 2
        scrollView.contentOffset = CGPoint(x: max(0, offsetX), y: max(0, offsetY))

        let minScaleX = cropFrame.width / width
        let minScaleY = cropFrame.height / height
        let minScale = max(minScaleX, minScaleY)

        scrollView.minimumZoomScale = minScale
        scrollView.zoomScale = minScale
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    @objc
    private func cropAction() {
        let zoomScale = scrollView.zoomScale
        let visibleRect = CGRect(
            x: scrollView.contentOffset.x / zoomScale,
            y: scrollView.contentOffset.y / zoomScale,
            width: cropFrame.width / zoomScale,
            height: cropFrame.height / zoomScale
        )

        let imageScaleX = image.size.width / imageView.bounds.width
        let imageScaleY = image.size.height / imageView.bounds.height

        let pixelRect = CGRect(
            x: visibleRect.origin.x * imageScaleX * image.scale,
            y: visibleRect.origin.y * imageScaleY * image.scale,
            width: visibleRect.width * imageScaleX * image.scale,
            height: visibleRect.height * imageScaleY * image.scale
        )

        guard let result = image.cropped(to: pixelRect) else { return }
        completion(result)
        navigationController?.popViewController(animated: true)
    }
}
