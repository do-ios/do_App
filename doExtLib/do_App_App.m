//
//  do_App_App.m
//  DoExt_SM
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import "do_App_App.h"
static do_App_App* instance;
@implementation do_App_App
@synthesize OpenURLScheme;
+(id) Instance
{
    if(instance==nil)
        instance = [[do_App_App alloc]init];
    return instance;
}
@end
