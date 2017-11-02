//
//  doSourceFS.h
//  DoFrame
//
//  Created by zhangwd on 14-11-21.
//  Copyright (c) 2014年 DongXian. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "doISourceFS.h"
#import "doIApp.h"
#import "doSourceFile.h"
#import "doServiceContainer.h"
#import "doGlobal.h"


@interface doSourceFS : NSObject<doISourceFS>{
@private
    NSMutableDictionary * dictSourceFiles;
}
- (id)init:(id<doIApp>)_app;

@end
