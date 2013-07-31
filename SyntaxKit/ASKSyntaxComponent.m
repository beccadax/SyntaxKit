//
//  ASKSyntaxComponent.m
//  SyntaxKit
//
//  Created by Brent Royal-Gordon on 7/31/13.
//  Copyright (c) 2013 Architechies. All rights reserved.
//

#import "ASKSyntaxComponent.h"

@implementation ASKSyntaxComponent

- (id)initWithDefinition:(NSDictionary *)definition {
    if((self = [super init])) {
        _definition = definition;
    }
    return self;
}

@end
