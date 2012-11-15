//
//  JPCouchIncrementalStore.m
//  JPCouchIncrementalStore
//
//  Created by Jamie Pinkham on 11/15/12.
//  Copyright (c) 2012 Jamie Pinkham. All rights reserved.
//

#import "JPCouchIncrementalStore.h"

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

- (BOOL)loadMetadata:(NSError *__autoreleasing *)error
{
	NSString *uuid = [self generateUUID];
	NSDictionary *metdata = @{NSStoreUUIDKey : uuid, NSStoreTypeKey : [[self class] type]};
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
