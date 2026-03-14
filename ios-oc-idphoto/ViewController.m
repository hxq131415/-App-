#import "ViewController.h"
#import "IDPhotoProcessor.h"
#import <Photos/Photos.h>

@interface ViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (nonatomic, strong) UIImageView *previewImageView;
@property (nonatomic, strong) UISegmentedControl *sizeSegment;
@property (nonatomic, strong) UISegmentedControl *bgSegment;
@property (nonatomic, strong) UISlider *zoomSlider;
@property (nonatomic, strong) UILabel *zoomLabel;
@property (nonatomic, strong) UIImage *sourceImage;
@property (nonatomic, strong) UIImage *resultImage;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"证件照工坊 OC";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    [self setupUI];
}

- (void)setupUI {
    UIButton *pickButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [pickButton setTitle:@"上传照片" forState:UIControlStateNormal];
    [pickButton addTarget:self action:@selector(pickImage) forControlEvents:UIControlEventTouchUpInside];

    UIButton *saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [saveButton setTitle:@"导出到相册" forState:UIControlStateNormal];
    [saveButton addTarget:self action:@selector(savePhoto) forControlEvents:UIControlEventTouchUpInside];

    self.sizeSegment = [[UISegmentedControl alloc] initWithItems:@[@"一寸", @"二寸", @"小二寸", @"护照"]];
    self.sizeSegment.selectedSegmentIndex = 1;
    [self.sizeSegment addTarget:self action:@selector(rebuildResult) forControlEvents:UIControlEventValueChanged];

    self.bgSegment = [[UISegmentedControl alloc] initWithItems:@[@"蓝底", @"白底", @"红底", @"灰底"]];
    self.bgSegment.selectedSegmentIndex = 0;
    [self.bgSegment addTarget:self action:@selector(rebuildResult) forControlEvents:UIControlEventValueChanged];

    self.zoomSlider = [[UISlider alloc] init];
    self.zoomSlider.minimumValue = 0.7;
    self.zoomSlider.maximumValue = 1.4;
    self.zoomSlider.value = 1.0;
    [self.zoomSlider addTarget:self action:@selector(onZoomChange) forControlEvents:UIControlEventValueChanged];

    self.zoomLabel = [[UILabel alloc] init];
    self.zoomLabel.text = @"缩放 100%";
    self.zoomLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];

    self.previewImageView = [[UIImageView alloc] init];
    self.previewImageView.backgroundColor = [UIColor whiteColor];
    self.previewImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.previewImageView.layer.cornerRadius = 12;
    self.previewImageView.clipsToBounds = YES;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        pickButton,
        self.sizeSegment,
        self.bgSegment,
        self.zoomLabel,
        self.zoomSlider,
        saveButton,
        self.previewImageView
    ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [self.previewImageView.heightAnchor constraintEqualToConstant:420]
    ]];
}

- (void)pickImage {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)savePhoto {
    if (!self.resultImage) {
        return;
    }

    UIImageWriteToSavedPhotosAlbum(self.resultImage, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    NSString *message = error ? @"保存失败" : @"保存成功";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)onZoomChange {
    NSInteger percent = (NSInteger)roundf(self.zoomSlider.value * 100);
    self.zoomLabel.text = [NSString stringWithFormat:@"缩放 %ld%%", (long)percent];
    [self rebuildResult];
}

- (UIColor *)selectedBackgroundColor {
    switch (self.bgSegment.selectedSegmentIndex) {
        case 0:
            return [UIColor colorWithRed:0.31 green:0.62 blue:0.97 alpha:1];
        case 1:
            return [UIColor whiteColor];
        case 2:
            return [UIColor colorWithRed:0.92 green:0.35 blue:0.35 alpha:1];
        case 3:
            return [UIColor colorWithRed:0.83 green:0.85 blue:0.89 alpha:1];
        default:
            return [UIColor whiteColor];
    }
}

- (void)rebuildResult {
    if (!self.sourceImage) {
        return;
    }

    IDPhotoPreset preset = (IDPhotoPreset)self.sizeSegment.selectedSegmentIndex;
    UIColor *bgColor = [self selectedBackgroundColor];

    self.resultImage = [IDPhotoProcessor renderIDPhotoWithSource:self.sourceImage
                                                          preset:preset
                                                 backgroundColor:bgColor
                                                            zoom:self.zoomSlider.value];
    self.previewImageView.image = self.resultImage;
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    self.sourceImage = image;
    [picker dismissViewControllerAnimated:YES completion:nil];
    [self rebuildResult];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end
