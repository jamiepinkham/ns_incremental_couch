//
//  JPCouchIncrementalStore.h
//  JPCouchIncrementalStore
//
//  Created by Jamie Pinkham on 11/15/12.
//  Copyright (c) 2012 Jamie Pinkham. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@protocol JPCouchIncrementalStoreDelegate;

extern NSString * const JPCouchIncrementalStoreCanonicalLocation;
extern NSString * const JPCouchIncrementalStoreReplicationInterval;
extern NSString * const JPCouchIncrementalStoreDatabaseName;

extern NSString * const JPCouchIncrementalStoreConflictNotification;
extern NSString * const JPCouchIncrementalStoreConflictManagedObjectIdsUserInfoKey;

extern NSString * const JPCouchIncrementalStoreType;

@interface JPCouchIncrementalStore : NSIncrementalStore

+ (NSString *)type;

@property (nonatomic, assign) id<JPCouchIncrementalStoreDelegate> delegate;

@end