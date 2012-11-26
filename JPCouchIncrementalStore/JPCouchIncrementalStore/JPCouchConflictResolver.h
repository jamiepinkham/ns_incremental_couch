//
//  JPCouchConflictResolver.h
//  JPCouchIncrementalStore
//
//  Created by Jamie Pinkham on 11/24/12.
//  Copyright (c) 2012 Jamie Pinkham. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JPCouchConflictResolver : NSObject

- (NSDictionary *)resolvedValuesForCurrentRevisionValues:(NSDictionary *)current proposedRevisionValues:(NSDictionary *)proposed;

@end
