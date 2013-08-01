//
//  ASKSyntax.m
//  SyntaxKit
//
//  Created by Brent Royal-Gordon on 7/25/13.
//  Copyright (c) 2013 Architechies. All rights reserved.
//

#import "ASKSyntax.h"
#import "ASKSyntaxMarker.h"

NSString * const ASKSyntaxComponentAttributeName = @"ASKSyntaxMode";

@interface ASKSyntax ()

@end

@implementation ASKSyntax

- (id)initWithDefinition:(NSDictionary *)definition {
    if((self = [super init])) {
        _oneLineCommentPrefix = definition[@"OneLineCommentPrefix"];
        _fileNameSuffixes = definition[@"FileNameSuffixes"];
        
        NSMutableArray * components = [NSMutableArray new];
        for(NSDictionary * def in definition[@"Components"]) {
            [components addObject:[[ASKSyntaxComponent alloc] initWithDefinition:def]];
        }
        _components = components;
        
        _marker = [ASKSyntaxMarker new];
        _marker.syntax = self;
    }
    return self;
}

- (id)initWithDefinitionURL:(NSURL *)URL {
    return [self initWithDefinition:[NSDictionary dictionaryWithContentsOfURL:URL]];
}

@end
