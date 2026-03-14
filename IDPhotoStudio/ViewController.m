#import "ViewController.h"
#import "ImageMattingService.h"
#import <PhotosUI/PhotosUI.h>

@interface ViewController () <PHPickerViewControllerDelegate, UIColorPickerViewControllerDelegate>
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIActivityIndicatorView *indicator;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *pickButton;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UIStackView *colorStack;
@property (nonatomic, strong) UIImage *originalImage;
@property (nonatomic, strong) UIImage *processedImage;
@property (nonatomic, strong) UIColor *selectedColor;
@property (nonatomic, strong) ImageMattingService *mattingService;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"证件照换底色(OC)";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.selectedColor = UIColor.blueColor;
    self.mattingService = [[ImageMattingService alloc] init];
    [self setupUI];
}

- (void)setupUI {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll];

    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:content];

    self.imageView = [[UIImageView alloc] init];
    self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.imageView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.imageView.layer.cornerRadius = 16;
    self.imageView.layer.masksToBounds = YES;
    [content addSubview:self.imageView];

    self.pickButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.pickButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.pickButton setTitle:@"从相册选择照片" forState:UIControlStateNormal];
    self.pickButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    self.pickButton.backgroundColor = UIColor.systemBlueColor;
    [self.pickButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.pickButton.layer.cornerRadius = 10;
    [self.pickButton addTarget:self action:@selector(pickPhoto) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:self.pickButton];

    self.colorStack = [[UIStackView alloc] init];
    self.colorStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.colorStack.axis = UILayoutConstraintAxisHorizontal;
    self.colorStack.spacing = 12;
    [content addSubview:self.colorStack];

    NSArray<UIColor *> *colors = @[UIColor.blueColor, UIColor.redColor, UIColor.whiteColor, [UIColor colorWithRed:0.2 green:0.7 blue:1 alpha:1]];
    for (UIColor *color in colors) {
        UIButton *dot = [UIButton buttonWithType:UIButtonTypeSystem];
        dot.translatesAutoresizingMaskIntoConstraints = NO;
        dot.backgroundColor = color;
        dot.layer.cornerRadius = 16;
        dot.layer.borderWidth = 1;
        dot.layer.borderColor = UIColor.separatorColor.CGColor;
        [dot.widthAnchor constraintEqualToConstant:32].active = YES;
        [dot.heightAnchor constraintEqualToConstant:32].active = YES;
        [dot addTarget:self action:@selector(selectColor:) forControlEvents:UIControlEventTouchUpInside];
        [self.colorStack addArrangedSubview:dot];
    }

    UIButton *customButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [customButton setTitle:@"自定义" forState:UIControlStateNormal];
    [customButton addTarget:self action:@selector(showColorPicker) forControlEvents:UIControlEventTouchUpInside];
    [self.colorStack addArrangedSubview:customButton];

    self.saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.saveButton setTitle:@"保存到相册" forState:UIControlStateNormal];
    self.saveButton.layer.cornerRadius = 10;
    self.saveButton.layer.borderWidth = 1;
    self.saveButton.layer.borderColor = UIColor.separatorColor.CGColor;
    [self.saveButton addTarget:self action:@selector(saveResult) forControlEvents:UIControlEventTouchUpInside];
    self.saveButton.enabled = NO;
    [content addSubview:self.saveButton];

    self.indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.indicator.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:self.indicator];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.text = @"请选择正面人像，使用高精度抠图换底色";
    self.statusLabel.textColor = UIColor.secondaryLabelColor;
    self.statusLabel.font = [UIFont systemFontOfSize:13];
    [content addSubview:self.statusLabel];

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

        [self.imageView.topAnchor constraintEqualToAnchor:content.topAnchor constant:16],
        [self.imageView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [self.imageView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [self.imageView.heightAnchor constraintEqualToConstant:360],

        [self.pickButton.topAnchor constraintEqualToAnchor:self.imageView.bottomAnchor constant:16],
        [self.pickButton.leadingAnchor constraintEqualToAnchor:self.imageView.leadingAnchor],
        [self.pickButton.trailingAnchor constraintEqualToAnchor:self.imageView.trailingAnchor],
        [self.pickButton.heightAnchor constraintEqualToConstant:44],

        [self.colorStack.topAnchor constraintEqualToAnchor:self.pickButton.bottomAnchor constant:14],
        [self.colorStack.leadingAnchor constraintEqualToAnchor:self.pickButton.leadingAnchor],

        [self.saveButton.topAnchor constraintEqualToAnchor:self.colorStack.bottomAnchor constant:14],
        [self.saveButton.leadingAnchor constraintEqualToAnchor:self.pickButton.leadingAnchor],
        [self.saveButton.trailingAnchor constraintEqualToAnchor:self.pickButton.trailingAnchor],
        [self.saveButton.heightAnchor constraintEqualToConstant:42],

        [self.indicator.topAnchor constraintEqualToAnchor:self.saveButton.bottomAnchor constant:12],
        [self.indicator.leadingAnchor constraintEqualToAnchor:self.saveButton.leadingAnchor],

        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.indicator.centerYAnchor],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.indicator.trailingAnchor constant:8],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.saveButton.trailingAnchor],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-24]
    ]];
}

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
    if (result == nil) return;

    [self setProcessing:YES text:@"AI 抠图处理中..."];
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
            weakSelf.originalImage = image;
            [weakSelf renderWithCurrentColor];
        });
    }];
}

- (void)selectColor:(UIButton *)sender {
    self.selectedColor = sender.backgroundColor;
    [self renderWithCurrentColor];
}

- (void)showColorPicker {
    if (@available(iOS 14.0, *)) {
        UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
        picker.selectedColor = self.selectedColor;
        __weak typeof(self) weakSelf = self;
        picker.supportsAlpha = NO;
        picker.modalPresentationStyle = UIModalPresentationPopover;
        [self presentViewController:picker animated:YES completion:nil];
        picker.delegate = (id<UIColorPickerViewControllerDelegate>)weakSelf;
    }
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0)) {
    self.selectedColor = viewController.selectedColor;
    [self renderWithCurrentColor];
}

- (void)renderWithCurrentColor {
    if (self.originalImage == nil) {
        return;
    }

    [self setProcessing:YES text:@"AI 抠图处理中..."];
    UIImage *source = self.originalImage;
    UIColor *bg = self.selectedColor;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_USER_INITIATED, 0), ^{
        NSError *error = nil;
        UIImage *result = [weakSelf.mattingService processImage:source backgroundColor:bg error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (result != nil) {
                weakSelf.processedImage = result;
                weakSelf.imageView.image = result;
                weakSelf.saveButton.enabled = YES;
                [weakSelf setProcessing:NO text:@"完成，可继续切换底色"];
            } else {
                [weakSelf setProcessing:NO text:error.localizedDescription ?: @"处理失败"];
            }
        });
    });
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
