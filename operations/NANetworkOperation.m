//
//  NANetworkOperation.m
//  SK3
//
//  Created by nashibao on 2012/10/10.
//  Copyright (c) 2012年 s-cubism. All rights reserved.
//

#import "NANetworkOperation.h"

#import "NSOperationQueue+na.h"

#import "NANetworkActivityIndicatorManager.h"

#import "Reachability.h"

//#import "JSONKit.h"

@implementation NANetworkOperation

static NSMutableArray *__all_operations__ = nil;
static NSMutableArray *__waiting_operations__ = nil;
static NSMutableArray *__waiting_queues__ = nil;
static NSMutableDictionary *_operations_with_id = nil;
static Reachability *__reach__ = nil;
static BOOL __reachability__ = NO;

// FIXME: 本当は呼び出しもとのスレッドは決めておいた方がいいな．lockはかけたくないしmainはいやだから、globalBackgroundThreadがあるといいけど?gcdのglobal background queueを使うか．

+ (void)load{
    [super load];
    _operations_with_id = [[NSMutableDictionary alloc] init];
    __all_operations__ = [@[] mutableCopy];
    __waiting_operations__ = [@[] mutableCopy];
    __waiting_queues__ = [@[] mutableCopy];
    __reach__ = [Reachability reachabilityWithHostname:@"www.google.com"];
    
    __reach__.reachableBlock = ^(Reachability *reach){
        if(__reachability__)return;
        __reachability__ = YES;
        NSLog(@"%s|%@", __PRETTY_FUNCTION__, @"Reachable!!");
//        waiting -> queue
        int opcnt = 0;
        for (NANetworkOperation *op in __waiting_operations__) {
            id queue =__waiting_queues__[opcnt];
            opcnt += 1;
            if([queue isKindOfClass:[NSOperationQueue class]]){
                [queue addOperation:op];
            }else{
                [op resume];
            }
        }
        [__waiting_operations__ removeAllObjects];
        [__waiting_queues__ removeAllObjects];
    };
    __reach__.unreachableBlock = ^(Reachability *reach){
        if(!__reachability__)return;
        __reachability__ = NO;
        NSLog(@"%s|%@", __PRETTY_FUNCTION__, @"Unreachable!!");
//        all -> waiting
        for (NANetworkOperation *op in __all_operations__) {
            [op pause];
            if([__waiting_operations__ indexOfObject:op]==NSNotFound){
                [__waiting_operations__ addObject:op];
                [__waiting_queues__ addObject:[NSNull null]];
            }
        }
    };
    [__reach__ startNotifier];
    __reachability__ = __reach__.isReachable;
}

+ (NANetworkOperation *)sendJsonAsynchronousRequest:(NSURLRequest *)request
                                         jsonOption:(NSJSONReadingOptions)jsonOption
                                     returnEncoding:(NSStringEncoding)returnEncoding
                                         returnMain:(BOOL)returnMain
                                              queue:(NSOperationQueue *)queue
                                         identifier:(NSString *)identifier
                                 identifierMaxCount:(NSInteger)identifierMaxCount
                                            options:(NSDictionary *)options
                                     queueingOption:(NANetworkOperationQueingOption)queueingOption
                                     successHandler:(void(^)(NANetworkOperation *op, id data))successHandler
                                       errorHandler:(void(^)(NANetworkOperation *op, NSError *err))errorHandler{
    return [self _sendAsynchronousRequest:request isJson:YES jsonOption:jsonOption returnEncoding:returnEncoding returnMain:returnMain queue:queue identifier:identifier identifierMaxCount:identifierMaxCount options:options queueingOption:queueingOption successHandler:successHandler errorHandler:errorHandler completeHandler:nil];
}

+ (NANetworkOperation *)sendJsonAsynchronousRequest:(NSURLRequest *)request
                                         jsonOption:(NSJSONReadingOptions)jsonOption
                                     returnEncoding:(NSStringEncoding)returnEncoding
                                         returnMain:(BOOL)returnMain
                                              queue:(NSOperationQueue *)queue
                                         identifier:(NSString *)identifier
                                 identifierMaxCount:(NSInteger)identifierMaxCount
                                            options:(NSDictionary *)options
                                     queueingOption:(NANetworkOperationQueingOption)queueingOption
                                     successHandler:(void(^)(NANetworkOperation *op, id data))successHandler
                                       errorHandler:(void(^)(NANetworkOperation *op, NSError *err))errorHandler
                                    completeHandler:(void (^)(NANetworkOperation *))completeHandler{
    return [self _sendAsynchronousRequest:request isJson:YES jsonOption:jsonOption returnEncoding:returnEncoding returnMain:returnMain queue:queue identifier:identifier identifierMaxCount:identifierMaxCount options:options queueingOption:queueingOption successHandler:successHandler errorHandler:errorHandler completeHandler:completeHandler];
}

+ (NANetworkOperation *)sendAsynchronousRequest:(NSURLRequest *)request
                                 returnEncoding:(NSStringEncoding)returnEncoding
                                     returnMain:(BOOL)returnMain
                                          queue:(NSOperationQueue *)queue
                                     identifier:(NSString *)identifier
                             identifierMaxCount:(NSInteger)identifierMaxCount
                                        options:(NSDictionary *)options
                                 queueingOption:(NANetworkOperationQueingOption)queueingOption
                                 successHandler:(void(^)(NANetworkOperation *op, id data))successHandler
                                   errorHandler:(void(^)(NANetworkOperation *op, NSError *err))errorHandler{
    return [self _sendAsynchronousRequest:request isJson:NO jsonOption:0 returnEncoding:returnEncoding returnMain:returnMain queue:queue identifier:identifier identifierMaxCount:identifierMaxCount  options:options queueingOption:queueingOption successHandler:successHandler errorHandler:errorHandler completeHandler:nil];
}

+ (NANetworkOperation *)sendAsynchronousRequest:(NSURLRequest *)request
                                 returnEncoding:(NSStringEncoding)returnEncoding
                                     returnMain:(BOOL)returnMain
                                          queue:(NSOperationQueue *)queue
                                     identifier:(NSString *)identifier
                             identifierMaxCount:(NSInteger)identifierMaxCount
                                        options:(NSDictionary *)options
                                 queueingOption:(NANetworkOperationQueingOption)queueingOption
                                 successHandler:(void(^)(NANetworkOperation *op, id data))successHandler
                                   errorHandler:(void(^)(NANetworkOperation *op, NSError *err))errorHandler
                                completeHandler:(void (^)(NANetworkOperation *))completeHandler{
    return [self _sendAsynchronousRequest:request isJson:NO jsonOption:0 returnEncoding:returnEncoding returnMain:returnMain queue:queue identifier:identifier identifierMaxCount:identifierMaxCount  options:options queueingOption:queueingOption successHandler:successHandler errorHandler:errorHandler completeHandler:completeHandler];
}

+ (NANetworkOperation *)_sendAsynchronousRequest:(NSURLRequest *)request
                                          isJson:(BOOL)isJson
                                         jsonOption:(NSJSONReadingOptions)jsonOption
                                     returnEncoding:(NSStringEncoding)returnEncoding
                                         returnMain:(BOOL)returnMain
                                              queue:(NSOperationQueue *)queue
                                      identifier:(NSString *)identifier
                              identifierMaxCount:(NSInteger)identifierMaxCount
                                         options:(NSDictionary *)options
                                  queueingOption:(NANetworkOperationQueingOption)queueingOption
                                     successHandler:(void(^)(NANetworkOperation *op, id data))successHandler
                                    errorHandler:(void(^)(NANetworkOperation *op, NSError *err))errorHandler
                                 completeHandler:(void(^)(NANetworkOperation *op))completeHandler{
    if(!identifierMaxCount)
        identifierMaxCount = 1;
    NANetworkOperation *op = nil;
    NSMutableArray *operations = _operations_with_id[identifier];
    if([operations count] >= identifierMaxCount){
        if(queueingOption == NANetworkOperationQueingOptionReturnOld){
            op = [operations lastObject];
            return op;
        }else if(queueingOption == NANetworkOperationQueingOptionCancel){
            [self cancelByIdentifier:identifier handler:nil];
        }
    }
    
    [[NANetworkActivityIndicatorManager sharedManager] incrementActivityCount:identifier option:options];
    
    op = [[[self class] alloc] initWithRequest:request];
    [__all_operations__ addObject:op];
    [op setCompletionBlockWithSuccess:successHandler failure:errorHandler complete:completeHandler isJson:isJson jsonOption:jsonOption returnMain:returnMain returnEncoding:returnEncoding];
    NSOperationQueue *_queue = queue ?: [NSOperationQueue globalBackgroundQueue];
    [op setIdentifier:identifier];
    operations = _operations_with_id[identifier] ?: [@[] mutableCopy];
    [operations addObject:op];
    _operations_with_id[identifier] = operations;
    [op checkIdentifierStart];
    
    if([__reach__ isReachable]){
        [_queue addOperation:op];
    }else{
        [__waiting_operations__ addObject:op];
        [__waiting_queues__ addObject:_queue];
    }
    return op;
}

+ (NSArray *)getOperationsByIdentifier:(NSString *)identifier{
    return _operations_with_id[identifier];
}

+ (NSArray *)cancelByIdentifier:(NSString *)identifier handler:(void (^)(void))handler{
    NSArray *operations = [self getOperationsByIdentifier:identifier];
    if(operations){
        __block NSInteger cnt = 0;
        NSInteger maxcnt = [operations count];
        for (NANetworkOperation *op in operations) {
            op.finish_block = ^{
                cnt += 1;
                if(maxcnt == cnt){
                    NSLog(@"%s|%@", __PRETTY_FUNCTION__, @"cancelled!!");
                    if(handler)
                        handler();
                }
            };
            [op cancel];
        }
    }
    return operations;
}

- (void)setCompletionBlockWithSuccess:(void (^)(id operation, id responseObject))success
                              failure:(void (^)(id operation, NSError *error))failure
                             complete:(void(^)(NANetworkOperation *op))complete
                               isJson:(BOOL)isJson
                           jsonOption:(NSJSONReadingOptions)jsonOption
                           returnMain:(BOOL)returnMain
                       returnEncoding:(NSStringEncoding)returnEncoding{
    __block __weak NANetworkOperation *wself = self;
    self.success_block = success;
    self.fail_block = failure;
    self.complete_block = complete;
    self.completionBlock = ^{
        [__all_operations__ removeObject:wself];
        NSMutableArray *operations = _operations_with_id[wself.identifier];
        [operations removeObject:wself];
        NSUInteger temp_index = [__waiting_operations__ indexOfObject:wself];
        if(temp_index != NSNotFound){
            [__waiting_operations__ removeObjectAtIndex:temp_index];
            [__waiting_queues__ removeObjectAtIndex:temp_index];
        }
        [wself checkIdentifierFinish];
        if ([wself isCancelled]) {
            if(wself.cancel_block)
                wself.cancel_block();
            if(wself.finish_block)
                wself.finish_block();
            [[NANetworkActivityIndicatorManager sharedManager] decrementActivityCount:wself.identifier];
            return;
        }
        NSError *_err = nil;
        id response = nil;
        if (wself.error) {
            if (wself.fail_block) {
                _err = wself.error;
            }
        } else {
            if (wself.success_block) {
                response = wself.responseData;
                if(isJson){
                    NSError *jsonErr = nil;
                    response = [NSJSONSerialization dataWithJSONObject:response options:0 error:&jsonErr];
//                    response = [response objectFromJSONDataWithParseOptions:JKParseOptionStrict error:&jsonErr];
                    if(jsonErr){
                        _err = jsonErr;
                    }
                }else{
                    response = [[NSString alloc] initWithData:response encoding:returnEncoding];
                }
            }
        }
        if(_err){
            if(wself.fail_block){
                if(returnMain){
                    dispatch_async(dispatch_get_main_queue(), ^{
                        wself.fail_block(wself, _err);
                    });
                }else{
                    wself.fail_block(wself, _err);
                }
            }
            [[NANetworkActivityIndicatorManager sharedManager] decrementActivityCount:wself.identifier error:[NSString stringWithFormat:@"%@", _err]];
        }else{
            if(wself.success_block){
                if(returnMain){
                    dispatch_async(dispatch_get_main_queue(), ^{
                        wself.success_block(wself, response);
                    });
                }else{
                    wself.success_block(wself, response);
                }
            }
            [[NANetworkActivityIndicatorManager sharedManager] decrementActivityCount:wself.identifier];
        }
        if(wself.finish_block)
            wself.finish_block();
        if(wself.complete_block){
            dispatch_async(dispatch_get_main_queue(), ^{
                wself.complete_block(wself);
            });
        }
    };
    
}

- (void)checkIdentifierStart{
    if(self.identifier){
        NSMutableArray *operations = _operations_with_id[self.identifier];
        if([operations count] == 1){
            [[NSNotificationCenter defaultCenter] postNotificationName:NANetworkOperationIdentifierStart object:self.identifier];
        }
    }
}

- (void)checkIdentifierFinish{
    if(self.identifier){
        NSMutableArray *operations = _operations_with_id[self.identifier];
        if([operations count] == 0){
            [[NSNotificationCenter defaultCenter] postNotificationName:NANetworkOperationIdentifierEnd object:self.identifier];
        }
    }
}

@end
