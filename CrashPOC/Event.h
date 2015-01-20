//
//  Event.h
//  CrashPOC
//
//  Created by Jorge Leandro Perez on 1/19/15.
//  Copyright (c) 2015 Lantean. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Event : NSManagedObject

@property (nonatomic, retain) NSDate * timeStamp;

- (NSString *)sectionName;

@end
