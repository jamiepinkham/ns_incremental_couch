//
//  JPCouchIncrementalStore.m
//  JPCouchIncrementalStore
//
//  Created by Jamie Pinkham on 11/15/12.
//  Copyright (c) 2012 Jamie Pinkham. All rights reserved.
//

#import "JPCouchIncrementalStore.h"
#import "JPCouchManagedObject.h"
#import <TouchDB/TouchDB.h>
#import <TouchDB/TD_Database+Insertion.h>

@interface JPCouchIncrementalStore ()

- (void)generateViewsForManagedObjectsInManagedObjectModel:(NSManagedObjectModel *)managedObjectModel;

@property (nonatomic, retain) NSNumber *replicationInterval;
@property (nonatomic, retain) NSURL *canonicalStoreURL;

@property (nonatomic, retain) TD_Database *couchDB;

@property (nonatomic, retain) NSMutableDictionary *cachedPropertiesForObjects;


@end


NSString * const JPCouchIncrementalStoreCanonicalLocation = @"com.jamiepinkham.JPCouchIncrementalStoreCanonicalLocation";
NSString * const JPCouchIncrementalStoreReplicationInterval = @"com.jamiepinkham.JPCouchIncrementalStoreReplicationInterval";
NSString * const JPCouchIncrementalStoreDatabaseName = @"com.jamiepinkham.JPCouchIncrementalStoreDatabaseName";

NSString * const JPCouchIncrementalStoreConflictNotification = @"com.jamiepinkham.JPCouchIncrementalStoreConflictNotification";
NSString * const JPCouchIncrementalStoreConflictManagedObjectIdsUserInfoKey = @"com.jamiepinkham.JPCouchIncrementalStoreConflictManagedObjectIdsUserInfoKey";


NSString * const JPCouchIncrementalStoreErrorDomain = @"com.jamiepinkham.JPCouchIncrementalStore";

NSString * const JPCouchIncrementalStoreCDEntityPropertyName = @"com.jamiepinkham.cd_entity";
NSString * const JPCouchIncrementalStoreCDObjectIDPropertyName = @"com.jamiepinkham.mo_id";


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
		
		[self setCachedPropertiesForObjects:[NSMutableDictionary dictionary]];
		
		NSString *databaseName = nil;
		
		if([options objectForKey:JPCouchIncrementalStoreDatabaseName])
		{
			databaseName = [options objectForKey:JPCouchIncrementalStoreDatabaseName];
		}
		else
		{
			databaseName = [self generateUUID];
		}
		
		TD_Database *db = [[TD_Database alloc] initWithPath:[url path]];
		[self setCouchDB:db];
		
		[self generateViewsForManagedObjectsInManagedObjectModel:[root managedObjectModel]];
	}
	return self;
}

- (void)setCouchDB:(TD_Database *)couchDB
{
	if(_couchDB != couchDB)
	{
		[couchDB close];
		_couchDB = couchDB;
		[_couchDB open];
	}
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
	NSPersistentStoreRequestType requestType = request.requestType;
	if(requestType == NSFetchRequestType)
	{
		NSFetchRequest *fetchRequest = (NSFetchRequest *)request;
		return [self executeFetchRequest:fetchRequest context:context error:error];
	}
	else if(requestType == NSSaveRequestType)
	{
		NSSaveChangesRequest *saveRequest = (NSSaveChangesRequest *)request;
		return [self executeSaveRequest:saveRequest context:context error:error];
	}
	else
	{
		NSDictionary *userInfo = @{NSLocalizedDescriptionKey : [NSString stringWithFormat:NSLocalizedString(@"Unsupported NSFetchRequestResultType, %d", nil), request.requestType]};
        if (error) {
            *error = [[NSError alloc] initWithDomain:JPCouchIncrementalStoreErrorDomain code:0 userInfo:userInfo];
        }
        
        return nil;
	}
	
	return nil;
}

- (NSIncrementalStoreNode *)newValuesForObjectWithID:(NSManagedObjectID *)objectID withContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error
{
	NSDictionary *dictionary = [[self cachedPropertiesForObjects] objectForKey:[self referenceObjectForObjectID:objectID]];
	NSIncrementalStoreNode *node = [[NSIncrementalStoreNode alloc] initWithObjectID:objectID withValues:dictionary version:1];
	return node;
}

- (id)newValueForRelationship:(NSRelationshipDescription *)relationship forObjectWithID:(NSManagedObjectID *)objectID withContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error
{
	return nil;
}

- (NSArray *)obtainPermanentIDsForObjects:(NSArray *)array error:(NSError *__autoreleasing *)error
{
	NSMutableArray *permanentIDs = [NSMutableArray arrayWithCapacity:[array count]];
	
	for(NSManagedObject *object in array)
	{
		[permanentIDs addObject:[self newObjectIDForEntity:[object entity] referenceObject:[self generateUUID]]];
	}
	
	return permanentIDs;
}


#pragma mark - view generation

- (void)generateViewsForManagedObjectsInManagedObjectModel:(NSManagedObjectModel *)managedObjectModel
{
	for(NSEntityDescription *entityDescription in managedObjectModel)
	{
		TD_View *view = [[self couchDB] viewNamed:[entityDescription name]];
		[view setMapBlock:^(NSDictionary *doc, TDMapEmitBlock emit) {
			if(doc && doc[JPCouchIncrementalStoreCDEntityPropertyName])
			{
				if([doc[JPCouchIncrementalStoreCDEntityPropertyName] isEqualToString:[entityDescription name]])
				{
					emit(doc[@"_id"], doc);
				}
			}
		} reduceBlock:NULL version:@"1.0"];
		
	}
}


#pragma mark - request executions

- (id)executeFetchRequest:(NSFetchRequest *)fetchRequest context:(NSManagedObjectContext *)context error:(NSError *__autoreleasing*)error
{
	TDQueryOptions options = kDefaultTDQueryOptions;
	
	TD_View *view = [[self couchDB] viewNamed:[fetchRequest entityName]];
	
	if(view == nil)
	{
		if(error != nil)
		{
			NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"No avaliable view for entity named: %@", nil), [fetchRequest entityName]] };
			*error = [[NSError alloc] initWithDomain:JPCouchIncrementalStoreErrorDomain code:0 userInfo:userInfo];
		}
		return nil;
	}
	[view updateIndex];
	TDStatus status;
	NSArray *rows = [view queryWithOptions:&options status:&status];
	NSArray *mappedObjects = [self cachePropertyValuesInRows:rows forEntity:[fetchRequest entity] inContext:context];
	return mappedObjects;
	return nil;
}


- (id)executeSaveRequest:(NSSaveChangesRequest *)saveRequest context:(NSManagedObjectContext *)context error:(NSError *__autoreleasing*)error
{
	for(NSManagedObject *insertedObject in [saveRequest insertedObjects])
	{
		NSDictionary *attributeValues = [self encodeAttributesForObject:insertedObject];
	
		TD_Revision *rev = [[TD_Revision alloc] initWithProperties:attributeValues];
		TDStatus status;
		TD_Revision* result = [[self couchDB] putRevision: rev prevRevisionID: nil allowConflict: NO status: &status];
		if(status != kTDStatusCreated){
			NSLog(@"not created = %@", result);
		}
		
	}
	
	for(NSManagedObject *updatedObject in [saveRequest updatedObjects])
	{
		JPCouchManagedObject *couchUpdatedObject = (JPCouchManagedObject *)updatedObject;
		if([couchUpdatedObject valueForKey:@"revisionID"])
		{
			NSDictionary *attributeValues = [self encodeAttributesForObject:couchUpdatedObject];
			NSString *previousRevision = [updatedObject valueForKey:@"revisionID"];
			TD_Revision *rev = [[TD_Revision alloc] initWithProperties:attributeValues];
			TDStatus status;
			TD_Revision* result = [[self couchDB] putRevision: rev prevRevisionID:previousRevision allowConflict: NO status: &status];
			[updatedObject setValue:result.revID forKey:@"revisionID"];
			[updatedObject setValue:result.docID forKey:@"documentID"];
		}
//		NSLog(@"updated result = %@", result);

	}
	
	for(NSManagedObject *deletedObject in [saveRequest deletedObjects])
	{
		JPCouchManagedObject *couchDeletedObject = (JPCouchManagedObject *)deletedObject;
		
		if([couchDeletedObject valueForKey:@"revisionID"] && [couchDeletedObject valueForKey:@"documentID"])
		{
			NSString *previousRevision = [couchDeletedObject valueForKey:@"revisionID"];
			NSString *documentID = [couchDeletedObject valueForKey:@"documentID"];
			TD_Revision *rev = [[TD_Revision alloc] initWithDocID:documentID revID:previousRevision deleted:YES];
			TDStatus status;
			TD_Revision* result = [[self couchDB] putRevision: rev prevRevisionID:previousRevision allowConflict: NO status: &status];
			NSLog(@"deleted result = %@", result);
			
		}
	}
	
	return [NSArray array];
	return nil;
}

#pragma mark - mapping

- (NSDictionary *)encodeAttributesForObject:(NSManagedObject *)mo
{
	NSDictionary *attributeDictionary = [[mo entity] attributesByName];
	NSMutableDictionary *attributeValues = [[mo dictionaryWithValuesForKeys:[attributeDictionary allKeys]] mutableCopy];
	for(id key in [attributeValues allKeys])
	{
		id value = attributeValues[key];
		if([value isKindOfClass:[NSDate class]])
		{
			NSString *formattedDate = [dateFormatter() stringFromDate:value];
			attributeValues[key] = formattedDate;
		}
	}
	if([mo isInserted])
	{
		[attributeValues setObject:[[mo entity] name] forKey:JPCouchIncrementalStoreCDEntityPropertyName];
		NSString *moIdString = [self referenceObjectForObjectID:[mo objectID]];
		[attributeValues setObject:moIdString forKey:JPCouchIncrementalStoreCDObjectIDPropertyName];
	}
	return attributeValues;
}

static NSDateFormatter *formatter = nil;

static NSDateFormatter * dateFormatter()
{
	if(formatter == nil)
	{
		formatter = [[NSDateFormatter alloc] init];
		[formatter setDateFormat:@"yyyy-MM-dd'T'HH:mmZ"];
	}
	return formatter;
}

- (NSArray *)cachePropertyValuesInRows:(NSArray *)rows forEntity:(NSEntityDescription *)entity inContext:(NSManagedObjectContext *)context
{
	NSMutableArray *objects = [NSMutableArray arrayWithCapacity:[rows count]];
	for(NSDictionary *dictionary in rows)
	{
		NSDictionary *doc = dictionary[@"value"];
		NSString *moIDProperty = doc[JPCouchIncrementalStoreCDObjectIDPropertyName];
		NSManagedObjectID *moID = [self newObjectIDForEntity:entity referenceObject:moIDProperty];
		NSManagedObject *object = [context objectWithID:moID];
		NSDictionary *attributesDictionary = [entity attributesByName];
		NSMutableDictionary *cachedProperties = [NSMutableDictionary dictionary];
		for(NSString *attributeKey in [attributesDictionary allKeys])
		{
			NSAttributeDescription *attributeDescription = attributesDictionary[attributeKey];
			id value = nil;
			if([attributeDescription attributeType] == NSDateAttributeType)
			{
				value = [dateFormatter() dateFromString:doc[attributeKey]];
			}
			else
			{
				value = doc[attributeKey];
			}
			
			[cachedProperties setValue:value forKey:attributeKey];
		}
		[[self cachedPropertiesForObjects] setValue:cachedProperties forKey:[self referenceObjectForObjectID:moID]];
		
		[object setValue:doc[@"_rev"] forKey:@"revisionID"];
		[object setValue:doc[@"_id"] forKey:@"documentID"];
		[objects addObject:object];
	}
	return objects;
}


@end
