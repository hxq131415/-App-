#import "EditorViewController.h"
#import "ImageMattingService.h"
#import <CoreImage/CoreImage.h>

@interface EditorViewController () <UIColorPickerViewControllerDelegate>
@property (nonatomic, strong) UIImageView *previewImageView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *indicator;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UISlider *beautySlider;
@property (nonatomic, strong) UILabel *beautyValueLabel;

@property (nonatomic, strong) UIImage *originalImage;
@property (nonatomic, strong) UIImage *processedImage;
@property (nonatomic, strong) UIColor *selectedColor;
@property (nonatomic, assign) CGFloat beautyLevel;
@property (nonatomic, strong) NSArray<UIButton *> *colorButtons;

@property (nonatomic, strong) ImageMattingService *mattingService;
@property (nonatomic, strong) CIContext *ciContext;
@end

@implementation EditorViewController

- (instancetype)initWithImage:(UIImage *)image {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _originalImage = image;
        _selectedColor = [UIColor colorWithRed:0.19 green:0.53 blue:0.95 alpha:1.0];
        _beautyLevel = 0.35;
        _mattingService = [[ImageMattingService alloc] init];
        _ciContext = [CIContext contextWithOptions:nil];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"证件照编辑";
    self.view.backgroundColor = [UIColor colorWithRed:0.96 green:0.97 blue:0.99 alpha:1.0];
    [self setupUI];
    [self renderWithCurrentConfig];
}

- (void)setupUI {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll];

    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:content];

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = UIColor.whiteColor;
    card.layer.cornerRadius = 22;
    card.layer.shadowColor = [UIColor colorWithWhite:0 alpha:0.12].CGColor;
    card.layer.shadowOffset = CGSizeMake(0, 8);
    card.layer.shadowRadius = 24;
    card.layer.shadowOpacity = 1;
    [content addSubview:card];

    self.previewImageView = [[UIImageView alloc] initWithImage:self.originalImage];
    self.previewImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.previewImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.previewImageView.backgroundColor = [UIColor colorWithRed:0.92 green:0.93 blue:0.96 alpha:1];
    self.previewImageView.layer.cornerRadius = 16;
    self.previewImageView.layer.masksToBounds = YES;
    [card addSubview:self.previewImageView];

    UILabel *beautyTitle = [[UILabel alloc] init];
    beautyTitle.translatesAutoresizingMaskIntoConstraints = NO;
    beautyTitle.text = @"美颜强度";
    beautyTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [card addSubview:beautyTitle];

    self.beautyValueLabel = [[UILabel alloc] init];
    self.beautyValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.beautyValueLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
    self.beautyValueLabel.textColor = [UIColor colorWithRed:0.33 green:0.35 blue:0.44 alpha:1.0];
    [card addSubview:self.beautyValueLabel];

    self.beautySlider = [[UISlider alloc] init];
    self.beautySlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.beautySlider.minimumValue = 0;
    self.beautySlider.maximumValue = 1;
    self.beautySlider.value = self.beautyLevel;
    self.beautySlider.minimumTrackTintColor = [UIColor colorWithRed:0.26 green:0.61 blue:0.96 alpha:1.0];
    [self.beautySlider addTarget:self action:@selector(beautyChanged:) forControlEvents:UIControlEventValueChanged];
    [card addSubview:self.beautySlider];

    UILabel *bgTitle = [[UILabel alloc] init];
    bgTitle.translatesAutoresizingMaskIntoConstraints = NO;
    bgTitle.text = @"证件照底色";
    bgTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [card addSubview:bgTitle];

    UIStackView *colorStack = [[UIStackView alloc] init];
    colorStack.translatesAutoresizingMaskIntoConstraints = NO;
    colorStack.axis = UILayoutConstraintAxisHorizontal;
    colorStack.spacing = 12;
    [card addSubview:colorStack];

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
        [colorStack addArrangedSubview:dot];
        [dots addObject:dot];
    }
    self.colorButtons = dots;

    UIButton *customButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [customButton setTitle:@"自定义" forState:UIControlStateNormal];
    customButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [customButton addTarget:self action:@selector(showColorPicker) forControlEvents:UIControlEventTouchUpInside];
    [colorStack addArrangedSubview:customButton];

    self.saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.saveButton setTitle:@"保存证件照" forState:UIControlStateNormal];
    self.saveButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    self.saveButton.backgroundColor = [UIColor colorWithRed:0.12 green:0.75 blue:0.45 alpha:1.0];
    [self.saveButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.saveButton.layer.cornerRadius = 12;
    [self.saveButton addTarget:self action:@selector(saveResult) forControlEvents:UIControlEventTouchUpInside];
    self.saveButton.enabled = NO;
    [card addSubview:self.saveButton];

    self.indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.indicator.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:self.indicator];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.text = @"AI 抠图处理中...";
    self.statusLabel.textColor = [UIColor colorWithRed:0.42 green:0.45 blue:0.56 alpha:1.0];
    self.statusLabel.font = [UIFont systemFontOfSize:13];
    [card addSubview:self.statusLabel];

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

        [card.topAnchor constraintEqualToAnchor:content.topAnchor constant:16],
        [card.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:14],
        [card.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-14],
        [card.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-16],

        [self.previewImageView.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [self.previewImageView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
        [self.previewImageView.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],
        [self.previewImageView.heightAnchor constraintEqualToAnchor:self.previewImageView.widthAnchor multiplier:4.0/3.0],

        [beautyTitle.topAnchor constraintEqualToAnchor:self.previewImageView.bottomAnchor constant:16],
        [beautyTitle.leadingAnchor constraintEqualToAnchor:self.previewImageView.leadingAnchor],

        [self.beautyValueLabel.centerYAnchor constraintEqualToAnchor:beautyTitle.centerYAnchor],
        [self.beautyValueLabel.trailingAnchor constraintEqualToAnchor:self.previewImageView.trailingAnchor],

        [self.beautySlider.topAnchor constraintEqualToAnchor:beautyTitle.bottomAnchor constant:8],
        [self.beautySlider.leadingAnchor constraintEqualToAnchor:self.previewImageView.leadingAnchor],
        [self.beautySlider.trailingAnchor constraintEqualToAnchor:self.previewImageView.trailingAnchor],

        [bgTitle.topAnchor constraintEqualToAnchor:self.beautySlider.bottomAnchor constant:16],
        [bgTitle.leadingAnchor constraintEqualToAnchor:self.previewImageView.leadingAnchor],

        [colorStack.topAnchor constraintEqualToAnchor:bgTitle.bottomAnchor constant:10],
        [colorStack.leadingAnchor constraintEqualToAnchor:self.previewImageView.leadingAnchor],

        [self.saveButton.topAnchor constraintEqualToAnchor:colorStack.bottomAnchor constant:18],
        [self.saveButton.leadingAnchor constraintEqualToAnchor:self.previewImageView.leadingAnchor],
        [self.saveButton.trailingAnchor constraintEqualToAnchor:self.previewImageView.trailingAnchor],
        [self.saveButton.heightAnchor constraintEqualToConstant:44],

        [self.indicator.topAnchor constraintEqualToAnchor:self.saveButton.bottomAnchor constant:14],
        [self.indicator.leadingAnchor constraintEqualToAnchor:self.saveButton.leadingAnchor],

        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.indicator.centerYAnchor],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.indicator.trailingAnchor constant:8],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.saveButton.trailingAnchor],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16]
    ]];

    [self updateBeautyLabel];
    [self updateColorSelectionUI];
}

- (void)beautyChanged:(UISlider *)slider {
    self.beautyLevel = slider.value;
    [self updateBeautyLabel];
    [self renderWithCurrentConfig];
}

- (void)updateBeautyLabel {
    self.beautyValueLabel.text = [NSString stringWithFormat:@"%.0f%%", self.beautyLevel * 100];
}

- (void)selectColor:(UIButton *)sender {
    self.selectedColor = sender.backgroundColor;
    [self updateColorSelectionUI];
    [self renderWithCurrentConfig];
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
    [self renderWithCurrentConfig];
}

- (void)renderWithCurrentConfig {
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
                weakSelf.previewImageView.image = result;
                weakSelf.saveButton.enabled = YES;
                [weakSelf setProcessing:NO text:@"完成：抠图效果已增强，可继续调节"];
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
    if (processing) {
        [self.indicator startAnimating];
    } else {
        [self.indicator stopAnimating];
    }
}

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
