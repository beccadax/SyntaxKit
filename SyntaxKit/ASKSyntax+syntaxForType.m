//
//  ASKSyntax+GSTType.m
//  Ingist
//
//  Created by Brent Royal-Gordon on 7/25/13.
//  Copyright (c) 2013 Architechies. All rights reserved.
//

#import "ASKSyntax+syntaxForType.h"

NSString * const ASKSyntaxWillInvalidateSyntaxesNotification = @"ASKSyntaxWillInvalidateSyntaxes";
NSString * const ASKSyntaxDidInvalidateSyntaxesNotification = @"ASKSyntaxDidInvalidateSyntaxes";

static NSMutableDictionary * Syntaxes = nil;

@implementation ASKSyntax (syntaxForType)

+ (void)invalidateSyntaxes {
    [NSNotificationCenter.defaultCenter postNotificationName:ASKSyntaxWillInvalidateSyntaxesNotification object:self];
    Syntaxes = nil;
    [NSNotificationCenter.defaultCenter postNotificationName:ASKSyntaxDidInvalidateSyntaxesNotification object:self];
}

+ (NSURL *)userSyntaxesURL {
    NSURL * appSupportURL = [[NSFileManager new] URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
    return [appSupportURL URLByAppendingPathComponent:@"Syntax Definitions"];
    
}

+ (NSURL *)mainBundleSyntaxesURL {
    return [[NSBundle mainBundle] URLForResource:@"Syntax Definitions" withExtension:nil];    
}

+ (NSURL *)kitBundleSyntaxesURL {
    return [[NSBundle bundleForClass:self] URLForResource:@"Syntax Definitions" withExtension:nil];
}

+ (void)loadSyntaxesFromURL:(NSURL*)URL {
    if(!URL) {
        return;
    }
    
    NSDirectoryEnumerator * contents = [[NSFileManager new] enumeratorAtURL:URL includingPropertiesForKeys:@[ NSURLTypeIdentifierKey ] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:NULL];
    
    for(NSURL * syntaxURL in contents) {
        NSString * type;
        if(![syntaxURL getResourceValue:&type forKey:NSURLTypeIdentifierKey error:NULL]) {
            continue;
        }
        if(!UTTypeConformsTo((__bridge CFStringRef)type, CFSTR("com.apple.property-list"))) {
            continue;
        }
        
        ASKSyntax * syntax = [[ASKSyntax alloc] initWithDefinitionURL:syntaxURL];
        
        for(NSString * sourceType in syntax.preferredUTIs) {
            if(Syntaxes[sourceType]) {
                // Another syntax is at least compatible with this UTI...
                ASKSyntax * otherSyntax = Syntaxes[sourceType];
                if([otherSyntax.preferredUTIs containsObject:sourceType]) {
                    // Actually, it's preferred too.
                    continue;
                }
            }
            Syntaxes[sourceType] = syntax;
        }
        for(NSString * sourceType in syntax.compatibleUTIs) {
            if(Syntaxes[sourceType]) {
                // Another syntax is already compatible with this UTI
                continue;
            }
            Syntaxes[sourceType] = syntax;
        }
    }
}

+ (instancetype)syntaxForType:(NSString*)type {
    if(!Syntaxes) {
        Syntaxes = [NSMutableDictionary new];
        [self loadSyntaxesFromURL:[self userSyntaxesURL]];
        [self loadSyntaxesFromURL:[self mainBundleSyntaxesURL]];
        [self loadSyntaxesFromURL:[self kitBundleSyntaxesURL]];
    }
    
    return Syntaxes[type];
}

@end
