ns_incremental_couch
====================

make an nsincrementalstore that speaks touchdb.


todo
=====

0. ~~Create~~
1. ~~Read~~
2. ~~Update~~
3. ~~Delete~~
4. handle relationships
5. handle data types other than NSDate, NSString, NSNumber

data type
=========

typedef enum {
NSUndefinedAttributeType = 0,
NSInteger16AttributeType = 100,
NSInteger32AttributeType = 200,
NSInteger64AttributeType = 300,
NSDecimalAttributeType = 400,
NSDoubleAttributeType = 500,
NSFloatAttributeType = 600,
NSStringAttributeType = 700,
NSBooleanAttributeType = 800,
NSDateAttributeType = 900,
NSBinaryDataAttributeType = 1000,
NSTransformableAttributeType = 1800,
NSObjectIDAttributeType = 2000
} NSAttributeType;

6. handle replication

