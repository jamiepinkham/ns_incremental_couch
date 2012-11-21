//
//  NSManagedObject+JPCouchIncrementalStoreRev.m
//  JPCouchIncrementalStore
//
//  Created by Jamie Pinkham on 11/15/12.
//  Copyright (c) 2012 Jamie Pinkham. All rights reserved.
//

#import "NSManagedObject+JPCouchIncrementalStoreRev.h"
#import <objc/runtime.h>

@implementation NSManagedObject (JPCouchIncrementalStoreRev)

static char * JPCouchIncrementalStoreRevKey;

- (NSString *)jp_couchRev
{
	return (NSString *)objc_getAssociatedObject(self, &JPCouchIncrementalStoreRevKey);
}

- (void)setJp_couchRev:(NSString *)jp_couchRev
{
	objc_setAssociatedObject(self, &JPCouchIncrementalStoreRevKey, jp_couchRev, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
