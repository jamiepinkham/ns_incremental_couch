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

@interface Event : JPCouchManagedObject

@property (nonatomic) NSTimeInterval timeStamp;
@property (nonatomic) BOOL active;

@end
