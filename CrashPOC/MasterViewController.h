//
//  MasterViewController.h
//  CrashPOC
//
//  Created by Jorge Leandro Perez on 1/19/15.
//  Copyright (c) 2015 Lantean. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface MasterViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (strong, nonatomic) NSFetchedResultsController    *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext        *writerObjectContext;
@property (strong, nonatomic) NSManagedObjectContext        *managedObjectContext;
@property (strong, nonatomic) NSManagedObjectContext        *backgroundContext;

@end
