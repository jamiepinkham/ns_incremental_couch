//
//  JPCouchManagedObject.h
//  JPCouchIncrementalStore
//
//  Created by Jamie Pinkham on 11/23/12.
//  Copyright (c) 2012 Jamie Pinkham. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface JPCouchManagedObject : NSManagedObject

//@property (nonatomic, copy) NSString *documentID;
@property (nonatomic, copy) NSString *revisionID;

@end
