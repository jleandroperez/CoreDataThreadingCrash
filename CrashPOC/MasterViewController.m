//
//  MasterViewController.m
//  CrashPOC
//
//  Created by Jorge Leandro Perez on 1/19/15.
//  Copyright (c) 2015 Lantean. All rights reserved.
//

#import "MasterViewController.h"
#import "Event.h"


#define USE_NESTED_CONTEXTS false


@interface MasterViewController ()

@end

@implementation MasterViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIBarButtonItem *addButton                      = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(insertNewObject:)];
    self.navigationItem.rightBarButtonItem          = addButton;
    
    NSManagedObjectContext *backgroundContext       = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    
#if USE_NESTED_CONTEXTS
    backgroundContext.parentContext                 = self.writerObjectContext;
#else
    backgroundContext.persistentStoreCoordinator    = self.managedObjectContext.persistentStoreCoordinator;
#endif
    
    self.backgroundContext                          = backgroundContext;

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(backgroundContextWillSave:) name:NSManagedObjectContextWillSaveNotification object:self.backgroundContext];
    [nc addObserver:self selector:@selector(backgroundContextDidSave:) name:NSManagedObjectContextDidSaveNotification object:self.backgroundContext];
}

- (void)backgroundContextWillSave:(NSNotification *)note
{
    NSLog(@">> %@", NSStringFromSelector(_cmd));
    
    NSManagedObjectContext *workerContext = (NSManagedObjectContext *)note.object;

    // Load the deleted object id's
    NSMutableSet *workerDeletedIds = [NSMutableSet set];
    for (NSManagedObject *object in workerContext.deletedObjects) {
        [workerDeletedIds addObject:object.objectID];
    }
    
    if (workerDeletedIds.count == 0) {
        return;
    }
    
    // Remove the objects from the mainContext
    [self.writerObjectContext performBlockAndWait:^{
        for (NSManagedObjectID *objectID in workerDeletedIds) {
            NSManagedObject *writerMO = [self.writerObjectContext existingObjectWithID:objectID error:nil];
            [self.writerObjectContext refreshObject:writerMO mergeChanges:false];
            if (writerMO.isFault) {
                [writerMO willAccessValueForKey:nil];
            }
        }
    }];
}

- (void)backgroundContextDidSave:(NSNotification *)note
{
    NSLog(@">> %@", NSStringFromSelector(_cmd));

    [self.writerObjectContext performBlockAndWait:^{
        [self.writerObjectContext mergeChangesFromContextDidSaveNotification:note];
    }];
    
    [self.managedObjectContext performBlockAndWait:^{
        [self.managedObjectContext mergeChangesFromContextDidSaveNotification:note];
    }];
}

- (void)insertNewObject:(id)sender
{
    // 1. Insert
    NSManagedObjectContext *context                 = self.managedObjectContext;
    
    NSEntityDescription *entity                     = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:context];
    Event *newManagedObject                         = [NSEntityDescription insertNewObjectForEntityForName:entity.name inManagedObjectContext:context];
    
    newManagedObject.timeStamp                      = [NSDate date];
    
    [context obtainPermanentIDsForObjects:@[newManagedObject] error:nil];
    
    NSLog(@"[Inserting]");
    [context save:nil];
    
    [self.writerObjectContext performBlockAndWait:^{
        [self.writerObjectContext save:nil];
    }];
    
    // 2. Fetch
    [self.fetchedResultsController performFetch:nil];

    // 3. Fault the object
    [self.managedObjectContext refreshObject:newManagedObject mergeChanges:false];
    
    // 4. Delete in BackgroundMOC
    NSLog(@"[BeforeDelete] Fault: %d Deleted: %d", newManagedObject.isFault, newManagedObject.isDeleted);
    
    [self.backgroundContext performBlockAndWait:^{
        NSManagedObject *backgroundObject = [self.backgroundContext objectWithID:newManagedObject.objectID];
        
        [self.backgroundContext deleteObject:backgroundObject];
        [self.backgroundContext save:nil];
    }];

    NSLog(@"[AfterDelete] Fault: %d Deleted: %d", newManagedObject.isFault, newManagedObject.isDeleted);
    
    // 5. Crash
    NSLog(@"[Faulting] Timestamp: %@", newManagedObject.timeStamp);
    NSLog(@"[Faulted] Fault: %d Deleted: %d", newManagedObject.isFault, newManagedObject.isDeleted);
}


#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo    = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo    = [self.fetchedResultsController sections][section];
    return sectionInfo.name;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    Event *object                                   = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text                             = object.timeStamp.description;
}

#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest                    = [[NSFetchRequest alloc] init];
    fetchRequest.entity                             = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:self.managedObjectContext];
    fetchRequest.fetchBatchSize                     = 20;
    NSLog(@"Default %d", fetchRequest.returnsObjectsAsFaults);
    
    NSSortDescriptor *sortDescriptor                = [[NSSortDescriptor alloc] initWithKey:@"timeStamp" ascending:NO];
    
    fetchRequest.sortDescriptors                    = @[sortDescriptor];

    NSFetchedResultsController *frc                 = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:@"sectionName" cacheName:nil];
    frc.delegate                                    = self;
    self.fetchedResultsController                   = frc;

	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error]) {
	    NSLog(@"Unresolved error %@, %@", error, error.userInfo);
	    abort();
	}
    
    return _fetchedResultsController;
}    

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        default:
            return;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

@end
