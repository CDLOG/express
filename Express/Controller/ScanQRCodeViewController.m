//
//  ScanQRCodeViewController.m
//  Express
//
//  Created by LeeLom on 16/8/1.
//  Copyright © 2016年 LeeLom. All rights reserved.
//

#import "ScanQRCodeViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ScanQRCodeViewController ()<UITabBarDelegate,AVCaptureMetadataOutputObjectsDelegate,UINavigationControllerDelegate,UIImagePickerControllerDelegate>
@property (strong, nonatomic) AVCaptureDevice* device;
@property (strong, nonatomic) AVCaptureDeviceInput* input;
@property (strong, nonatomic) AVCaptureMetadataOutput* output;
@property (strong, nonatomic) AVCaptureSession* session;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer* previewLayer;

@property (strong, nonatomic) IBOutlet UIView *customContainerView;
@property (strong, nonatomic) IBOutlet UIImageView *scanLineImageView;
@property (strong, nonatomic) IBOutlet UILabel *customLabel;

/***专门用于保存描边的图层***/
@property (strong, nonatomic) CALayer* containerLayer;

@end

@implementation ScanQRCodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self startScan];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
#pragma mark 属性懒加载
-(AVCaptureDevice*)device{
    if (_device == nil) {
        _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    return _device;
}
-(AVCaptureDeviceInput*)input{
    if (_input == nil) {
        _input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
    }
    return _input;
}
-(AVCaptureSession*)session{
    if (_session == nil) {
        _session = [[AVCaptureSession alloc]init];
    }
    return _session;
}
-(AVCaptureVideoPreviewLayer *)previewLayer{
    if (_previewLayer == nil) {
        _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    }
    return _previewLayer;
}
// 设置输出对象解析数据时感兴趣的范围
// 默认值是 CGRect(x: 0, y: 0, width: 1, height: 1)
// 通过对这个值的观察, 我们发现传入的是比例
// 注意: 参照是以横屏的左上角作为, 而不是以竖屏
//        out.rectOfInterest = CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
-(AVCaptureMetadataOutput*)output{
    if (_output == nil) {
        _output = [[AVCaptureMetadataOutput alloc]init];
        //1. 获取屏幕frame
        CGRect viewRect = self.view.frame;
        //2. 获取容器frame
        CGRect containerRect = self.customContainerView.frame;
        
        CGFloat x = containerRect.origin.y / viewRect.size.height;
        CGFloat y = containerRect.origin.x / viewRect.size.width;
        CGFloat width = containerRect.size.height / viewRect.size.height;
        CGFloat height = containerRect.size.width / viewRect.size.width;
        
        _output.rectOfInterest = CGRectMake(x, y, width, height);
    }
    return _output;
}
- (CALayer *)containerLayer{
    if (_containerLayer == nil) {
        _containerLayer = [[CALayer alloc] init];
    }
    return _containerLayer;
}

/*-----------------------------分割线---------------------------------------*/
-(void)startScan{
    //1. 判断输入能否添加会话中
    if (![self.session canAddInput:self.input]) {
        [self.session addInput:self.input];
    }
    //2. 判断输出能否添加会话中
    if (![self.session canAddOutput:self.output]) {
        [self.session addOutput:self.output];
    }
    //3. 设置输出能够解析的数据类型
    // 注意点: 设置数据类型一定要在输出对象添加到会话之后才能设置
    self.output.metadataObjectTypes = self.output.availableMetadataObjectTypes;
    //4. 设置监听 监听输出解析到的数据
    [self.output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    //5. 添加预览图层
    [self.view.layer insertSublayer:self.previewLayer atIndex:0];
    self.previewLayer.frame = self.view.bounds;
    //6. 添加容器图层
    [self.view.layer addSublayer:self.containerLayer];
    //7. 开始扫描
    [self.session startRunning];
}
#pragma mark 两个动作
- (IBAction)closeButtonClick:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (IBAction)openCameraClick:(id)sender {
    //1. 判断相册是否可以打开
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        return;
    }
    //2. 创建图片选择控制器
    UIImagePickerController* ipc = [[UIImagePickerController alloc]init];
    ipc.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    //3. 设置代理
    ipc.delegate = self;
    //4. modal出这个控制器
    [self presentViewController:ipc animated:YES completion:nil];
}
#pragma mark ------UIImagePickerControllerDelegate-------
-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info{
    //1. 取出选中的图片
    UIImage* pickImage = info[UIImagePickerControllerOriginalImage];
    NSData* imageData = UIImagePNGRepresentation(pickImage);
    CIImage* ciImage = [CIImage imageWithData:imageData];
    //2. 从选中的图片中选取二维码数据
    //2.1 创建一个探测器
    CIDetector* detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil
                                              options:@{CIDetectorAccuracy:CIDetectorAccuracyLow}];
    //2.2 利用探测器探测数据
    NSArray* feature = [detector featuresInImage:ciImage];
    //2.3 取出探测到的数据
    for (CIQRCodeFeature *result in feature) {
        NSLog(@"%@",result.messageString);
        NSString *urlStr = result.messageString;
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlStr]];
    }
    //注意：如果实现了该方法，当选中一张图片是系统就不会自动关闭相册控制器
    [picker dismissViewControllerAnimated:YES completion:nil];
}
#pragma mark --------AVCaptureMetadataOutputObjectsDelegate ---------
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    
    //  if (metadataObjects.count > 0) {
    // id 类型不能点语法,所以要先去取出数组中对象
    AVMetadataMachineReadableCodeObject *object = [metadataObjects lastObject];
    
    if (object == nil) return;
    // 只要扫描到结果就会调用
    self.customLabel.text = object.stringValue;
    
    [self clearLayers];
    
    // [self.previewLayer removeFromSuperlayer];
    
    // 2.对扫描到的二维码进行描边
    AVMetadataMachineReadableCodeObject *obj = (AVMetadataMachineReadableCodeObject *)[self.previewLayer transformedMetadataObjectForMetadataObject:object];
    
    [self drawLine:obj];
    // 停止扫描
    //        [self.session stopRunning];
    //
    //        // 将预览图层移除
    //        [self.previewLayer removeFromSuperlayer];
    //    } else {
    //        NSLog(@"没有扫描到数据");
    //    }
    
}

// 绘制描边
- (void)drawLine:(AVMetadataMachineReadableCodeObject *)objc
{
    NSArray *array = objc.corners;
    
    // 1.创建形状图层, 用于保存绘制的矩形
    CAShapeLayer *layer = [[CAShapeLayer alloc] init];
    
    // 设置线宽
    layer.lineWidth = 2;
    layer.strokeColor = [UIColor greenColor].CGColor;
    layer.fillColor = [UIColor clearColor].CGColor;
    
    // 2.创建UIBezierPath, 绘制矩形
    UIBezierPath *path = [[UIBezierPath alloc] init];
    CGPoint point = CGPointZero;
    int index = 0;
    
    CFDictionaryRef dict = (__bridge CFDictionaryRef)(array[index++]);
    // 把点转换为不可变字典
    // 把字典转换为点，存在point里，成功返回true 其他false
    CGPointMakeWithDictionaryRepresentation(dict, &point);
    
    [path moveToPoint:point];
    
    // 2.2连接其它线段
    for (int i = 1; i<array.count; i++) {
        CGPointMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)array[i], &point);
        [path addLineToPoint:point];
    }
    // 2.3关闭路径
    [path closePath];
    
    layer.path = path.CGPath;
    // 3.将用于保存矩形的图层添加到界面上
    [self.containerLayer addSublayer:layer];
    
}
- (void)clearLayers
{
    if (self.containerLayer.sublayers)
    {
        for (CALayer *subLayer in self.containerLayer.sublayers)
        {
            [subLayer removeFromSuperlayer];
        }
    }
}
//界面消失时候关闭session
- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [self.session stopRunning];
}
//开启冲击波动画
-(void)startAnimation{
    //1. 设置冲击波底部和容器视图顶部对齐
    //刷新UI
    [self.view layoutIfNeeded];
    //2. 执行扫描动画
    [UIView animateWithDuration:1.0 animations:^{
        //无限重复动画
        [UIView setAnimationRepeatCount:MAXFLOAT];
        
        //刷新UI
        [self.view layoutIfNeeded];
    }];
    
}
@end