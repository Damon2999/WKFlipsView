//
//  WKFlipsLayer.m
//  WKFlipsView
//
//  Created by 秦 道平 on 13-12-13.
//  Copyright (c) 2013年 秦 道平. All rights reserved.
//

#import "WKFlipsLayer.h"
#import "WKFlipsView.h"
#import "WKFlip.h"
#pragma makr - WKFlipsLayerView
///重建页面时的贴图时间
#define WKFlipsLayerView_PasteImageDuration_When_Rebuild 1.0f
///翻页结束时的贴图时间
#define WKFlipsLayerView_PasteImageDuration_After_Flipped 1.0f
///在主线程中延时贴图的时间
#define WKFlipsLayerView_PasteImage_Delay 0.01f
@interface WKFlipsLayerView(){
    
}

@end
@implementation WKFlipsLayerView
@dynamic runState;
@dynamic numbersOfLayers;
-(id)initWithFrame:(CGRect)frame{
    self=[super initWithFrame:frame];
    if (self){
        self.userInteractionEnabled=NO;
        self.opaque=YES;
    }
    return self;
}
-(id)initWithFlipsView:(WKFlipsView *)flipsView{
    self=[super initWithFrame:flipsView.bounds];
    if (self){
        self.userInteractionEnabled=NO;
        self.flipsView=flipsView;
        self.opaque=YES;
        _pasterService=[[_WKFlipsPasterService alloc]initWithFlipsLayerView:self];
        //[self buildLayers];
    }
    return self;
}
-(void)dealloc{
    [_pasterService release];
    [super dealloc];
}
-(void)setRunState:(WKFlipsLayerViewRunState)runState{
    _runState=runState;
    switch (runState) {
        case WKFlipsLayerViewRunStateAnimation:
            self.hidden=NO;
            self.flipsView.currentPageView.hidden=YES;
            self.flipsView._operateAvailable=NO;
            [self.flipsView hidePageIndex];
            break;
        case WKFlipsLayerViewRunStateDragging:
            self.hidden=NO;
            self.flipsView.currentPageView.hidden=YES;
            self.flipsView._operateAvailable=NO;
            [self.flipsView hidePageIndex];
            break;
        case WKFlipsLayerViewRunStateStop:
            [self _removeShadowOnDraggngLayer];
            self.hidden=YES;
            self.flipsView.currentPageView.hidden=NO;
            self.flipsView._operateAvailable=YES;
            [self.flipsView showPageIndex];
            break;
        default:
            break;
    }
}
-(WKFlipsLayerViewRunState)runState{
    return _runState;
}
#pragma mark - build
-(int)numbersOfLayers{
    //return [self.flipsView.dataSource numberOfPagesForFlipsView:self.flipsView]*2;
    return (int)[self.flipsView.dataSource numberOfPagesForFlipsView:self.flipsView]+1;
}
-(int)totalPages{
    int totalPages=(int)[self.flipsView.dataSource numberOfPagesForFlipsView:self.flipsView];
    return totalPages;
}
-(void)buildLayers{
//    double startTime=CFAbsoluteTimeGetCurrent();
    ///先删除现有的layer
    NSMutableArray* layerArray=[[self.layer.sublayers mutableCopy] autorelease];
    for (CALayer *layer in layerArray) {
        [layer removeFromSuperlayer];
    }
    
    ///layer的总数
    int layersNumber=[self numbersOfLayers];
//    int layersNumber=1;
    ///在重新创建新的layer,一开始的位置都在屏幕下半部分
    CGRect layerFrame=CGRectMake(0.0f, self.bounds.size.height/2, self.bounds.size.width, self.bounds.size.height/2);
    for (int a=0; a<layersNumber; a++) {
        WKFlipsLayer* layer=[[[WKFlipsLayer alloc]initWithFrame:layerFrame] autorelease];
        [self.layer insertSublayer:layer atIndex:0];
//        [self.layer addSublayer:layer];
//        layer.frontLayer.contents=(id)[UIImage imageNamed:@"weather-default-bg"].CGImage;
//        layer.backLayer.contents=(id)[UIImage imageNamed:@"weather-default-bg"].CGImage;
        #ifdef DEBUG
        ///在页面上输出图层编号和页面编号,绘制文字会消耗不少时间
//        [layer drawWords:[NSString stringWithFormat:@"layer:%d-front,page:%d",(layersNumber-a-1),a-1] onPosition:0];
//        [layer drawWords:[NSString stringWithFormat:@"layer:%d-back,page:%d",(layersNumber-a-1),a] onPosition:1];
        #endif
        layer.rotateDegree=0.0f;
    }

    //为当前的页面进行贴图
    [self.pasterService pasterWorkAtPageIndex:self.flipsView.pageIndex];
    ///直接已经翻页到现在的页面
    [self flipToPageIndex:self.flipsView.pageIndex];

}
#pragma mark - flips
///无动画的翻页
-(void)flipToPageIndex:(int)pageIndex{
//    if (pageIndex && pageIndex==self.flipsView.pageIndex)
//        return;
    pageIndex=MIN(pageIndex, (int)[self.flipsView.dataSource numberOfPagesForFlipsView:self.flipsView]-1);
    pageIndex=MAX(pageIndex, 0);
    int layersNumber=[self numbersOfLayers];
    ///往前翻页，也就是把上半部分的页面往下面翻
    if (pageIndex<self.flipsView.pageIndex){
        for (int layerIndex=0; layerIndex<layersNumber; layerIndex++) {
            CGFloat rotateDegree=[self _calculateRotateDegreeForLayerIndex:layerIndex toTargetPageIndex:pageIndex];
            WKFlipsLayer *flipLayer=self.layer.sublayers[layerIndex];
            flipLayer.hidden=NO;
            flipLayer.rotateDegree=rotateDegree;
        }
    }
    ///往后面翻页,也就是把下半部分的往上面翻
    else{
        for (int layerIndex=layersNumber-1; layerIndex>=0; layerIndex--) {
            CGFloat rotateDegree=[self _calculateRotateDegreeForLayerIndex:layerIndex toTargetPageIndex:pageIndex];
            WKFlipsLayer* flipLayer=self.layer.sublayers[layerIndex];
            flipLayer.hidden=NO;
            flipLayer.rotateDegree=rotateDegree;
        }
    }
    self.flipsView.pageIndex=pageIndex;
    if ([self.flipsView.delegate respondsToSelector:@selector(flipsView:didFlippedToPageIndex:)]){
        [self.flipsView.delegate flipsView:self.flipsView didFlippedToPageIndex:self.flipsView.pageIndex];
    }
    [self.pasterService startWithPriorPageIndex:self.flipsView.pageIndex inSecnods:WKFlipsLayerView_PasteImageDuration_When_Rebuild];
    self.runState=WKFlipsLayerViewRunStateStop;
}
-(void)flipToPageIndex:(int)pageIndex completion:(void (^)(BOOL completed))completionBlock{
    if(self.runState!=WKFlipsLayerViewRunStateStop)
        return;
    pageIndex=MIN(pageIndex, (int)[self.flipsView.dataSource numberOfPagesForFlipsView:self.flipsView]-1);
    pageIndex=MAX(pageIndex, 0);
    if (pageIndex && pageIndex==self.flipsView.pageIndex)
        return;
    [self.pasterService stop];///动画开始时结束贴图
    self.runState=WKFlipsLayerViewRunStateAnimation;
    CGFloat durationFull=1.0f;
    CGFloat delayFromDuration=0.05f;
    ///往前翻页，也就是把上半部分往下面翻页
    CGFloat delay=0.0f;
    int layersNumber=[self numbersOfLayers];
    __block int complete_hits=0;
    if (pageIndex<self.flipsView.pageIndex){
        for (int layerIndex=0; layerIndex<layersNumber; layerIndex++) {
            CGFloat rotateDegree=[self _calculateRotateDegreeForLayerIndex:layerIndex toTargetPageIndex:pageIndex];
            //NSLog(@"layerIndex:%d,%f",layerIndex,rotateDegree);
            WKFlipsLayer *flipLayer=self.layer.sublayers[layerIndex];
            flipLayer.hidden=NO;
            CGFloat rotateDistance=fabsf(rotateDegree-flipLayer.rotateDegree);
            CGFloat duration=rotateDistance/180.0f*durationFull;
            delay+=duration*delayFromDuration;
            [flipLayer setRotateDegree:rotateDegree duration:duration afterDelay:delay completion:^{
                if (++complete_hits>=layersNumber){
                        //NSLog(@"flip completed");
                        self.flipsView.pageIndex=pageIndex;
                        if ([self.flipsView.delegate respondsToSelector:@selector(flipsView:didFlippedToPageIndex:)]){
                            [self.flipsView.delegate flipsView:self.flipsView didFlippedToPageIndex:self.flipsView.pageIndex];
                        }
                    [self.pasterService startWithPriorPageIndex:pageIndex inSecnods:WKFlipsLayerView_PasteImageDuration_After_Flipped];
                        completionBlock(YES);
                        self.runState=WKFlipsLayerViewRunStateStop;
                    }
            }];
            
        }
    }
    else{
        for (int layerIndex=layersNumber-1; layerIndex>=0; layerIndex--) {
            CGFloat rotateDegree=[self _calculateRotateDegreeForLayerIndex:layerIndex toTargetPageIndex:pageIndex];
            //NSLog(@"layerIndex:%d,%f",layerIndex,rotateDegree);
            WKFlipsLayer* flipLayer=self.layer.sublayers[layerIndex];
            flipLayer.hidden=NO;
            CGFloat rotateDistance=fabsf(rotateDegree-flipLayer.rotateDegree);
            CGFloat duration=rotateDistance/180.0f*durationFull;
            delay+=duration*delayFromDuration;
            [flipLayer setRotateDegree:rotateDegree duration:duration afterDelay:delay completion:^{
                if (++complete_hits>=layersNumber){
                        //NSLog(@"flip completed");
                        self.flipsView.pageIndex=pageIndex;
                        if ([self.flipsView.delegate respondsToSelector:@selector(flipsView:didFlippedToPageIndex:)]){
                            [self.flipsView.delegate flipsView:self.flipsView didFlippedToPageIndex:self.flipsView.pageIndex];
                        }
                    [self.pasterService startWithPriorPageIndex:pageIndex inSecnods:WKFlipsLayerView_PasteImageDuration_After_Flipped];
                        completionBlock(YES);
                        self.runState=WKFlipsLayerViewRunStateStop;
                    
                    }
            }];
        }
    }
}
///当翻页到一个pageIndex,为每个layer计算角度
-(CGFloat)_calculateRotateDegreeForLayerIndex:(int)layerIndex toTargetPageIndex:(int)pageIndex{
    int layersNumber=[self numbersOfLayers];
    int stopLayerIndexAtTop=layersNumber-1-pageIndex;
    int stopLayerIndexAtBottom=stopLayerIndexAtTop-1;
    CGFloat spaceRotate=0.1f;
//    CGFloat spaceRotate=0.01f;
    if (layerIndex>=stopLayerIndexAtTop){
        return 180.0f+(layerIndex-stopLayerIndexAtTop)*spaceRotate;
    }
    else if (layerIndex<=stopLayerIndexAtBottom){
        return 0.0f-(stopLayerIndexAtBottom-layerIndex)*spaceRotate;
    }
    else{
        return 0.0f;
    }

}
#pragma mark - Drag
-(void)dragBeganWithTranslation:(CGPoint)translation{
//    NSLog(@"dragBegan");
//    if (self.runState!=WKFlipsLayerViewRunStateStop)
//        return;
    if (self.runState==WKFlipsLayerViewRunStateAnimation) ///如果正在连续动画就不拖动
        return;
    [self.pasterService stop];///拖动时停止贴图
    _drag_start_time=[[NSDate date] timeIntervalSince1970];
    _dragging_last_translation_y=translation.y;
    [_dragging_layer cancelDragAnimation];///如果有_dragging_layer的话，取消拖动的动画
    self.runState=WKFlipsLayerViewRunStateDragging;
}
-(void)dragEndedWithTranslation:(CGPoint)translation{
//    NSLog(@"dragEnded");
    if (self.runState!=WKFlipsLayerViewRunStateDragging)
        return;
    ///拖动手势可能直接从began 到 end，如果拖动速度很快的话，这时没有拖动的页面，应该立刻结束拖动状态
    if (_dragging_layer==nil){
        NSLog(@"end drag with empty layer");
//        if ([self.flipsView.delegate respondsToSelector:@selector(flipsView:didFlippedToPageIndex:)]){
//            [self.flipsView.delegate flipsView:self.flipsView didFlippedToPageIndex:self.flipsView.pageIndex];
//        }
        self.runState=WKFlipsLayerViewRunStateStop;
        return;
    }
    CGFloat durationFull=1.0f;
//    CGFloat durationFull=10.0f;
    double drag_duration=fabsl([[NSDate date] timeIntervalSince1970]-_drag_start_time);
    //NSLog(@"drag_duration:%f,rotate:%f",drag_duration,_dragging_layer.rotateDegree);
    BOOL quick_drag_flip=(drag_duration<0.15f); ///是否翻页足够快
//    NSLog(@"drag_duration:%f,quick_drag_flip:%d,rotate:%f",drag_duration,quick_drag_flip,_dragging_layer.rotateDegree);
    if (_dragging_position==WKFlipsLayerDragAtPositionTop){
        ///返回现在的页面,超过90度或者快速的操作30度
        ///不是最后一页，要么翻页超过90度，要么快速翻页超过20度
        if (_dragging_layer!=self.layer.sublayers.lastObject &&
            (_dragging_layer.rotateDegree<=90.0f ||(_dragging_layer.rotateDegree<=(180-30.0f) && quick_drag_flip))){
                [self _removeShadowOnDraggngLayer];
                int previousPageIndex=self.flipsView.pageIndex-1;
                int layersNumber=[self numbersOfLayers];
//                [CATransaction setValue:[NSNumber numberWithBool:YES] forKey:kCATransactionDisableActions];
                for (int layerIndex=0; layerIndex<layersNumber; layerIndex++) {
                    CGFloat rotateDegree=[self _calculateRotateDegreeForLayerIndex:layerIndex toTargetPageIndex:previousPageIndex];
                    WKFlipsLayer* flipLayer=self.layer.sublayers[layerIndex];
                    if (flipLayer!=_dragging_layer){
                        [flipLayer setRotateDegree:rotateDegree];
                    }
                    else{
//                        NSLog(@"skip dragging layerIndex:%d",layerIndex);
                    }
//                    NSLog(@"layerIndex:%d,rotateDegree:%f/%f",layerIndex,flipLayer.rotateDegree,[[flipLayer presentationLayer] rotateDegree]);
                }
                int layerIndex=(int)[self.layer.sublayers indexOfObject:_dragging_layer];
                CGFloat newRotateDegree=[self _calculateRotateDegreeForLayerIndex:layerIndex toTargetPageIndex:previousPageIndex];
                CGFloat duration=fabsf(newRotateDegree-_dragging_layer.rotateDegree)/180.0f*durationFull;
//            CGFloat duration=10.0f;
                ///快速时因为角度很小，所以要缩短时间
                if (quick_drag_flip){
                    duration=0.3f;
                }
                [_dragging_layer setRotateDegree:newRotateDegree duration:duration afterDelay:0.0f completion:^{
                    _dragging_layer=nil;
                    self.flipsView.pageIndex=previousPageIndex;
                    if ([self.flipsView.delegate respondsToSelector:@selector(flipsView:didFlippedToPageIndex:)]){
                        [self.flipsView.delegate flipsView:self.flipsView didFlippedToPageIndex:self.flipsView.pageIndex];
                    }
                    [self.pasterService startWithPriorPageIndex:previousPageIndex inSecnods:WKFlipsLayerView_PasteImageDuration_After_Flipped];
                    self.runState=WKFlipsLayerViewRunStateStop;
                }];
        }
        ///否则返回到前面的页面
        else{
            int layerIndex=(int)[self.layer.sublayers indexOfObject:_dragging_layer];
            CGFloat oldRotateDegree=[self _calculateRotateDegreeForLayerIndex:layerIndex toTargetPageIndex:self.flipsView.pageIndex];
            CGFloat duration=fabsf(oldRotateDegree-_dragging_layer.rotateDegree)/180.0f*durationFull;
            [_dragging_layer setRotateDegree:oldRotateDegree duration:duration afterDelay:0.0f completion:^{
                _dragging_layer=nil;
                self.runState=WKFlipsLayerViewRunStateStop;
            }];
        }
    }
    else{
        ///到后一页
        ///不是第一页，翻页超过90度，或者快速翻页超过30页
        if (_dragging_layer!=self.layer.sublayers.firstObject &&
                (_dragging_layer.rotateDegree>=90.0f || (_dragging_layer.rotateDegree>=30.0f && quick_drag_flip))){
//            [_dragging_layer removeShadow];
            [self _removeShadowOnDraggngLayer];
            int nextPageIndex=self.flipsView.pageIndex+1;
            int layersNumber=[self numbersOfLayers];
//            [CATransaction setValue:[NSNumber numberWithBool:YES] forKey:kCATransactionDisableActions];
            for (int layerIndex=layersNumber-1; layerIndex>=0; layerIndex--) {
                CGFloat rotateDegree=[self _calculateRotateDegreeForLayerIndex:layerIndex toTargetPageIndex:nextPageIndex];
                WKFlipsLayer* flipLayer=self.layer.sublayers[layerIndex];
                if (flipLayer!=_dragging_layer)
                    [flipLayer setRotateDegree:rotateDegree];
                else{
//                    NSLog(@"skip dragging layerIndex:%d",layerIndex);
                }
//                NSLog(@"layerIndex:%d,rotateDegree:%f/%f",layerIndex,flipLayer.rotateDegree,[[flipLayer presentationLayer] rotateDegree]);
            }
            int layerIndex=(int)[self.layer.sublayers indexOfObject:_dragging_layer];
            CGFloat newRotateDegree=[self _calculateRotateDegreeForLayerIndex:layerIndex toTargetPageIndex:nextPageIndex];
            CGFloat duration=fabsf(newRotateDegree-_dragging_layer.rotateDegree)/180.0f*durationFull;
//            CGFloat duration=10.0f;
            ///快速翻页时因为角度很小，要缩小时间
            if (quick_drag_flip){
                duration=0.3f;
            }
            [_dragging_layer setRotateDegree:newRotateDegree duration:duration afterDelay:0.0f completion:^{
                _dragging_layer=nil;
                self.flipsView.pageIndex=nextPageIndex;
                if ([self.flipsView.delegate respondsToSelector:@selector(flipsView:didFlippedToPageIndex:)]){
                    [self.flipsView.delegate flipsView:self.flipsView didFlippedToPageIndex:self.flipsView.pageIndex];
                }
                [self.pasterService startWithPriorPageIndex:nextPageIndex inSecnods:WKFlipsLayerView_PasteImageDuration_After_Flipped];
                self.runState=WKFlipsLayerViewRunStateStop;
                
            }];
        }
        else{///返回到现在的页面
            int layerIndex=(int)[self.layer.sublayers indexOfObject:_dragging_layer];
            CGFloat oldRotateDegree=[self _calculateRotateDegreeForLayerIndex:layerIndex toTargetPageIndex:self.flipsView.pageIndex];
            CGFloat duration=fabsf(oldRotateDegree-_dragging_layer.rotateDegree)/180.0f*durationFull;
            [_dragging_layer setRotateDegree:oldRotateDegree duration:duration afterDelay:0.0f completion:^{
                _dragging_layer=nil;
                self.runState=WKFlipsLayerViewRunStateStop;
            }];
        }
        
    }
}
-(void)draggingWithTranslation:(CGPoint)translation{
    //NSLog(@"dragging:%f",translation.y);
    if (self.runState!=WKFlipsLayerViewRunStateDragging)
        return;
    ///一开始的时候要知道是在拖动那一页
    if (!_dragging_layer){
//        NSLog(@"get dragging layer");
        int layersNumber=[self numbersOfLayers];
        int stopLayerIndexAtTop=layersNumber-1-self.flipsView.pageIndex;
        int stopLayerIndexAtBottom=stopLayerIndexAtTop-1;
        if (translation.y>0){
            _dragging_layer=self.layer.sublayers[stopLayerIndexAtTop];
            _dragging_position=WKFlipsLayerDragAtPositionTop;
//            NSLog(@"dragging Top layerIndex:%d",stopLayerIndexAtTop);
        }
        else{
            _dragging_layer=self.layer.sublayers[stopLayerIndexAtBottom];
            _dragging_position=WKFlipsLayerDragAtPositionBottom;
//            NSLog(@"dragging Bottom layerIndex:%d",stopLayerIndexAtBottom);
        }
        ///为图层设置隐藏关系，多图层会引起动画很卡，只要当前翻页的几张能显示就可以了，其他图层隐藏
        for (long layerIndex=self.layer.sublayers.count-1; layerIndex>=0; layerIndex--) {
//            WKFlipsLayer* layer=self.layer.sublayers[layerIndex];
//            NSLog(@"%ld,%f",layerIndex,layer.rotateDegree);
            WKFlipsLayer* layer=self.layer.sublayers[layerIndex];
            if (abs(stopLayerIndexAtBottom-(int)layerIndex)>2 || abs(stopLayerIndexAtTop-(int)layerIndex)>2){
                layer.hidden=YES;
            }
            else{
                layer.hidden=NO;
            }
        }
//        ///恢复开是时候的位置
//        _dragging_last_translation_y=translation.y;
    }
    else{
//        NSLog(@"existed dragging layer");
    }
    ///往下面翻
    if (_dragging_position==WKFlipsLayerDragAtPositionTop){
        CGFloat rotateDegree=_dragging_layer.rotateDegree-(translation.y-_dragging_last_translation_y)*0.5;
        rotateDegree=fminf(rotateDegree, 179.0f);
        ///最后一页翻不到下面
        if (_dragging_layer==self.layer.sublayers.lastObject){
            rotateDegree=fmaxf(rotateDegree, 91.0f);
        }
        else{
            rotateDegree=fmaxf(rotateDegree, 1.0f);
        }
        _dragging_layer.rotateDegree=rotateDegree;
    }
    else{ ///往上面翻
        CGFloat rotateDegree=_dragging_layer.rotateDegree-(translation.y-_dragging_last_translation_y)*0.5f;
        ///第一页翻不到上面
        if (_dragging_layer==self.layer.sublayers.firstObject){
            rotateDegree=fminf(rotateDegree, 89.0f);
        }
        else{
            rotateDegree=fminf(rotateDegree, 179.0f);
        }
        rotateDegree=fmaxf(rotateDegree, 1.0f);
        _dragging_layer.rotateDegree=rotateDegree;
    }
    _dragging_last_translation_y=translation.y;
    ///shadow
    [self _showShadowOnDraggingLayer];
    
}
#pragma mark Shadow
///根据现在的页面拖动的角度计算另外两层页面的阴影
-(void)_showShadowOnDraggingLayer{
    ///当前正在拖动的这层有一个固定明度的阴影
    //[_dragging_layer showShadowOpacity:_dragging_layer.rotateDegree/180.0f*0.3 onLayer:0];
    [_dragging_layer showShadowOpacity:0.06];
    NSUInteger layerIndex=[self.layer.sublayers indexOfObject:_dragging_layer];
    WKFlipsLayer* shadowLayer_bottom=nil;
    if (layerIndex>0){
        NSUInteger shadowLayerIndex_bottom=layerIndex-1;
        shadowLayer_bottom=self.layer.sublayers[shadowLayerIndex_bottom];
    }
    WKFlipsLayer* shadowLayer_top=nil;
    if (layerIndex<self.layer.sublayers.count-1){
        NSUInteger shadowLayerIndex_top=layerIndex+1;
        shadowLayer_top=self.layer.sublayers[shadowLayerIndex_top];
    }
    if (_dragging_layer.rotateDegree<90.0f){
        [shadowLayer_bottom showShadowOpacity:(1.0f-_dragging_layer.rotateDegree/90.0f) onLayer:0];
        [shadowLayer_top removeShadow];
    }
    else{
        [shadowLayer_top showShadowOpacity:(1.0f-(180.0f-_dragging_layer.rotateDegree)/90.0f) onLayer:1];
        [shadowLayer_bottom removeShadow];
    }
    
}
///去掉图层阴影，从所有图层上处理
-(void)_removeShadowOnDraggngLayer{
    //double startTime=CFAbsoluteTimeGetCurrent();
    ///不循环所有层，只处理当前的几层
    [_dragging_layer removeShadow];
    NSUInteger layerIndex=[self.layer.sublayers indexOfObject:_dragging_layer];
    WKFlipsLayer* shadowLayer_bottom=nil;
    if (layerIndex>0 && layerIndex<self.layer.sublayers.count-1){
        NSUInteger shadowLayerIndex_bottom=layerIndex-1;
        shadowLayer_bottom=self.layer.sublayers[shadowLayerIndex_bottom];
    }
    WKFlipsLayer* shadowLayer_top=nil;
    if (layerIndex<self.layer.sublayers.count-1){
        NSUInteger shadowLayerIndex_top=layerIndex+1;
        shadowLayer_top=self.layer.sublayers[shadowLayerIndex_top];
    }
    [shadowLayer_bottom removeShadow];
    [shadowLayer_top removeShadow];
    //NSLog(@"removeShaodw duration:%f",CFAbsoluteTimeGetCurrent()-startTime);
}
#pragma mark - Cache
-(void)preparePageCache{
    int totalPages=(int)[self.flipsView.dataSource numberOfPagesForFlipsView:self.flipsView];
    ///检查缓存索引键是否完全
    for (int a=0; a<totalPages; a++) {
        if (![self.flipsView.cache pageCacheAtPageIndex:a]){
            [self.flipsView.cache addPage];
        }
    }
}
@end

#pragma mark - WKFlipsLayer
#define WKFLIPSLAYER_FLIP_ANIMATION @"flip-animation"
@interface WKFlipsLayer(){
    
}
///动画是否被取消
@property (nonatomic,assign) BOOL isAnimationCancelled;
@end
@implementation WKFlipsLayer
@dynamic rotateDegree;
+(NSArray*)sharedBackgroundImagesWithRect:(CGRect)rect{
    static NSArray *images=nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIImage *backgroundImage=WKFlip_line_radial_image(rect);
        images=[WKFlip_make_hsplit_images_for_image(backgroundImage) retain];
        NSLog(@"shared background image");
    });
    return images;
}
-(id)initWithFrame:(CGRect)frame{
    self=[super init];
    if (self){
        self.frame=frame;
        self.doubleSided=YES;
        self.anchorPoint=CGPointMake(0.5, 0.0f);
        self.position=CGPointMake(self.position.x,
                                  self.position.y-self.frame.size.height/2);
        
        CGRect rect=CGRectMake(0.0f, 0.0f, frame.size.width, frame.size.height*2);
        UIImage *image_1=[WKFlipsLayer sharedBackgroundImagesWithRect:rect][0];
        UIImage *image_2=[WKFlipsLayer sharedBackgroundImagesWithRect:rect][1];
        
        _frontLayer=[[CALayer alloc]init];
        _frontLayer.frame=self.bounds;
        _frontLayer.backgroundColor=[UIColor whiteColor].CGColor;
        _frontLayer.doubleSided=NO;
        _frontLayer.name=@"frontLayer";
        _frontLayer.opaque=YES;
        _frontLayer.contents=(id)image_2.CGImage;
        
        _backLayer=[[CALayer alloc]init];
        _backLayer.frame=self.bounds;
        _backLayer.backgroundColor=[UIColor whiteColor].CGColor;
        _backLayer.doubleSided=YES;
        _backLayer.name=@"backLayer";
        _backLayer.contents=(id)image_1.CGImage;
        _backLayer.transform=WKFlipCATransform3DPerspectSimpleWithRotate(180.0f);
        _backLayer.opaque=YES;
   
        [self addSublayer:_backLayer];
        [self addSublayer:_frontLayer];
        self.frontLayerContent=NO;
        self.backLayerContent=NO;
    }
    return self;
}
-(void)dealloc{
    [_shadowOnFronLayer release];
    [_shadowOnBackLayer release];
    [_frontLayer release];
    [_backLayer release];
    [super dealloc];
}
#pragma mark - Test
-(void)drawWords:(NSString *)words onPosition:(int)position{
    UIGraphicsBeginImageContext(self.frame.size);
    CGContextRef context=UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    // Flip the coordinate system
    CGContextSetTextMatrix(context, CGAffineTransformIdentity); // 2-1
    CGContextTranslateCTM(context, 0, self.frame.size.height); // 3-1
    CGContextScaleCTM(context, 1.0, -1.0); // 4-1
    ///Text
    NSMutableAttributedString* attributeString=[[[NSMutableAttributedString alloc]initWithString:words] autorelease];
    CTFontRef fontRefBold = CTFontCreateWithName((CFStringRef)@"Helvetica-Bold", 20.0f, NULL); // 3-3  字体
    NSDictionary *attrDictionaryBold = [NSDictionary dictionaryWithObjectsAndKeys:(id)fontRefBold, (NSString *)kCTFontAttributeName, (id)[[UIColor blackColor] CGColor], (NSString *)(kCTForegroundColorAttributeName), nil]; // 4-3，另一个格式，用来设置部分文字的样式
    [attributeString addAttributes:attrDictionaryBold range:NSMakeRange(0,attributeString.length)]; // 5-3 一段范围内的文字格式，添加这个样式（只对应指定长度内）
    CFRelease(fontRefBold); // 6-3
    CGMutablePathRef path = CGPathCreateMutable(); // 5-2
    CGPathAddRect(path, NULL, CGRectMake(0.0f, 0.0f, self.frame.size.width, self.frame.size.height)); // 6-2 绘制的区域
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attributeString); // 7-2，设置text frame的样式和内容
    CTFrameRef theFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, [attributeString length]), path, NULL); // 8-2 创建text frame
    CFRelease(framesetter); // 9-2
    CFRelease(path); // 10-2
    CTFrameDraw(theFrame, context); // 11-2 绘制这个区域
    CFRelease(theFrame); // 12-2
    UIImage* imageOutput=UIGraphicsGetImageFromCurrentImageContext();
    CGContextRestoreGState(context);
    UIGraphicsEndImageContext();
    CALayer *wordsLayer=[[[CALayer alloc]init] autorelease];
    wordsLayer.frame=self.bounds;
    wordsLayer.contents=(id)imageOutput.CGImage;
    if (position==0){
        [self.frontLayer addSublayer:wordsLayer];
    }
    else{
        [self.backLayer addSublayer:wordsLayer];
    }
}
#pragma mark - Animation
-(id<CAAction>)actionForKey:(NSString *)event{
//    return [super actionForKey:event];
//    id<CAAction> animation=[super actionForKey:event];
//    NSLog(@"%@:\n%@",event,animation);
//    return animation;
    if ([event isEqualToString:@"rotateDegree"]){
        CABasicAnimation *animation=[CABasicAnimation animationWithKeyPath:event];
        animation.fromValue=@([[self presentationLayer] rotateDegree]);
        animation.toValue=@(self.rotateDegree);
//        NSLog(@"rotateDegree duration:%f",animation.duration);
        return animation;
    }
    return [super actionForKey:event];
}
+(BOOL)needsDisplayForKey:(NSString *)key{
//    NSLog(@"needsDisplayForKey:%@",key);
    if ([key isEqualToString:@"rotateDegree"]){
        return YES;
    }
    BOOL result=[super needsDisplayForKey:key];
//    NSLog(@"needsDisplayForKey:%@,%d",key,result);
    return result;
}
-(void)display{
//    NSLog(@"display:%f",[self.presentationLayer rotateDegree]);
    [CATransaction setValue:[NSNumber numberWithBool:YES] forKey:kCATransactionDisableActions];
    self.transform=WKFlipCATransform3DPerspectSimpleWithRotate([self.presentationLayer rotateDegree]);
//    [super display];
}
#pragma mark - Cancel Drag
-(void)cancelDragAnimation{
    if ([self animationForKey:WKFLIPSLAYER_FLIP_ANIMATION]){
        self.rotateDegree=[[self presentationLayer] rotateDegree];
        self.isAnimationCancelled=YES;
        [self removeAnimationForKey:WKFLIPSLAYER_FLIP_ANIMATION];
        NSLog(@"cancel");
    }
}
#pragma mark - rotateDegree
#pragma mark rotateDegree animation
-(void)setRotateDegree:(CGFloat)rotateDegree duration:(CGFloat)duration afterDelay:(NSTimeInterval)delay completion:(void (^)())completion{
    if ([self animationForKey:WKFLIPSLAYER_FLIP_ANIMATION]){
        NSLog(@"animation not finished");
        return;
    }
    [CATransaction begin];
    CABasicAnimation* flipAnimation=[CABasicAnimation animationWithKeyPath:@"rotateDegree"];
    [CATransaction setValue:[NSNumber numberWithBool:YES] forKey:kCATransactionDisableActions];
    flipAnimation.delegate=self;
    flipAnimation.duration=duration;
    flipAnimation.fillMode=kCAFillModeBoth;
    flipAnimation.beginTime=[self convertTime:CACurrentMediaTime() fromLayer:nil]+delay;
    flipAnimation.toValue=[NSNumber numberWithFloat:rotateDegree];
    flipAnimation.fromValue=@(self.rotateDegree);
//    flipAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    [CATransaction setCompletionBlock:^{
        if (self.isAnimationCancelled){
            self.isAnimationCancelled=NO;
        }
        else{
            self.isAnimationCancelled=NO;
            completion();
        }
    }];
    [self addAnimation:flipAnimation forKey:WKFLIPSLAYER_FLIP_ANIMATION];
    self.rotateDegree=rotateDegree;
    [CATransaction commit];
    

}
#pragma mark shadow
///显示图层阴影，设置opacity是比较费时的操作
-(void)showShadowOpacity:(CGFloat)opacity{
    if (!_shadowOnFronLayer && !_shadowOnBackLayer){
        _shadowOnFronLayer=[[CALayer alloc]init];
        _shadowOnFronLayer.frame=self.bounds;
        _shadowOnBackLayer=[[CALayer alloc]init];
        _shadowOnBackLayer.frame=self.bounds;
        [self.frontLayer addSublayer:_shadowOnFronLayer];
        [self.backLayer addSublayer:_shadowOnBackLayer];
        _shadowOnBackLayer.backgroundColor=[UIColor colorWithRed:0/255.0f green:0/255.0f blue:0/255.0f alpha:1.0f].CGColor;
        _shadowOnFronLayer.backgroundColor=[UIColor colorWithRed:0/255.0f green:0/255.0f blue:0/255.0f alpha:1.0f].CGColor;
    }
    [CATransaction setDisableActions:YES];
    _shadowOnBackLayer.opacity=opacity;
    _shadowOnFronLayer.opacity=opacity;
}
///只显示一面的图层阴影
-(void)showShadowOpacity:(CGFloat)opacity onLayer:(int)layerPos{
    if (!_shadowOnFronLayer){
        _shadowOnFronLayer=[[CALayer alloc]init];
        _shadowOnFronLayer.frame=self.bounds;
        _shadowOnFronLayer.backgroundColor=[UIColor colorWithRed:0/255.0f green:0/255.0f blue:0/255.0f alpha:0.3f].CGColor;
        if (layerPos==0){
            [self.frontLayer addSublayer:_shadowOnFronLayer];
        }
        else{
            [self.backLayer addSublayer:_shadowOnFronLayer];
        }
    }
    
    [CATransaction setDisableActions:YES];
    _shadowOnFronLayer.opacity=opacity;
}
-(void)removeShadow{
    //NSLog(@"removeShadow");
    if (_shadowOnFronLayer){
        [_shadowOnFronLayer removeFromSuperlayer];
        _shadowOnFronLayer=nil;
    }
    if (_shadowOnBackLayer){
        [_shadowOnBackLayer removeFromSuperlayer];
        _shadowOnBackLayer=nil;
    }
}
@end
