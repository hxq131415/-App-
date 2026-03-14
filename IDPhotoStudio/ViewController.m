#import "ViewController.h"
#import "ImageMattingService.h"
#import <PhotosUI/PhotosUI.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>

@interface ViewController () <PHPickerViewControllerDelegate, UIColorPickerViewControllerDelegate, AVCapturePhotoCaptureDelegate>
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *previewContainer;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIView *frameGuide;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UIStackView *buttonStack;
@property (nonatomic, strong) UIButton *cameraButton;
@property (nonatomic, strong) UIButton *albumButton;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UIStackView *colorStack;
@property (nonatomic, strong) UISlider *beautySlider;
@property (nonatomic, strong) UILabel *beautyValueLabel;
@property (nonatomic, strong) UIActivityIndicatorView *indicator;
@property (nonatomic, strong) UILabel *statusLabel;

@property (nonatomic, strong) UIImage *originalImage;
@property (nonatomic, strong) UIImage *processedImage;
@property (nonatomic, strong) UIColor *selectedColor;
@property (nonatomic, assign) CGFloat beautyLevel;
@property (nonatomic, strong) NSArray<UIButton *> *colorButtons;

@property (nonatomic, strong) ImageMattingService *mattingService;
@property (nonatomic, strong) CIContext *ciContext;

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCapturePhotoOutput *photoOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"AI证件照";
    self.view.backgroundColor = [UIColor colorWithRed:0.96 green:0.97 blue:0.99 alpha:1.0];
    self.selectedColor = [UIColor colorWithRed:0.19 green:0.53 blue:0.95 alpha:1.0];
    self.beautyLevel = 0.45;
    self.mattingService = [[ImageMattingService alloc] init];
    self.ciContext = [CIContext contextWithOptions:nil];
    [self setupUI];
    [self setupCameraPreviewIfNeeded];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.captureSession stopRunning];
}

#pragma mark - UI

- (void)setupUI {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    [self.view addSubview:scroll];

    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:content];

    self.cardView = [[UIView alloc] init];
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardView.backgroundColor = UIColor.whiteColor;
    self.cardView.layer.cornerRadius = 22;
    self.cardView.layer.shadowColor = [UIColor colorWithWhite:0 alpha:0.12].CGColor;
    self.cardView.layer.shadowOffset = CGSizeMake(0, 8);
    self.cardView.layer.shadowRadius = 24;
    self.cardView.layer.shadowOpacity = 1;
    [content addSubview:self.cardView];

    self.previewContainer = [[UIView alloc] init];
    self.previewContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.previewContainer.layer.cornerRadius = 18;
    self.previewContainer.layer.masksToBounds = YES;
    self.previewContainer.backgroundColor = [UIColor colorWithRed:0.88 green:0.90 blue:0.95 alpha:1];
    [self.cardView addSubview:self.previewContainer];

    self.imageView = [[UIImageView alloc] init];
    self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.imageView.hidden = YES;
    [self.previewContainer addSubview:self.imageView];

    self.frameGuide = [[UIView alloc] init];
    self.frameGuide.translatesAutoresizingMaskIntoConstraints = NO;
    self.frameGuide.layer.cornerRadius = 10;
    self.frameGuide.layer.borderWidth = 2;
    self.frameGuide.layer.borderColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.9].CGColor;
    self.frameGuide.userInteractionEnabled = NO;
    [self.previewContainer addSubview:self.frameGuide];

    self.hintLabel = [[UILabel alloc] init];
    self.hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.hintLabel.text = @"请将人像置于框中并保持正面";
    self.hintLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.hintLabel.textColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.96];
    self.hintLabel.textAlignment = NSTextAlignmentCenter;
    [self.previewContainer addSubview:self.hintLabel];

    self.buttonStack = [[UIStackView alloc] init];
    self.buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.buttonStack.axis = UILayoutConstraintAxisHorizontal;
    self.buttonStack.distribution = UIStackViewDistributionFillEqually;
    self.buttonStack.spacing = 12;
    [self.cardView addSubview:self.buttonStack];

    self.cameraButton = [self primaryButtonWithTitle:@"自拍拍摄" color:[UIColor colorWithRed:0.16 green:0.55 blue:0.96 alpha:1.0] action:@selector(capturePhoto)];
    self.albumButton = [self primaryButtonWithTitle:@"相册导入" color:[UIColor colorWithRed:0.42 green:0.44 blue:0.94 alpha:1.0] action:@selector(pickPhoto)];
    [self.buttonStack addArrangedSubview:self.cameraButton];
    [self.buttonStack addArrangedSubview:self.albumButton];

    UILabel *beautyTitle = [[UILabel alloc] init];
    beautyTitle.translatesAutoresizingMaskIntoConstraints = NO;
    beautyTitle.text = @"美颜强度";
    beautyTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    beautyTitle.textColor = [UIColor colorWithRed:0.15 green:0.17 blue:0.25 alpha:1.0];
    [self.cardView addSubview:beautyTitle];

    self.beautyValueLabel = [[UILabel alloc] init];
    self.beautyValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.beautyValueLabel.textColor = [UIColor colorWithRed:0.33 green:0.35 blue:0.44 alpha:1.0];
    self.beautyValueLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
    [self.cardView addSubview:self.beautyValueLabel];

    self.beautySlider = [[UISlider alloc] init];
    self.beautySlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.beautySlider.minimumValue = 0;
    self.beautySlider.maximumValue = 1;
    self.beautySlider.value = self.beautyLevel;
    self.beautySlider.minimumTrackTintColor = [UIColor colorWithRed:0.26 green:0.61 blue:0.96 alpha:1.0];
    [self.beautySlider addTarget:self action:@selector(beautyChanged:) forControlEvents:UIControlEventValueChanged];
    [self.cardView addSubview:self.beautySlider];

    UILabel *bgTitle = [[UILabel alloc] init];
    bgTitle.translatesAutoresizingMaskIntoConstraints = NO;
    bgTitle.text = @"证件照底色";
    bgTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    bgTitle.textColor = [UIColor colorWithRed:0.15 green:0.17 blue:0.25 alpha:1.0];
    [self.cardView addSubview:bgTitle];

    self.colorStack = [[UIStackView alloc] init];
    self.colorStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.colorStack.axis = UILayoutConstraintAxisHorizontal;
    self.colorStack.spacing = 12;
    [self.cardView addSubview:self.colorStack];

    NSArray<UIColor *> *presetColors = @[
        [UIColor colorWithRed:0.19 green:0.53 blue:0.95 alpha:1.0],
        [UIColor colorWithRed:0.93 green:0.20 blue:0.26 alpha:1.0],
        [UIColor whiteColor],
        [UIColor colorWithRed:0.27 green:0.67 blue:0.95 alpha:1.0]
    ];

    NSMutableArray<UIButton *> *dots = [NSMutableArray array];
    for (UIColor *color in presetColors) {
        UIButton *dot = [UIButton buttonWithType:UIButtonTypeSystem];
        dot.translatesAutoresizingMaskIntoConstraints = NO;
        dot.backgroundColor = color;
        dot.layer.cornerRadius = 16;
        dot.layer.borderWidth = 1;
        dot.layer.borderColor = [UIColor colorWithWhite:0 alpha:0.12].CGColor;
        [dot.widthAnchor constraintEqualToConstant:32].active = YES;
        [dot.heightAnchor constraintEqualToConstant:32].active = YES;
        [dot addTarget:self action:@selector(selectColor:) forControlEvents:UIControlEventTouchUpInside];
        [self.colorStack addArrangedSubview:dot];
        [dots addObject:dot];
    }
    self.colorButtons = dots;

    UIButton *customButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [customButton setTitle:@"自定义" forState:UIControlStateNormal];
    customButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [customButton addTarget:self action:@selector(showColorPicker) forControlEvents:UIControlEventTouchUpInside];
    [self.colorStack addArrangedSubview:customButton];

    self.saveButton = [self primaryButtonWithTitle:@"保存证件照" color:[UIColor colorWithRed:0.12 green:0.75 blue:0.45 alpha:1.0] action:@selector(saveResult)];
    self.saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveButton.enabled = NO;
    [self.cardView addSubview:self.saveButton];

    self.indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.indicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cardView addSubview:self.indicator];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.text = @"自拍或导入照片后可智能抠图、换底色与美颜";
    self.statusLabel.textColor = [UIColor colorWithRed:0.42 green:0.45 blue:0.56 alpha:1.0];
    self.statusLabel.font = [UIFont systemFontOfSize:13];
    [self.cardView addSubview:self.statusLabel];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [content.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [content.widthAnchor constraintEqualToAnchor:scroll.widthAnchor],

        [self.cardView.topAnchor constraintEqualToAnchor:content.topAnchor constant:16],
        [self.cardView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:14],
        [self.cardView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-14],
        [self.cardView.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-16],

        [self.previewContainer.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:14],
        [self.previewContainer.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:14],
        [self.previewContainer.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-14],
        [self.previewContainer.heightAnchor constraintEqualToAnchor:self.previewContainer.widthAnchor multiplier:4.0/3.0],

        [self.imageView.topAnchor constraintEqualToAnchor:self.previewContainer.topAnchor],
        [self.imageView.leadingAnchor constraintEqualToAnchor:self.previewContainer.leadingAnchor],
        [self.imageView.trailingAnchor constraintEqualToAnchor:self.previewContainer.trailingAnchor],
        [self.imageView.bottomAnchor constraintEqualToAnchor:self.previewContainer.bottomAnchor],

        [self.frameGuide.centerXAnchor constraintEqualToAnchor:self.previewContainer.centerXAnchor],
        [self.frameGuide.centerYAnchor constraintEqualToAnchor:self.previewContainer.centerYAnchor constant:-8],
        [self.frameGuide.widthAnchor constraintEqualToAnchor:self.previewContainer.widthAnchor multiplier:0.68],
        [self.frameGuide.heightAnchor constraintEqualToAnchor:self.frameGuide.widthAnchor multiplier:4.0/3.0],

        [self.hintLabel.leadingAnchor constraintEqualToAnchor:self.previewContainer.leadingAnchor constant:10],
        [self.hintLabel.trailingAnchor constraintEqualToAnchor:self.previewContainer.trailingAnchor constant:-10],
        [self.hintLabel.bottomAnchor constraintEqualToAnchor:self.previewContainer.bottomAnchor constant:-12],

        [self.buttonStack.topAnchor constraintEqualToAnchor:self.previewContainer.bottomAnchor constant:14],
        [self.buttonStack.leadingAnchor constraintEqualToAnchor:self.previewContainer.leadingAnchor],
        [self.buttonStack.trailingAnchor constraintEqualToAnchor:self.previewContainer.trailingAnchor],
        [self.buttonStack.heightAnchor constraintEqualToConstant:44],

        [beautyTitle.topAnchor constraintEqualToAnchor:self.buttonStack.bottomAnchor constant:16],
        [beautyTitle.leadingAnchor constraintEqualToAnchor:self.buttonStack.leadingAnchor],

        [self.beautyValueLabel.centerYAnchor constraintEqualToAnchor:beautyTitle.centerYAnchor],
        [self.beautyValueLabel.trailingAnchor constraintEqualToAnchor:self.buttonStack.trailingAnchor],

        [self.beautySlider.topAnchor constraintEqualToAnchor:beautyTitle.bottomAnchor constant:8],
        [self.beautySlider.leadingAnchor constraintEqualToAnchor:self.buttonStack.leadingAnchor],
        [self.beautySlider.trailingAnchor constraintEqualToAnchor:self.buttonStack.trailingAnchor],

        [bgTitle.topAnchor constraintEqualToAnchor:self.beautySlider.bottomAnchor constant:16],
        [bgTitle.leadingAnchor constraintEqualToAnchor:self.buttonStack.leadingAnchor],

        [self.colorStack.topAnchor constraintEqualToAnchor:bgTitle.bottomAnchor constant:10],
        [self.colorStack.leadingAnchor constraintEqualToAnchor:self.buttonStack.leadingAnchor],

        [self.saveButton.topAnchor constraintEqualToAnchor:self.colorStack.bottomAnchor constant:18],
        [self.saveButton.leadingAnchor constraintEqualToAnchor:self.buttonStack.leadingAnchor],
        [self.saveButton.trailingAnchor constraintEqualToAnchor:self.buttonStack.trailingAnchor],
        [self.saveButton.heightAnchor constraintEqualToConstant:44],

        [self.indicator.topAnchor constraintEqualToAnchor:self.saveButton.bottomAnchor constant:14],
        [self.indicator.leadingAnchor constraintEqualToAnchor:self.saveButton.leadingAnchor],

        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.indicator.centerYAnchor],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.indicator.trailingAnchor constant:8],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.saveButton.trailingAnchor],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-16]
    ]];

    [self updateBeautyLabel];
    [self updateColorSelectionUI];
}

- (UIButton *)primaryButtonWithTitle:(NSString *)title color:(UIColor *)color action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    button.backgroundColor = color;
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.layer.cornerRadius = 12;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

#pragma mark - Camera

- (void)setupCameraPreviewIfNeeded {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusDenied || status == AVAuthorizationStatusRestricted) {
        self.statusLabel.text = @"请在设置中开启相机权限后使用自拍";
        return;
    }

    if (status == AVAuthorizationStatusNotDetermined) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (granted) {
                    [self setupCameraPreviewIfNeeded];
                } else {
                    self.statusLabel.text = @"未授权相机，可从相册导入";
                }
            });
        }];
        return;
    }

    [self setupCaptureSession];
}

- (void)setupCaptureSession {
    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto;

    AVCaptureDevice *front = [self frontCameraDevice];
    if (front == nil) {
        self.statusLabel.text = @"设备不支持前置相机，可从相册导入";
        return;
    }

    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:front error:&error];
    if (error || ![self.captureSession canAddInput:input]) {
        self.statusLabel.text = @"相机初始化失败，可从相册导入";
        return;
    }
    [self.captureSession addInput:input];

    self.photoOutput = [[AVCapturePhotoOutput alloc] init];
    if ([self.captureSession canAddOutput:self.photoOutput]) {
        [self.captureSession addOutput:self.photoOutput];
    }

    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.frame = self.previewContainer.bounds;
    [self.previewContainer.layer insertSublayer:self.previewLayer atIndex:0];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        [self.captureSession startRunning];
    });
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.previewLayer.frame = self.previewContainer.bounds;
}

- (AVCaptureDevice *)frontCameraDevice {
    AVCaptureDeviceDiscoverySession *session = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
                                                                                                      mediaType:AVMediaTypeVideo
                                                                                                       position:AVCaptureDevicePositionFront];
    return session.devices.firstObject;
}

- (void)capturePhoto {
    if (self.photoOutput == nil) {
        self.statusLabel.text = @"相机不可用，请使用相册导入";
        return;
    }

    AVCapturePhotoSettings *settings = [AVCapturePhotoSettings photoSettings];
    settings.flashMode = AVCaptureFlashModeOff;
    [self.photoOutput capturePhotoWithSettings:settings delegate:self];
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error {
    if (error != nil) {
        self.statusLabel.text = error.localizedDescription ?: @"拍照失败";
        return;
    }

    NSData *data = [photo fileDataRepresentation];
    UIImage *image = [UIImage imageWithData:data];
    if (image == nil) {
        self.statusLabel.text = @"拍照失败，请重试";
        return;
    }

    [self processSelectedImage:image sourceText:@"自拍完成，正在智能美颜抠图..."];
}

#pragma mark - Album

- (void)pickPhoto {
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.selectionLimit = 1;
    config.filter = [PHPickerFilter imagesFilter];
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    PHPickerResult *result = results.firstObject;
    if (result == nil) {
        return;
    }

    [self setProcessing:YES text:@"正在读取图片..."];
    NSItemProvider *provider = result.itemProvider;
    if (![provider canLoadObjectOfClass:[UIImage class]]) {
        [self setProcessing:NO text:@"图片加载失败"];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [provider loadObjectOfClass:[UIImage class] completionHandler:^(UIImage * _Nullable image, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (image == nil) {
                [weakSelf setProcessing:NO text:error.localizedDescription ?: @"图片加载失败"];
                return;
            }
            [weakSelf processSelectedImage:image sourceText:@"相册导入完成，正在智能美颜抠图..."];
        });
    }];
}

#pragma mark - Processing

- (void)processSelectedImage:(UIImage *)image sourceText:(NSString *)sourceText {
    self.originalImage = image;
    self.imageView.hidden = NO;
    self.imageView.image = image;
    [self setProcessing:YES text:sourceText];
    [self renderWithCurrentConfig];
}

- (void)beautyChanged:(UISlider *)slider {
    self.beautyLevel = slider.value;
    [self updateBeautyLabel];
    if (self.originalImage != nil) {
        [self renderWithCurrentConfig];
    }
}

- (void)updateBeautyLabel {
    self.beautyValueLabel.text = [NSString stringWithFormat:@"%.0f%%", self.beautyLevel * 100];
}

- (void)selectColor:(UIButton *)sender {
    self.selectedColor = sender.backgroundColor;
    [self updateColorSelectionUI];
    if (self.originalImage != nil) {
        [self renderWithCurrentConfig];
    }
}

- (void)updateColorSelectionUI {
    for (UIButton *button in self.colorButtons) {
        BOOL selected = [button.backgroundColor isEqual:self.selectedColor];
        button.layer.borderWidth = selected ? 2.5 : 1.0;
        button.layer.borderColor = selected ? [UIColor colorWithRed:0.15 green:0.25 blue:0.6 alpha:0.95].CGColor : [UIColor colorWithWhite:0 alpha:0.12].CGColor;
        button.transform = selected ? CGAffineTransformMakeScale(1.1, 1.1) : CGAffineTransformIdentity;
    }
}

- (void)showColorPicker {
    if (@available(iOS 14.0, *)) {
        UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
        picker.selectedColor = self.selectedColor;
        picker.supportsAlpha = NO;
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    }
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0)) {
    self.selectedColor = viewController.selectedColor;
    [self updateColorSelectionUI];
    if (self.originalImage != nil) {
        [self renderWithCurrentConfig];
    }
}

- (void)renderWithCurrentConfig {
    if (self.originalImage == nil) {
        return;
    }

    UIImage *source = self.originalImage;
    UIColor *bg = self.selectedColor;
    CGFloat beautyLevel = self.beautyLevel;
    [self setProcessing:YES text:@"AI 抠图与美颜处理中..."];

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        UIImage *beautified = [weakSelf beautyImageFromImage:source level:beautyLevel];

        NSError *error = nil;
        UIImage *result = [weakSelf.mattingService processImage:beautified backgroundColor:bg error:&error];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (result != nil) {
                weakSelf.processedImage = result;
                weakSelf.imageView.image = result;
                weakSelf.saveButton.enabled = YES;
                [weakSelf setProcessing:NO text:@"完成：已智能抠图+换底色，可继续微调"];
            } else {
                [weakSelf setProcessing:NO text:error.localizedDescription ?: @"处理失败，请重试"];
            }
        });
    });
}

- (UIImage *)beautyImageFromImage:(UIImage *)image level:(CGFloat)level {
    if (level <= 0.01 || image.CGImage == nil) {
        return image;
    }

    CIImage *input = [CIImage imageWithCGImage:image.CGImage];

    CIFilter *noiseReduction = [CIFilter filterWithName:@"CINoiseReduction"];
    [noiseReduction setValue:input forKey:kCIInputImageKey];
    [noiseReduction setValue:@(0.01 + level * 0.04) forKey:@"inputNoiseLevel"];
    [noiseReduction setValue:@(0.2 + level * 0.5) forKey:@"inputSharpness"];
    CIImage *smoothed = noiseReduction.outputImage ?: input;

    CIFilter *controls = [CIFilter filterWithName:@"CIColorControls"];
    [controls setValue:smoothed forKey:kCIInputImageKey];
    [controls setValue:@(1.0 + level * 0.07) forKey:kCIInputContrastKey];
    [controls setValue:@(0.01 + level * 0.03) forKey:kCIInputBrightnessKey];
    [controls setValue:@(1.0 + level * 0.05) forKey:kCIInputSaturationKey];

    CIImage *output = controls.outputImage ?: smoothed;
    CGImageRef cgImage = [self.ciContext createCGImage:output fromRect:output.extent];
    if (cgImage == nil) {
        return image;
    }

    UIImage *result = [UIImage imageWithCGImage:cgImage scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(cgImage);
    return result;
}

- (void)setProcessing:(BOOL)processing text:(NSString *)text {
    self.statusLabel.text = text;
    self.cameraButton.enabled = !processing;
    self.albumButton.enabled = !processing;
    if (processing) {
        [self.indicator startAnimating];
    } else {
        [self.indicator stopAnimating];
    }
}

#pragma mark - Save

- (void)saveResult {
    if (self.processedImage == nil) {
        return;
    }
    UIImageWriteToSavedPhotosAlbum(self.processedImage, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    self.statusLabel.text = error ? (error.localizedDescription ?: @"保存失败") : @"已保存到相册";
}

@end
