//
//  ASKSyntax.m
//  SyntaxKit
//
//  Created by Brent Royal-Gordon on 7/25/13.
//  Copyright (c) 2013 Architechies. All rights reserved.
//

#import "ASKSyntax.h"

@interface ASKSyntax ()

@property (strong) NSDictionary * definition;

@end


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

- (NSArray *)components {
    return self.definition[@"Components"];
}

- (NSString *)oneLineCommentPrefix {
    return self.definition[@"OneLineCommentSuffix"];
}

- (NSArray *)fileNameSuffixes {
    return self.definition[@"FileNameSuffixes"];
}

@end
