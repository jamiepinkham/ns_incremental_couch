//
//  JPCouchIncrementalStore.m
//  JPCouchIncrementalStore
//
//  Created by Jamie Pinkham on 11/15/12.
//  Copyright (c) 2012 Jamie Pinkham. All rights reserved.
//

#import "JPCouchIncrementalStore.h"
#import "NSManagedObject+JPCouchIncrementalStoreRev.h"

#import <TouchDB/TouchDB.h>

@interface JPCouchIncrementalStore ()

@property (nonatomic, retain) NSNumber *replicationInterval;
@property (nonatomic, retain) NSURL *canonicalStoreURL;
@property (nonatomic, retain) NSString *databaseName;

@end


NSString * const JPCouchIncrementalStoreCanonicalLocation = @"com.jamiepinkham.JPCouchIncrementalStoreCanonicalLocation";
NSString * const JPCouchIncrementalStoreReplicationInterval = @"com.jamiepinkham.JPCouchIncrementalStoreReplicationInterval";
NSString * const JPCouchIncrementalStoreDatabaseName = @"com.jamiepinkham.JPCouchIncrementalStoreDatabaseName";

NSString * const JPCouchIncrementalStoreConflictNotification = @"com.jamiepinkham.JPCouchIncrementalStoreConflictNotification";
NSString * const JPCouchIncrementalStoreConflictManagedObjectIdsUserInfoKey = @"com.jamiepinkham.JPCouchIncrementalStoreConflictManagedObjectIdsUserInfoKey";



@implementation JPCouchIncrementalStore

+ (void)initialize
{
	[NSPersistentStoreCoordinator registerStoreClass:self forStoreType:[self type]];
}

+ (NSString *)type
{
	return NSStringFromClass(self);
}


- (NSString *)generateUUID
{
	CFUUIDRef theUUID = CFUUIDCreate(NULL);
	CFStringRef string = CFUUIDCreateString(NULL, theUUID);
	CFRelease(theUUID);
	return (__bridge_transfer NSString *)string;
}

- (instancetype)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)root configurationName:(NSString *)name URL:(NSURL *)url options:(NSDictionary *)options
{
	self = [super initWithPersistentStoreCoordinator:root configurationName:name URL:url options:options];
	if(self)
	{
		[self setCanonicalStoreURL:[options objectForKey:JPCouchIncrementalStoreCanonicalLocation]];
		[self setReplicationInterval:[options objectForKey:JPCouchIncrementalStoreReplicationInterval]];
		
		NSString *databaseName = nil;
		
		if([options objectForKey:JPCouchIncrementalStoreDatabaseName])
		{
			databaseName = [options objectForKey:JPCouchIncrementalStoreDatabaseName];
		}
		else
		{
			databaseName = [self generateUUID];
		}
		
		[self setDatabaseName:databaseName];
	}
	return self;
}

- (BOOL)loadMetadata:(NSError *__autoreleasing *)error
{
	NSString *uuid = [self generateUUID];
	NSDictionary *metdata = @{NSStoreUUIDKey : uuid, NSStoreTypeKey : [[self class] type] };
	[self setMetadata:metdata];
	return YES;
}

- (id)executeRequest:(NSPersistentStoreRequest *)request withContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error
{
	return nil;
}

- (NSIncrementalStoreNode *)newValuesForObjectWithID:(NSManagedObjectID *)objectID withContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error
{
	return nil;
}

- (id)newValueForRelationship:(NSRelationshipDescription *)relationship forObjectWithID:(NSManagedObjectID *)objectID withContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error
{
	return nil;
}

- (NSArray *)obtainPermanentIDsForObjects:(NSArray *)array error:(NSError *__autoreleasing *)error
{
	return nil;
}

@end
