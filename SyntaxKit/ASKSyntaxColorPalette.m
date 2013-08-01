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

@interface ASKSyntaxColorPalette ()

@property (strong) NSDictionary * plist;

@end

@implementation ASKSyntaxColorPalette

+ (instancetype)standardColorPalette {
    static ASKSyntaxColorPalette * singleton;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        singleton = [[self alloc] initWithURL:[[NSBundle bundleForClass:self] URLForResource:@"SyntaxColorDefaults" withExtension:@"plist"]];
    });
    
    return singleton;
}

- (id)initWithURL:(NSURL *)URL {
    if((self = [super init])) {
        _plist = [NSDictionary dictionaryWithContentsOfURL:URL];
    }
    return self;
}

- (NSString*)keyForSyntaxComponent:(ASKSyntaxComponent*)component {
    return [@"SyntaxColoring:Color:" stringByAppendingString:component.name];
}

- (NSColor *)colorForSyntaxComponent:(ASKSyntaxComponent *)component {
    NSString * key = [self keyForSyntaxComponent:component];
    NSArray * colorParts = self.plist[key];
    
    if(colorParts) {
        return colorParts.colorValue;
    }
    else {
        return component.color;
    }
}

@end
