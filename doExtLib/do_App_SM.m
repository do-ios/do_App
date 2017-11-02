//
//  do_App_SM.m
//  DoExt_API
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import "do_App_SM.h"

#import "doScriptEngineHelper.h"
#import "doIScriptEngine.h"
#import "doInvokeResult.h"

#import "doServiceContainer.h"
#import "doIGlobal.h"
#import "doIScriptEngineFactory.h"
#import "doIDataFS.h"
#import "doISourceFS.h"
#import "doIInitDataFS.h"
#import "doIPageViewFactory.h"
#import "doServiceContainer.h"
#import "doIMultitonModuleFactory.h"
#import "doJsonHelper.h"
#import "doIOHelper.h"
#import "doIPageViewFactory.h"
#import "doIPage.h"
#import "doUIModuleHelper.h"

#define libraryPath [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]


@implementation do_App_SM
{
    NSMutableDictionary * dictConfigs;
    NSMutableDictionary * dictModuleAddresses;
    NSMutableDictionary * dictModuleID;
}
@synthesize DataFS=_DataFS;
@synthesize AppID = _AppID;
@synthesize SourceFS=_SourceFS;
@synthesize ScriptEngine=_ScriptEngine;
@synthesize InitDataFS = _InitDataFS;
#pragma mark - 方法
#pragma mark - 同步异步方法的实现
//同步
- (void)LoadApp:(NSString *)_appID{
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSString * _verDestFile = [NSString stringWithFormat:@"%@/%@",[doServiceContainer Instance].Global.SourceRootPath,_appID];
    
    if (![fileMgr fileExistsAtPath:_verDestFile]) {
        @throw [NSException exceptionWithName:@"doApp" reason:[NSString stringWithFormat:@"不存在应用：%@",_appID] userInfo:nil];
        
    }
    _AppID = _appID;
    //初始化成员变量
    dictConfigs = [[NSMutableDictionary alloc]init];
    _DataFS = [doServiceContainer Instance].DataFS;
    _SourceFS = [doServiceContainer Instance].SourceFS;
    _InitDataFS = [doServiceContainer Instance].InitDataFS;
    dictModuleAddresses = [[NSMutableDictionary alloc]init];
    dictModuleID = [[NSMutableDictionary alloc]init];
    
    [[doServiceContainer Instance].ScriptEngineFactory SetDeviceOneLibScriptPath: [NSString stringWithFormat:@"%@/",[NSBundle mainBundle].bundlePath]];
    
    _ScriptEngine = [[doServiceContainer Instance].ScriptEngineFactory CreateScriptEngine:self :nil :nil :[self scriptsName]];
    if (_ScriptEngine == nil) {
        @throw [NSException exceptionWithName:@"doApp" reason:@"无法创建脚本引擎：" userInfo:nil];
    }
}

- (void)LoadScripts{
    NSString *fileName = [self scriptsName];

    doSourceFile * _scriptFile = [self.SourceFS GetSourceByFileName:fileName];
    if (_scriptFile != nil && _scriptFile.TxtContent.length > 0)
    {
        [self.ScriptEngine LoadScripts:_scriptFile.TxtContent ];
    }
}

- (NSString *)scriptsName
{
    NSString *fileName = @"";
    NSString *scriptType = [doServiceContainer Instance].Global.ScriptType;
    if ([scriptType hasSuffix:@"lua"]) {
        fileName = @"source://app.lua";
    }else
    fileName = @"source://app.js";
    
    return fileName;
}

#pragma mark -
#pragma mark - override

- (void)Dispose{
    if (self.DataFS != nil)
    {
        [self.DataFS Dispose];
        _DataFS = nil;
    }
    if (self.SourceFS != nil)
    {
        [self.SourceFS Dispose];
        _SourceFS = nil;
    }
    if (self.InitDataFS != nil)
    {
        [self.InitDataFS Dispose];
        _InitDataFS = nil;
    }
    if (self.ScriptEngine != nil)
    {
        [self.ScriptEngine Dispose];
        _ScriptEngine = nil;
    }
    if (dictConfigs != nil)
    {
        for (NSString* _key in [dictConfigs allKeys])
        {
            [dictConfigs[_key] Dispose];
        }
        [dictConfigs removeAllObjects];
        dictConfigs = nil;
    }
    [dictModuleID removeAllObjects];
    dictModuleID = nil;
    if (dictModuleAddresses != nil)
    {
        //释放每一个子Model
        for (doMultitonModule* _moduleModel in [dictModuleAddresses allValues])
        {
            [_moduleModel Dispose];
        }
        [dictModuleAddresses removeAllObjects];
        dictModuleAddresses = nil;
    }
    [super Dispose];
}

-(doMultitonModule*) CreateMultitonModule:(NSString*) _typeID :(NSString*) _id
{
    if (_typeID == nil || [_typeID length] <= 0) @throw [NSException exceptionWithName:@"doApp" reason:@"未指定Model组件的type值"  userInfo:nil];
    doMultitonModule*  _moduleModel = nil;
    NSString* tempId = nil;
    if(_id!=nil&&_id.length>0)
        tempId = [_typeID stringByAppendingString:_id];
    
    if(tempId!=nil&&dictModuleID[tempId]!=nil){
        _moduleModel = dictModuleAddresses[dictModuleID[tempId]];
    }else{
        _moduleModel = [[doServiceContainer Instance].MultitonModuleFactory CreateMultitonModule:_typeID];
        if (_moduleModel == nil) @throw [NSException exceptionWithName:@"doApp" reason:[NSString stringWithFormat:@"遇到无效的Model组件：%@",_typeID] userInfo:nil];
        _moduleModel.CurrentPage = nil;
        _moduleModel.CurrentApp = self;
        dictModuleAddresses[_moduleModel.UniqueKey] = _moduleModel;
        if(tempId!=nil){
            dictModuleID[tempId] = _moduleModel.UniqueKey;
        }
    }
    return _moduleModel;
}
-(BOOL) DeleteMultitonModule:(NSString*) _address
{
    doMultitonModule* _moduleModel = [self GetMultitonModuleByAddress: _address];
    if (_moduleModel == nil) return false;
    [_moduleModel Dispose];
    [dictModuleAddresses removeObjectForKey:_address];
    for(NSString* key in dictModuleID.allKeys)
    {
        if([dictModuleID[key] isEqualToString:_address])
        {
            [dictModuleID removeObjectForKey:key];
            break;
        }
    }
    return true;
}

-(doMultitonModule*) GetMultitonModuleByAddress:(NSString*) _key
{
    if (![[dictModuleAddresses allKeys] containsObject:_key]) return nil;
    return dictModuleAddresses[_key];
}

#pragma mark -
#pragma mark - private
//获取应用ID 同步
- (void) getAppID: (NSArray*) parms
{
    doInvokeResult * _invokeResult = [parms objectAtIndex:2];
    [_invokeResult SetResultText: self.AppID];
}

//打开一个页面 异步
- (void)openPage:(NSArray*) parms
{
    NSDictionary* _dictParas = [parms objectAtIndex:0];
    id<doIScriptEngine> _scriptEngine = [parms objectAtIndex:1];
    NSString* _callbackFuncName = [parms objectAtIndex:2];
    NSString * _pageFile = [doJsonHelper GetOneText: _dictParas: @"source" :nil];
    if (_pageFile == nil || _pageFile.length <= 0)
        @throw [NSException exceptionWithName:@"doApp" reason:@"打开页面时未指定相关文件" userInfo:nil];
    NSString * _animationType = [doJsonHelper GetOneText: _dictParas: @"animationType" :@"slide_r2l"];
    NSString * _scriptType = [doJsonHelper GetOneText: _dictParas: @"scriptType" :nil];
    NSString *  _inputData = [doJsonHelper GetOneText: _dictParas: @"data" :@""];
    NSString *  _statusBarState = [doJsonHelper GetOneText: _dictParas: @"statusBarState" : @"show"];
    NSString *  _keyboardMode = [doJsonHelper GetOneText: _dictParas: @"keyboardMode" : @""];
    NSString * _statusBarFgColor = [doJsonHelper GetOneText: _dictParas: @"statusBarFgColor" : @""];
    NSString * _pageId = [doJsonHelper GetOneText: _dictParas: @"id" : @""];
    NSString * statusBarBgColor = [doJsonHelper GetOneText: _dictParas: @"statusBarBgColor" : @""];
    
    
    doSourceFile * _sourceFile = [self.SourceFS GetSourceByFileName:_pageFile];
    if (_sourceFile == nil)
        @throw [NSException exceptionWithName:@"doApp" reason:[NSString stringWithFormat:@"试图打开一个无效的页面文件:%@",_pageFile] userInfo:nil];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        //回到主线程修改UI
        [[doServiceContainer Instance].PageViewFactory OpenPage:self.AppID :_pageFile :_scriptType :_animationType :_inputData: _statusBarState : _keyboardMode :_callbackFuncName  :_statusBarFgColor :_pageId :statusBarBgColor];
        doInvokeResult * _invokeResult = [[doInvokeResult alloc ] init:self.UniqueKey];
        [_scriptEngine Callback:_callbackFuncName :_invokeResult];
    });
}
//关闭当前页面 异步
- (void)closePage:(NSArray*) parms{
    [self closePageAll:parms :1];
}

- (void)closePageToID:(NSArray*) parms{
    [self closePageAll:parms :2];
}

- (void)closePageAll:(NSArray*) parms  :(int)type
{
    if (!parms) {
        return;
    }
    if (parms.count < 3) {
        return;
    }
    NSDictionary* _dictParas = [parms objectAtIndex:0];
    id<doIScriptEngine> _scriptEngine = [parms objectAtIndex:1];
    NSString* _callbackFuncName = [parms objectAtIndex:2];
    dispatch_async(dispatch_get_main_queue(), ^{
        //回到主线程修改UI
        NSString *  _animationType = [doJsonHelper GetOneText: _dictParas: @"animationType" : @""];
        if ([_animationType isEqualToString:@""]) {
            id<doIPageView> pageview = [((UINavigationController*)[doServiceContainer Instance].PageViewFactory).viewControllers lastObject];
            _animationType = [doUIModuleHelper GetCloseAnimation:pageview.openPageAnimation];
        }
        
        int _layers = [doJsonHelper GetOneInteger:_dictParas :@"layer" :1];
        if (_layers<1) {
            _layers = 1;
        }
        NSString *ID = [doJsonHelper GetOneText:_dictParas :@"id" :@""];
        NSString *  _data = [doJsonHelper GetOneText: _dictParas: @"data" : @""];
        
        if (type == 1) {
            [[doServiceContainer Instance].PageViewFactory ClosePage:_animationType :_layers :_data];
        }else
            [[doServiceContainer Instance].PageViewFactory ClosePageToID:_animationType :ID :_data];
        
        doInvokeResult * _invokeResult = [[doInvokeResult alloc ] init:self.UniqueKey];
        [_scriptEngine Callback:_callbackFuncName :_invokeResult];
    });
}

- (void)update:(NSArray*) parms
{
    NSDictionary* _dictParas = [parms objectAtIndex:0];
    id<doIScriptEngine> _scriptEngine = [parms objectAtIndex:1];
    NSString* _callbackFuncName = [parms objectAtIndex:2];
    doInvokeResult * _invokeResult = [[doInvokeResult alloc ] init:self.UniqueKey];
    // 更新后文件的名称 (包含路径)
    NSString *_target = [doJsonHelper GetOneText: _dictParas :@"target" :@""];
    // 要进行更新的源文件路径
    NSArray *_sources = [doJsonHelper GetOneArray:_dictParas :@"source"];
    NSMutableArray* _sourceFull = [[NSMutableArray alloc]init];
    
    @try {
        if (_target.length<=0) {
            [NSException raise:@"doApp" format:@"update的target参数不能为空"];
        }else if(![_target hasPrefix:@"source://"])
            [NSException raise:@"doApp" format:@"update的target只能是source://目录下的"];
        
        if (_sources.count<=0) {
            [NSException raise:@"doApp" format:@"update的source参数不能为空"];
        }
        
        NSRange range = [_target rangeOfString:@"source://"];
        _target = [_target substringFromIndex:range.length];
        _target = [NSString stringWithFormat:@"%@/%@",_scriptEngine.CurrentApp.SourceFS.MappingSourceRootPath,_target];
        
        if(![doIOHelper ExistDirectory:_target])
            [doIOHelper CreateDirectory:_target];
        for(int i = 0;i<_sources.count;i++)
        {
            if(_sources[i]!=nil)
            {
                if (![_sources[i] hasPrefix:@"data://"]){
                    [NSException raise:@"doApp" format:@"update的source参数必须为data目录"];
                    break;
                }
                NSString* _temp = [_scriptEngine.CurrentApp.DataFS GetFileFullPathByName:_sources[i]];
                BOOL isDir;
                //目录
                if([[NSFileManager defaultManager] fileExistsAtPath:_temp isDirectory:&isDir] && isDir){
                    [_sourceFull addObject:_temp];
                }
                else
                {
                    //文件
                    if (![doIOHelper ExistFile:_temp]) {
                        continue;
                    }
                    if(_temp!=nil)
                        [_sourceFull addObject:_temp];
                }
            }
        }
        if (_sourceFull.count > 0) {//更新后删除的情况
            for(int i = 0;i<_sourceFull.count;i++)
            {
                BOOL isDir;
                //目录
                if([[NSFileManager defaultManager] fileExistsAtPath:_sourceFull[i] isDirectory:&isDir] && isDir){
                    [doIOHelper DirectoryCopy:_sourceFull[i] :_target];
                }
                else
                {
                    NSString* file = [_sourceFull[i] lastPathComponent];
                    NSString* targetFile =[NSString stringWithFormat:@"%@/%@",_target,file];
                    [doIOHelper FileCopy:_sourceFull[i] : targetFile];
                }
            }
            
            [_invokeResult SetResultBoolean:YES];
        }
        else
        {
            [_invokeResult SetResultBoolean:NO];
        }
        
    }
    @catch (NSException *exception) {
        [_invokeResult SetException:exception];
    }
    [_SourceFS clear];
    [_scriptEngine Callback:_callbackFuncName :_invokeResult];
}


@end
