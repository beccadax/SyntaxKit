//
//  ASKSyntax.m
//  SyntaxKit
//
//  Created by Brent Royal-Gordon on 7/25/13.
//  Copyright (c) 2013 Architechies. All rights reserved.
//

#import "ASKSyntax.h"


@implementation ASKSyntax

- (id)initWithDefinition:(NSDictionary *)definition {
    if((self = [super init])) {
        _definition = definition;
    }
    return self;
}

- (id)initWithDefinitionURL:(NSURL *)URL {
    return [self initWithDefinition:[NSDictionary dictionaryWithContentsOfURL:URL]];
}

@end
