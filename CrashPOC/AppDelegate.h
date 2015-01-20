//
//  AppDelegate.h
//  CrashPOC
//
//  Created by Jorge Leandro Perez on 1/19/15.
//  Copyright (c) 2015 Lantean. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>


@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (readwrite, strong, nonatomic) UIWindow                       *window;
@property (readonly,  strong, nonatomic) NSManagedObjectContext         *writerObjectContext;
@property (readonly,  strong, nonatomic) NSManagedObjectContext         *managedObjectContext;
@property (readonly,  strong, nonatomic) NSManagedObjectModel           *managedObjectModel;
@property (readonly,  strong, nonatomic) NSPersistentStoreCoordinator   *persistentStoreCoordinator;

- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;

@end
