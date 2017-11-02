//
//  doIInitDataFS.h
//  DoCore
//
//  Created by wl on 16/5/29.
//  Copyright © 2016年 DongXian. All rights reserved.
//

#import <Foundation/Foundation.h>
@protocol doIApp;

@protocol doIInitDataFS <NSObject>
@property (nonatomic, readonly, weak) id<doIApp> CurrentApp;
@property (nonatomic, readonly, strong) NSString * RootPath;

//释放资源
- (void)Dispose;

@end
