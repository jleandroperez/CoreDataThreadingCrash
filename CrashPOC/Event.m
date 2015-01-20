//
//  Event.m
//  CrashPOC
//
//  Created by Jorge Leandro Perez on 1/19/15.
//  Copyright (c) 2015 Lantean. All rights reserved.
//

#import "Event.h"


@implementation Event

@dynamic timeStamp;

- (NSString *)sectionName
{
    return self.timeStamp.description;
}

@end
