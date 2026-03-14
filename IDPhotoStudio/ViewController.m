#import "ViewController.h"
#import "EditorViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <PhotosUI/PhotosUI.h>

@interface ViewController () <PHPickerViewControllerDelegate, AVCapturePhotoCaptureDelegate>
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *previewContainer;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UIView *frameGuide;
@property (nonatomic, strong) UIButton *cameraButton;
@property (nonatomic, strong) UIButton *albumButton;
@property (nonatomic, strong) UILabel *statusLabel;

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCapturePhotoOutput *photoOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"AI证件照";
    self.view.backgroundColor = [UIColor colorWithRed:0.96 green:0.97 blue:0.99 alpha:1.0];
    [self setupUI];
    [self setupCameraPreviewIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.captureSession && !self.captureSession.isRunning) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
            [self.captureSession startRunning];
        });
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.captureSession stopRunning];
}

- (void)setupUI {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
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

    self.cameraButton = [self primaryButtonWithTitle:@"自拍拍摄" color:[UIColor colorWithRed:0.16 green:0.55 blue:0.96 alpha:1.0] action:@selector(capturePhoto)];
    self.albumButton = [self primaryButtonWithTitle:@"相册导入" color:[UIColor colorWithRed:0.42 green:0.44 blue:0.94 alpha:1.0] action:@selector(pickPhoto)];

    UIStackView *buttonStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.cameraButton, self.albumButton]];
    buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
    buttonStack.axis = UILayoutConstraintAxisHorizontal;
    buttonStack.distribution = UIStackViewDistributionFillEqually;
    buttonStack.spacing = 12;
    [self.cardView addSubview:buttonStack];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.text = @"拍照或导入后将进入下一页进行智能抠图与换底色";
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

        [self.frameGuide.centerXAnchor constraintEqualToAnchor:self.previewContainer.centerXAnchor],
        [self.frameGuide.centerYAnchor constraintEqualToAnchor:self.previewContainer.centerYAnchor constant:-8],
        [self.frameGuide.widthAnchor constraintEqualToAnchor:self.previewContainer.widthAnchor multiplier:0.68],
        [self.frameGuide.heightAnchor constraintEqualToAnchor:self.frameGuide.widthAnchor multiplier:4.0/3.0],

        [self.hintLabel.leadingAnchor constraintEqualToAnchor:self.previewContainer.leadingAnchor constant:10],
        [self.hintLabel.trailingAnchor constraintEqualToAnchor:self.previewContainer.trailingAnchor constant:-10],
        [self.hintLabel.bottomAnchor constraintEqualToAnchor:self.previewContainer.bottomAnchor constant:-12],

        [buttonStack.topAnchor constraintEqualToAnchor:self.previewContainer.bottomAnchor constant:16],
        [buttonStack.leadingAnchor constraintEqualToAnchor:self.previewContainer.leadingAnchor],
        [buttonStack.trailingAnchor constraintEqualToAnchor:self.previewContainer.trailingAnchor],
        [buttonStack.heightAnchor constraintEqualToConstant:46],

        [self.statusLabel.topAnchor constraintEqualToAnchor:buttonStack.bottomAnchor constant:16],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:buttonStack.leadingAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:buttonStack.trailingAnchor],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-16]
    ]];
}

- (UIButton *)primaryButtonWithTitle:(NSString *)title color:(UIColor *)color action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
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

    [self openEditorWithImage:image];
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

    NSItemProvider *provider = result.itemProvider;
    if (![provider canLoadObjectOfClass:[UIImage class]]) {
        self.statusLabel.text = @"图片加载失败";
        return;
    }

    __weak typeof(self) weakSelf = self;
    [provider loadObjectOfClass:[UIImage class] completionHandler:^(UIImage * _Nullable image, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (image == nil) {
                weakSelf.statusLabel.text = error.localizedDescription ?: @"图片加载失败";
                return;
            }
            [weakSelf openEditorWithImage:image];
        });
    }];
}

- (void)openEditorWithImage:(UIImage *)image {
    EditorViewController *editor = [[EditorViewController alloc] initWithImage:image];
    [self.navigationController pushViewController:editor animated:YES];
}

@end
