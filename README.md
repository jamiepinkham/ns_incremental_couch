ns_incremental_couch
====================

make an nsincrementalstore that speaks touchdb.

notes
======

Hey Jens,

Awesome!  Thanks for the quick and thoughtful response.  I've included some clarifications & expansions to some of the stuff I've mentioned below.


Here are the current things, in no particular order, that I see as questions about it's possibility.

1. CouchDB documents include a hidden _rev property that is required for updates, so couch can vet if you are trying to update an older version of the document.  The idea here is to not bubble up implementation details and stuff this _rev as an associated object that is attached to every NSManagedObject that comes out of this NSIncrementalStore.

A lot of stuff has to stay the same just to support the CouchDB replication protocol. Certainly the entire SQL schema TouchDB uses. The part that isn't necessary is what I call the "router" layer, which implements the CouchDB REST API through a custom NSURLProtocol. This is pretty separable; and in fact in some post-1.0 stuff I'm working on in a branch, it becomes entirely separable and you can build TouchDB without it.


Would definitely like to more info on this, since we'll be accessing couch strictly through core data, no touchdb:// here. 

This in itself sounds straightforward, but it leads to the bigger issue of conflicts. If you cache the _rev property you can ensure no conflicts if it's only the IncrementalStore accessing the database; but if the replicator pulls any revisions from upstream you'll have to start dealing with them somehow. Since CoreData doesn't have a notion of conflicts (I don't think?) I'm not sure how you present this to the developer.

I think the general idea is to have this incremental store handle push/pull synchronization itself.  The default initializer, along with taking the location of the canonical store, can also take a parameter for sync interval.  The incremental store would handle push/pull.  Although, to be fair, I haven't really thought all the way through how I would pass back conflicts when it happens in a scheduled incremental store sync.. :/  Maybe a notification?

Rob's idea is to have the default policy be "the canonical store always wins", with an option to provide the store with a delegate and optional delegate methods to handle conflict resolution.

Obviously we need to apply some more brain power to that problem.  :)


2.  CouchDB does not have a strict idea of "relationships", relationships would have to be managed via properties in the document that are references to the _id of another document.  (NBD, there).

Right; this is a common idiom already. Although since NoSQL documents aren't as fully factored as relational schema, one often stores small collections inline as arrays in a document instead of making each item a separate row that requires a relation back to its owner. (This also has implications for replication: storing a collection in a single document ensures it's updated atomically, but can mean it's more prone to doc conflicts if two clients modify it.)

Small?  Meaning how many?  Should this be something that's watched and tuned, or is it something that there's a standard practice on?  I think the general goal should be to avoid conflicts as much as possible, because it's a mechanism that isn't readily "plugged-in" to the core data stack.


3.  Queries in CouchDB are map/reduce functions and CouchDB caches them with a given name.  The goal is to come up with a clever way to create a unique name for a query given an instance of NSFetchRequest.  Not sure how to do this just yet.

Yeah. You might want to look at Ektorp, a Java CouchDB API, which I believe has some support for doing this. Their design might be interesting.

Will do.  Thanks.  I think this is one of those problems that seems relatively straightforward, but can get hairy, especially for the different fetch types core data supports.. there are tons of permutations in a possible fetch request.

4. Syncing to a canonical central store can be accomplished by passing configuration information to -[NSPersistentStoreCoordinator addPersistentStoreWithType:configuration:options:], the default initializer of NSPersistentStore (of which, NSIncrementalStore is a subclass) is - [NSPersistentStore initWithPersistentStoreCoordinator:configurationName:URL:options:] (thank you, Jury)

5. CouchDB creates a GUID for each document in it's store, these will be used in - (NSArray*)obtainPermanentIDsForObjects:(NSArray*)array error:(NSError **)error;

6.  Lastly, to actually use this in practice would require a lot of dependancies (CocoaHTTPServer, MYUtilities [not sure if this one is completely necessary, I think it's used in writing some of the map/reduce functions], FMDB [TouchDB creates a local cache using a sqlite store], and OAuthConsumer).  

CocoaHTTPServer is only needed for the TouchDBListener library, i.e. only if you want to actually accept connections over HTTP, not for basic usage. MYUtilities is used all over the place. FMDB is of course required. OAuthConsumer is only used by some code that supports OAuth authentication to CouchDB and is probably pretty easy to remove if you don't need that.

I think we'll want to also support peer-to-peer synchronization, and of course we'll need to support talking to a "real" CouchDB.  :)  So, it looks like everything stays for now.