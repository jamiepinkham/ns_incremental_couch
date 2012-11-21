//
//  JPCouchIncrementalStore.h
//  JPCouchIncrementalStore
//
//  Created by Jamie Pinkham on 11/15/12.
//  Copyright (c) 2012 Jamie Pinkham. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "JPCouchIncrementalStoreDelegate.h"

extern NSString * const JPCouchIncrementalStoreCanonicalLocation;
extern NSString * const JPCouchIncrementalStoreReplicationInterval;
extern NSString * const JPCouchIncrementalStoreDatabaseName;

extern NSString * const JPCouchIncrementalStoreConflictNotification;
extern NSString * const JPCouchIncrementalStoreConflictManagedObjectIdsUserInfoKey;

@interface JPCouchIncrementalStore : NSIncrementalStore

@property (nonatomic, assign) id<JPCouchIncrementalStoreDelegate> delegate;

@end
