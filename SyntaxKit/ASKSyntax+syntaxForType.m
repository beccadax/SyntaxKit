//
//  ASKSyntax+GSTType.m
//  Ingist
//
//  Created by Brent Royal-Gordon on 7/25/13.
//  Copyright (c) 2013 Architechies. All rights reserved.
//

#import "ASKSyntax+syntaxForType.h"

@implementation ASKSyntax (syntaxForType)

+ (NSURL*)URLForSyntaxDefinitionNamed:(NSString*)name {
    return [[NSBundle bundleForClass:self] URLForResource:name withExtension:@"plist" subdirectory:@"Syntax Definitions"];
}

+ (NSDictionary*)syntaxDefinitionFileNames {
    static NSDictionary * singleton;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        singleton = [NSDictionary dictionaryWithContentsOfURL:[self URLForSyntaxDefinitionNamed:@"types"]];
    });
    
    return singleton;
}

+ (instancetype)syntaxForType:(NSString*)type {
    static NSMutableDictionary * syntaxes;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        syntaxes = [NSMutableDictionary new];
    });
    
    NSString * fileName = self.class.syntaxDefinitionFileNames[type];
    if(!fileName) {
        return nil;
    }
    
    ASKSyntax * syntax = syntaxes[fileName];
    if(!syntax) {
        NSURL * defintionURL = [self URLForSyntaxDefinitionNamed:fileName];
        syntax = [[self alloc] initWithDefinitionURL:defintionURL];
        syntaxes[fileName] = syntax;
    }
    
    return syntax;
}

@end
