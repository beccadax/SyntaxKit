//
//  ASKSyntaxComponent.m
//  SyntaxKit
//
//  Created by Brent Royal-Gordon on 7/31/13.
//  Copyright (c) 2013 Architechies. All rights reserved.
//

#import "ASKSyntaxComponent.h"
#import "NSArray+Color.h"

@implementation ASKSyntaxComponent

- (id)initWithDefinition:(NSDictionary *)definition {
    if((self = [super init])) {
        _type = definition[@"Type"];
        _name = definition[@"Name"];
        
        _start = definition[@"Start"];
        _end = definition[@"End"];
        _escapeChar = definition[@"EscapeChar"];
        if(definition[@"Charset"]) {
            _charset = [NSCharacterSet characterSetWithCharactersInString:definition[@"Charset"]];
        }
        
        _keywords = definition[@"Keywords"];
        _ignoredComponent = definition[@"IgnoredComponent"];
        _color = [definition[@"Color"] colorValue];
    }
    return self;
}

@end
