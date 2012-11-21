//
//  NSManagedObject+JPCouchIncrementalStoreRev.h
//  JPCouchIncrementalStore
//
//  Created by Jamie Pinkham on 11/15/12.
//  Copyright (c) 2012 Jamie Pinkham. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface NSManagedObject (JPCouchIncrementalStoreRev)

@property (nonatomic, copy) NSString *jp_couchRev;

@end
