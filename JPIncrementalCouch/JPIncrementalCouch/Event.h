//
//  Event.h
//  JPCouchCoreData
//
//  Created by Jamie Pinkham on 11/26/12.
//  Copyright (c) 2012 Jamie Pinkham. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <JPCouchIncrementalStore/JPCouchManagedObject.h>

@class Subevent;

@interface Event : JPCouchManagedObject

@property (nonatomic, retain) NSNumber * active;
@property (nonatomic, retain) NSDate * timeStamp;
@property (nonatomic, retain) NSSet *events;
@end

@interface Event (CoreDataGeneratedAccessors)

- (void)addEventsObject:(Subevent *)value;
- (void)removeEventsObject:(Subevent *)value;
- (void)addEvents:(NSSet *)values;
- (void)removeEvents:(NSSet *)values;

@end
