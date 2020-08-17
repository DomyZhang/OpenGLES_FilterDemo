//
//  ViewController.m
//  OpenGLES_Filters
//
//  Created by Domy on 2020/8/17.
//  Copyright © 2020 Domy. All rights reserved.
//

#import "ViewController.h"
#import <GLKit/GLKit.h>
#import "FilterBar.h"

typedef struct {
    GLKVector3 positionCoord;// (X, Y, Z)
    GLKVector3 textureCoord;// (U, V)
}SenceVertex;

@interface ViewController () <FilterBarDelegate>

// 上下文
@property (nonatomic, strong) EAGLContext *myContext;
// 顶点数据
@property (nonatomic, assign) SenceVertex *vertices;
// 着色器程序
@property (nonatomic, assign) GLuint program;
// 顶点缓存
@property (nonatomic, assign) GLuint vertexBuffer;
// 纹理 ID
@property (nonatomic, assign) GLuint textureID;

// 用于屏幕刷新
@property (nonatomic, strong) CADisplayLink *displayLink;
// 开始的时间戳
@property (nonatomic, assign) NSTimeInterval startTimeInterval;

@end

@implementation ViewController

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // 移除 displayLink
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor  =[UIColor whiteColor];
    
    // 创建滤镜筛选 bar
    [self createFilterBar];
    
    // 滤镜初始化
    [self initFilter];
    
    // 开始一个滤镜动画
    [self startFilerAnimation];
}

- (void)createFilterBar {
    
    CGFloat filterBarWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat filterBarHeight = 100;
    CGFloat filterBarY = [UIScreen mainScreen].bounds.size.height - filterBarHeight;
    FilterBar *filerBar = [[FilterBar alloc] initWithFrame:CGRectMake(0, filterBarY, filterBarWidth, filterBarHeight)];
    filerBar.delegate = self;
    [self.view addSubview:filerBar];
    
    NSArray *dataSource = @[@"无",@"缩放",@"灵魂出窍",@"抖动",@"闪白",@"毛刺",@"幻觉"];
    filerBar.itemList = dataSource;
}

#pragma mark - 绘制过程 -
- (void)initFilter {
    
    // 1.初始化  设置当前上下文
    self.myContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:self.myContext];
    
    // 2.开辟空间
    self.vertices = malloc(sizeof(SenceVertex) * 4);
    
    // 3、顶点数据
    self.vertices[0] = (SenceVertex){{-1, 1, 0}, {0, 1}};
    self.vertices[1] = (SenceVertex){{-1, -1, 0}, {0, 0}};
    self.vertices[2] = (SenceVertex){{1, 1, 0}, {1, 1}};
    self.vertices[3] = (SenceVertex){{1, -1, 0}, {1, 0}};
    
    // 4.图层 CAEAGLLayer
    CAEAGLLayer *layer = [[CAEAGLLayer alloc] init];
    layer.frame = CGRectMake(0, 100, self.view.frame.size.width, self.view.frame.size.width);
    // 设置图层的 scale
    layer.contentsScale = [UIScreen mainScreen].scale;
    // 添加到 view.layer
    [self.view.layer addSublayer:layer];
    
    // 5.绑定 缓冲区
    [self bindingBufferLayer:layer];
    
    // 6.加载纹理图片
    NSString *imagePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"cat.jpg"];
    // 读取图片
    UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
    // JPG 转 纹理
    GLuint textureID = [self createTextureWithImage:image];
    // 纹理ID
    self.textureID = textureID;
    
    // 7.设置视口
    glViewport(0, 0, self.drawableWidth, self.drawableHeight);
    
    // 8.设置顶点缓存区
    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    GLsizeiptr bufferSizeBytes = sizeof(SenceVertex) * 4;
    glBufferData(GL_ARRAY_BUFFER, bufferSizeBytes, self.vertices, GL_STATIC_DRAW);
    
    // 9.设置着色器
    [self setUpShaderPragramWithName:@"Normal"];
    
    // 10. 将顶点缓存保存，退出时释放
    self.vertexBuffer = vertexBuffer;
}

// 渲染缓冲区 bingding
- (void)bindingBufferLayer:(CALayer<EAGLDrawable> *)layer {
    
    GLuint renderBuffer;
    GLuint frameBuffer;
    
    // 生成+绑定 - 获取帧渲染缓存区名称,绑定渲染缓存区以及将渲染缓存区与layer建立连接
    glGenRenderbuffers(1, &renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
    [self.myContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
    
    glGenFramebuffers(1, &frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    // 将渲染缓存区附着到帧缓存区上
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderBuffer);
}

// JPG image 转 纹理
- (GLuint)createTextureWithImage:(UIImage *)image {
    
    ///  图片解压
    // 1、image 转 CGImageRef
    CGImageRef cgImageref = [image CGImage];
    if (!cgImageref) {
        NSLog(@"Failed to load Image");
        return 0;
    }
    // 2.读取图片大小
    GLuint width = (GLuint)CGImageGetWidth(cgImageref);
    GLuint height = (GLuint)CGImageGetHeight(cgImageref);
    CGRect rect = CGRectMake(0, 0, width, height);
    // 获取图片的颜色空间
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    // 3.获取图片字节数
    void *imageData = malloc(width * height * 4);
    // 4.创建上下文
    /*
    参数1：data,指向要渲染的绘制图像的内存地址
    参数2：width,bitmap的宽度，单位为像素
    参数3：height,bitmap的高度，单位为像素
    参数4：bitPerComponent,内存中像素的每个组件的位数，比如32位RGBA，就设置为8
    参数5：bytesPerRow,bitmap的每一行的内存所占的比特数
    参数6：colorSpace,bitmap上使用的颜色空间  kCGImageAlphaPremultipliedLast：RGBA
    */
    CGContextRef contextRef = CGBitmapContextCreate(imageData, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    // 图片翻转 --> 因为默认0点不同 图片是倒置的
    CGContextTranslateCTM(contextRef, 0, height);
    CGContextScaleCTM(contextRef, 1.0f, -1.0f);
    
    CGColorSpaceRelease(colorSpace);
    CGContextClearRect(contextRef, rect);
    
    // 重绘图片 得到解压后的一张新的位图
    CGContextDrawImage(contextRef, rect, cgImageref);
    
    /// 设置纹理
    // 1.纹理 ID
    GLuint textureID;
    glGenTextures(1, &textureID);
    glBindTexture(GL_TEXTURE_2D, textureID);
    // 2. 载入纹理
    /*
    参数1：纹理模式，GL_TEXTURE_1D、GL_TEXTURE_2D、GL_TEXTURE_3D
    参数2：加载的层次，一般设置为0
    参数3：纹理的颜色值GL_RGBA
    参数4：宽
    参数5：高
    参数6：border，边界宽度
    参数7：format
    参数8：type
    参数9：纹理数据
    */
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
    // 7.设置纹理属性
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    // 8. 绑定纹理
    /*
    参数1：纹理维度
    参数2：纹理ID,因为只有一个纹理，给0就可以了。
    */
    glBindTexture(GL_TEXTURE_2D, 0);
    
    
    // 释放 context imageData
    CGContextRelease(contextRef);
    free(imageData);
    
    return textureID;
}

// 初始化设置着色器
// 设置着色器程序
- (void)setUpShaderPragramWithName:(NSString *)name {
 
    // 1.获取 链接后的 着色器program
    GLuint program = [self programWithShaderName:name];
    
    // 2. use
    glUseProgram(program);
    
    // 3.获取 position texture textureCoordinator 的索引位置
    GLuint positionSlot = glGetAttribLocation(program, "Position");
    GLuint textureCoordinatorSlot = glGetAttribLocation(program, "TextureCoords");
    GLuint textureSlot = glGetUniformLocation(program, "Texture");
    
    // 4.激活纹理，绑定纹理ID
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.textureID);
    // 纹理 采样器 sample
    glUniform1i(textureSlot, 0);
    
    // 5.顶点坐标数据处理
    // 打开允许传递
    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, positionCoord));
    
    // 6.纹理坐标数据传递
    glEnableVertexAttribArray(textureCoordinatorSlot);
    glVertexAttribPointer(textureCoordinatorSlot, 2, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, textureCoord));
    
    // 7.保存 program
    self.program = program;
    
}
// 编译链接着色器程序 program
- (GLuint)programWithShaderName:(NSString *)shaderName {
    
    // 1.编译着色器 - 顶点/片元
    GLuint vertexShader = [self compileShaderWithName:shaderName type:GL_VERTEX_SHADER];
    GLuint texttureShader = [self compileShaderWithName:shaderName type:GL_FRAGMENT_SHADER];
    
    // 2.将着色器 附着到 program
    GLuint program = glCreateProgram();
    glAttachShader(program, vertexShader);
    glAttachShader(program, texttureShader);
    
    // 3.link
    glLinkProgram(program);
    // 是否 link 成功
    GLint linkSuccess;
    glGetProgramiv(program, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(program, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSAssert(NO, @"program 链接失败：%@", messageString);
        return 0;
    }

    // 得到 program
    return program;
}
// 编译 shader 代码
- (GLuint)compileShaderWithName:(NSString *)name type:(GLenum)shaderType {
    
    // 1.shader路径
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:shaderType==GL_VERTEX_SHADER ? @"vsh" : @"fsh"];
    NSError *error;
    NSString *shaderInfoString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (!shaderInfoString) {
        NSAssert(NO, @"读取 shader 失败");
        return 0;
    }
    // 2.创建 shader
    GLuint shader = glCreateShader(shaderType);
    // 3.获取shader source
    const char *shaderStringUTF8 = [shaderInfoString UTF8String];
    int shaderStrLength = (int)[shaderInfoString length];
    glShaderSource(shader, 1, &shaderStringUTF8, &shaderStrLength);
    // 4.编译 shader
    glCompileShader(shader);
    // 编译是否成功
    GLint compileSuccess;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shader, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSAssert(NO, @"shader 编译失败：%@", messageString);
        return 0;
    }
    
    // 得到 shader
    return shader;
}

// 开始一个滤镜动画
- (void)startFilerAnimation {
    
    // 1.判断 displayLink 是否为空
    // CADisplayLink 定时器
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
    // 2. 设置 displayLink 的方法
    self.startTimeInterval = 0;
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(timeAction)];
    
    // 3.将 displayLink 添加到 runloop 运行循环
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop]
                           forMode:NSRunLoopCommonModes];
}
//
- (void)timeAction {
    
    // displayLink 当前时间戳
    if (self.startTimeInterval == 0) {
        self.startTimeInterval = self.displayLink.timestamp;
    }
    
    // 使用program
    glUseProgram(self.program);
    glBindBuffer(GL_ARRAY_BUFFER, self.vertexBuffer);
    
    // 传入时间 到 着色器
    GLfloat currentTime = self.displayLink.timestamp - self.startTimeInterval;
    GLuint time = glGetUniformLocation(self.program, "Time");
    glUniform1f(time, currentTime);
    
    //
    glClear(GL_COLOR_BUFFER_BIT);
    glClearColor(1, 1, 1, 1);
    
    // 重绘
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    // 渲染到屏幕
    [self.myContext presentRenderbuffer:GL_RENDERER];
}

#pragma mark - FilterBar delegate -
- (void)filterBar:(FilterBar *)filterBar didScrollToIndex:(NSUInteger)index {
    
    if (index == 0) {
        [self setUpShaderPragramWithName:@"Normal"];
    }else if(index == 1) {
        [self setUpShaderPragramWithName:@"Scale"];
    }else if(index == 2) {
        [self setUpShaderPragramWithName:@"SoulOut"];
    }else if(index == 3) {
        [self setUpShaderPragramWithName:@"Shake"];
    }else if(index == 4) {
        [self setUpShaderPragramWithName:@"ShineWhite"];
    }else if(index == 5) {
        [self setUpShaderPragramWithName:@"Glitch"];
    }else {
        [self setUpShaderPragramWithName:@"Vertigo"];
    }
    
    // 重新开始滤镜动画
    [self startFilerAnimation];
}

// 获取渲染缓存区的宽
- (GLint)drawableWidth {
    
    GLint backingWidth;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    return backingWidth;
}
// 获取渲染缓存区的高
- (GLint)drawableHeight {
    
    GLint backingHeight;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    return backingHeight;
}

- (void)dealloc {
    
    // 上下文释放
    if ([EAGLContext currentContext] == self.myContext) {
        [EAGLContext setCurrentContext:nil];
    }
    
    // 顶点缓存区释放
    if (_vertexBuffer) {
        glDeleteBuffers(1, &_vertexBuffer);
        _vertexBuffer = 0;
    }
    
    // 顶点数组释放
    if (_vertices) {
        free(_vertices);
        _vertices = nil;
    }
}

@end
