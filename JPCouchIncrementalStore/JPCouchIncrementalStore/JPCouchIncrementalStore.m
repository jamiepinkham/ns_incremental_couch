//
//  JPCouchIncrementalStore.m
//  JPCouchIncrementalStore
//
//  Created by Jamie Pinkham on 11/15/12.
//  Copyright (c) 2012 Jamie Pinkham. All rights reserved.
//

#import "JPCouchIncrementalStore.h"
#import "JPCouchManagedObject.h"
#import "JPCouchConflictResolver.h"
#import <TouchDB/TouchDB.h>
#import <TouchDB/TD_Database+Insertion.h>
#import <TouchDB/TD_Body.h>

@interface JPCouchIncrementalStore ()

@property (nonatomic, retain) NSNumber *replicationInterval;
@property (nonatomic, retain) NSURL *canonicalStoreURL;

@property (nonatomic, retain) TD_Database *couchDB;

@property (nonatomic, retain) NSMutableDictionary *cachedPropertiesForObjects;

@property (nonatomic, retain) JPCouchConflictResolver *defaultConflictResolver;
@end


NSString * const JPCouchIncrementalStoreCanonicalLocation = @"com.jamiepinkham.JPCouchIncrementalStoreCanonicalLocation";
NSString * const JPCouchIncrementalStoreReplicationInterval = @"com.jamiepinkham.JPCouchIncrementalStoreReplicationInterval";
NSString * const JPCouchIncrementalStoreDatabaseName = @"com.jamiepinkham.JPCouchIncrementalStoreDatabaseName";

NSString * const JPCouchIncrementalStoreConflictNotification = @"com.jamiepinkham.JPCouchIncrementalStoreConflictNotification";
NSString * const JPCouchIncrementalStoreConflictManagedObjectIdsUserInfoKey = @"com.jamiepinkham.JPCouchIncrementalStoreConflictManagedObjectIdsUserInfoKey";


NSString * const JPCouchIncrementalStoreErrorDomain = @"com.jamiepinkham.JPCouchIncrementalStore";

NSString * const JPCouchIncrementalStoreCDEntityPropertyName = @"com.jamiepinkham.cd_entity";
NSString * const JPCouchIncrementalStoreCDObjectIDPropertyName = @"com.jamiepinkham.mo_id";
NSString * const JPCouchIncrementalStoreCDRelationshipFormatPropertyName = @"com.jamiepinkham.relationship_%@_mo_ids";


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
		
		JPCouchConflictResolver *resolver = [JPCouchConflictResolver new];
		[self setDefaultConflictResolver:resolver];
	}
	return self;
}

- (void)dealloc
{
	if([self couchDB])
	{
		[[self couchDB] compact];
		[[self couchDB] close];
	}
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
	NSString *docID = [self referenceObjectForObjectID:objectID];
	NSDictionary *dictionary = [[self cachedPropertiesForObjects] objectForKey:docID];
	if(dictionary == nil)
	{
		
		TD_Revision *rev = [[self couchDB] getDocumentWithID:docID revisionID:nil];
		TD_Body *body = [rev body];
		NSDictionary *documentProperties = [body properties];
		[self cachePropertyValuesInDocuments:@[documentProperties] forEntity:[objectID entity] inContext:context];
		dictionary = [[self cachedPropertiesForObjects] objectForKey:docID];
		
	}
	NSIncrementalStoreNode *node = [[NSIncrementalStoreNode alloc] initWithObjectID:objectID withValues:dictionary version:1];
	return node;
}

- (id)newValueForRelationship:(NSRelationshipDescription *)relationship forObjectWithID:(NSManagedObjectID *)objectID withContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error
{
	NSDictionary *dictionary = [[self cachedPropertiesForObjects] objectForKey:[self referenceObjectForObjectID:objectID]];
	NSString *relationshipName = [relationship name];
	if(dictionary[relationshipName])
	{
		return dictionary[relationshipName];
	}
	
	return [NSNull null];
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


- (void)managedObjectContextDidUnregisterObjectsWithIDs:(NSArray *)objectIDs
{
	for(NSManagedObjectID *moID in objectIDs)
	{
		NSString *docID = [self referenceObjectForObjectID:moID];
		[[self cachedPropertiesForObjects] removeObjectForKey:docID];
	}
}


#pragma mark - request executions

- (id)executeFetchRequest:(NSFetchRequest *)fetchRequest context:(NSManagedObjectContext *)context error:(NSError *__autoreleasing*)error
{
	TDQueryOptions options = kDefaultTDQueryOptions;
	
	if([fetchRequest fetchLimit] > 0)
	{
		options.limit = [fetchRequest fetchLimit];
	}
	
	if([fetchRequest fetchOffset] > 0)
	{
		
	}
	
	TD_View *view = [[self couchDB] viewNamed:[fetchRequest entityName]];
	
	[view setMapBlock:^(NSDictionary *doc, TDMapEmitBlock emit) {
		if(doc && doc[JPCouchIncrementalStoreCDEntityPropertyName])
		{
			if([doc[JPCouchIncrementalStoreCDEntityPropertyName] isEqualToString:[fetchRequest entityName]])
			{
				NSArray *sortDescriptors = [fetchRequest sortDescriptors];
				if(sortDescriptors)
				{
					emit([sortDescriptors valueForKey:@"key"], doc);
				}
			}
		}
	} reduceBlock:NULL version:@"1.0"];
	
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
	NSArray *docs = [rows valueForKeyPath:@"value"];
	NSArray *mappedObjects = [self cachePropertyValuesInDocuments:docs forEntity:[fetchRequest entity] inContext:context];
//	if([fetchRequest predicate])
//	{
//		return [mappedObjects filteredArrayUsingPredicate:[fetchRequest predicate]];
//	}
//	else
//	{
		return mappedObjects;
//	}
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
		
		if(status == kTDStatusConflict)
		{
//			[self handleConflictForManagedObject:insertedObject proposedValues:attributeValues];
		}
		
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
			NSString *documentID = [self referenceObjectForObjectID:[updatedObject objectID]];
			TD_Revision *rev = [[TD_Revision alloc] initWithDocID:documentID revID:previousRevision deleted:NO];
			[rev setBody:[TD_Body bodyWithProperties:attributeValues]];
			TDStatus status;
			TD_Revision* result = [[self couchDB] putRevision: rev prevRevisionID:previousRevision allowConflict: NO status: &status];
			if(status == kTDStatusConflict)
			{
//				[self handleConflictForManagedObject:couchUpdatedObject proposedValues:attributeValues];
			}
			[updatedObject setValue:result.revID forKey:@"revisionID"];
		}

	}
	
	for(NSManagedObject *deletedObject in [saveRequest deletedObjects])
	{
		JPCouchManagedObject *couchDeletedObject = (JPCouchManagedObject *)deletedObject;
		
		if([couchDeletedObject valueForKey:@"revisionID"])
		{
			NSString *previousRevision = [couchDeletedObject valueForKey:@"revisionID"];
			NSString *documentID = [self referenceObjectForObjectID:[couchDeletedObject objectID]];
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
	[attributeValues setObject:[[mo entity] name] forKey:JPCouchIncrementalStoreCDEntityPropertyName];
	NSString *moIdString = [self referenceObjectForObjectID:[mo objectID]];
	[attributeValues setObject:moIdString forKey:@"_id"];
	
	NSDictionary *relationshipDictionary = [[mo entity] relationshipsByName];
	for(id key in [relationshipDictionary allKeys])
	{
		id relationshipValue = nil;
		
		NSRelationshipDescription *relationshipDescription = relationshipDictionary[key];
		
		NSString *relationshipKeyName = [NSString stringWithFormat:JPCouchIncrementalStoreCDRelationshipFormatPropertyName, [relationshipDescription name]];
		
		NSString *keyPath = [NSString stringWithFormat:@"%@.objectID", [relationshipDescription name]];
		
		
		if([relationshipDescription isToMany])
		{
			NSArray *relatedObjectIDs = [mo valueForKeyPath:keyPath];
			
			NSMutableArray *array = [NSMutableArray array];
			for(NSManagedObjectID *moID in relatedObjectIDs)
			{
				[array addObject:[self referenceObjectForObjectID:moID]];
			}
			relationshipValue = array;
		}
		else
		{
			NSManagedObjectID *relatedObjectID = [mo valueForKeyPath:keyPath];
			relationshipValue = [self referenceObjectForObjectID:relatedObjectID];
			
		}
		
		[attributeValues setValue:relationshipValue forKey:relationshipKeyName];
	}
	return attributeValues;
}

static NSDateFormatter *formatter = nil;

static NSDateFormatter * dateFormatter()
{
	if(formatter == nil)
	{
		formatter = [[NSDateFormatter alloc] init];
		[formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
	}
	return formatter;
}

- (NSArray *)cachePropertyValuesInDocuments:(NSArray *)docs forEntity:(NSEntityDescription *)entity inContext:(NSManagedObjectContext *)context
{
	NSMutableArray *objects = [NSMutableArray arrayWithCapacity:[docs count]];
	for(NSDictionary *doc in docs)
	{
		NSString *moIDProperty = doc[@"_id"];
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
			
			if(value == nil  || [value isEqual:[NSNull null]])
			{
				if([attributeDescription defaultValue])
				{
					value = [attributeDescription defaultValue];
				}
				else
				{
					value = [self defaultValueForAttributeType:[attributeDescription attributeType]];
				}
			}
			
			[cachedProperties setValue:value forKey:attributeKey];
		}
		
		NSDictionary *relationshipDictionary = [entity relationshipsByName];
		for(NSString *relationshipName in [relationshipDictionary allKeys])
		{
			NSRelationshipDescription *relationshipDescription = relationshipDictionary[relationshipName];
			NSEntityDescription *destinationEntity = [relationshipDescription destinationEntity];
			
			NSString *relationshipFormattedName = [NSString stringWithFormat:JPCouchIncrementalStoreCDRelationshipFormatPropertyName, relationshipName];
			
			id relationshipValue = nil;
			
			if([relationshipDescription isToMany])
			{
				NSArray *docIDs = doc[relationshipFormattedName];
				relationshipValue = [NSMutableSet set];
				for(NSString *moID in docIDs)
				{
					NSManagedObjectID *objectID = [self newObjectIDForEntity:destinationEntity referenceObject:moID];
					[relationshipValue addObject:objectID];
				}
				
			}
			else
			{
				NSString *docID = doc[relationshipFormattedName];
				relationshipValue = [self newObjectIDForEntity:destinationEntity referenceObject:docID];
			}

			[cachedProperties setValue:relationshipValue forKey:relationshipName];
		}
		[cachedProperties setValue:doc[@"_rev"] forKey:@"revisionID"];
		[[self cachedPropertiesForObjects] setValue:cachedProperties forKey:moIDProperty];
		[objects addObject:object];
	}
	return objects;
}


- (id)defaultValueForAttributeType:(NSAttributeType)attributeType
{
	switch (attributeType) {
		
		case NSDateAttributeType:
			return [NSDate date];
		case NSInteger16AttributeType:
		case NSInteger32AttributeType:
		case NSInteger64AttributeType:
		case NSBooleanAttributeType:
		case NSDecimalAttributeType:
		case NSFloatAttributeType:
		case NSDoubleAttributeType:
			return @0;
		case NSUndefinedAttributeType:
		case NSObjectIDAttributeType:
		case NSTransformableAttributeType:
		case NSStringAttributeType:
		case NSBinaryDataAttributeType:
		default:
			return [NSNull null];
	}
}

#pragma mark - conflicts




@end
