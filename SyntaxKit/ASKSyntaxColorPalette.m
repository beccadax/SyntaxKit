//
//  ASKSyntaxColorPalette.m
//  SyntaxKit
//
//  Created by Brent Royal-Gordon on 7/31/13.
//  Copyright (c) 2013 Architechies. All rights reserved.
//

#import "ASKSyntaxColorPalette.h"
#import "ASKSyntaxComponent.h"
#import "NSArray+Color.h"

@implementation ASKSyntaxColorPalette

+ (instancetype)standardColorPalette {
    static ASKSyntaxColorPalette * singleton;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        singleton = [[self alloc] initWithDefinitionURL:[[NSBundle bundleForClass:self] URLForResource:@"SyntaxColorDefaults" withExtension:@"plist"]];
    });
    
    return singleton;
}

- (id)initWithDefinition:(NSDictionary *)definition {
    if(!definition) {
        return nil;
    }
    
    if((self = [super init])) {
        _definition = definition;
    }
    return self;
}

- (id)initWithDefinitionURL:(NSURL *)URL {
    return [self initWithDefinition:[NSDictionary dictionaryWithContentsOfURL:URL]];
}

- (NSString*)keyForSyntaxComponent:(ASKSyntaxComponent*)component {
    return [@"SyntaxColoring:Color:" stringByAppendingString:component.name];
}

- (NSColor *)colorForSyntaxComponent:(ASKSyntaxComponent *)component {
    NSString * key = [self keyForSyntaxComponent:component];
    NSArray * colorParts = self.definition[key];
    
    if(colorParts) {
        return colorParts.colorValue;
    }
    else {
        return component.color;
    }
}

@end
