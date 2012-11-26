//
//  JPCouchConflictResolver.m
//  JPCouchIncrementalStore
//
//  Created by Jamie Pinkham on 11/24/12.
//  Copyright (c) 2012 Jamie Pinkham. All rights reserved.
//

#import "JPCouchConflictResolver.h"

@implementation JPCouchConflictResolver

- (NSDictionary *)resolvedValuesForCurrentRevisionValues:(NSDictionary *)current proposedRevisionValues:(NSDictionary *)proposed
{
	return proposed;
}

@end
