//
//  Subevent.h
//  JPCouchCoreData
//
//  Created by Jamie Pinkham on 11/26/12.
//  Copyright (c) 2012 Jamie Pinkham. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <JPCouchIncrementalStore/JPCouchManagedObject.h>

@class Event;

@interface Subevent : JPCouchManagedObject

@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) Event *event;

@end
