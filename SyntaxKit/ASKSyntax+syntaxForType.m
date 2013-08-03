//
//  ASKSyntax+GSTType.m
//  Ingist
//
//  Created by Brent Royal-Gordon on 7/25/13.
//  Copyright (c) 2013 Architechies. All rights reserved.
//

#import "ASKSyntax+syntaxForType.h"
#import <ArchDirectoryObserver/ArchDirectoryObserver.h>

NSString * const ASKSyntaxWillInvalidateSyntaxesNotification = @"ASKSyntaxWillInvalidateSyntaxes";
NSString * const ASKSyntaxDidInvalidateSyntaxesNotification = @"ASKSyntaxDidInvalidateSyntaxes";

static NSMutableDictionary * Syntaxes = nil;

@interface ASKUserSyntaxDirectoryObserver : NSObject <ArchDirectoryObserver>

@end

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
    
    NSDirectoryEnumerator * contents = [[NSFileManager new] enumeratorAtURL:URL includingPropertiesForKeys:@[ ] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:NULL];
    
    for(NSURL * syntaxURL in contents) {
        NSString * type;
        if(![syntaxURL getResourceValue:&type forKey:NSURLTypeIdentifierKey error:NULL]) {
            continue;
        }
        if(!UTTypeConformsTo((__bridge CFStringRef)type, CFSTR("com.architechies.frameworks.SyntaxKit.syntaxDefinition"))) {
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
        static ASKUserSyntaxDirectoryObserver * observer;
        static dispatch_once_t once;
        
        dispatch_once(&once, ^{
            observer = [ASKUserSyntaxDirectoryObserver new];
            
            NSAssert(UTTypeConformsTo(CFSTR("com.architechies.frameworks.SyntaxKit.syntaxDefinition"), CFSTR("com.apple.property-list")), @"The syntaxDefinition UTI hasn't been registered! Have you copied SyntaxKit-Info.plist's UTExportedTypeDeclarations to your app?");
        });
        
        Syntaxes = [NSMutableDictionary new];
        [self loadSyntaxesFromURL:[self userSyntaxesURL]];
        [self loadSyntaxesFromURL:[self mainBundleSyntaxesURL]];
        [self loadSyntaxesFromURL:[self kitBundleSyntaxesURL]];
    }
    
    return Syntaxes[type];
}

@end

@implementation ASKUserSyntaxDirectoryObserver

- (id)init {
    if((self = [super init])) {
        [[ASKSyntax userSyntaxesURL] addDirectoryObserver:self options:ArchDirectoryObserverResponsive resumeToken:nil];
    }
    return self;
}

- (void)dealloc {
    [[ASKSyntax userSyntaxesURL] removeDirectoryObserver:self];
}

- (void)observedDirectory:(NSURL *)observedURL ancestorAtURLDidChange:(NSURL *)changedURL historical:(BOOL)historical resumeToken:(ArchDirectoryObservationResumeToken)resumeToken {
    if(!historical) {
        [ASKSyntax invalidateSyntaxes];
    }
}

- (void)observedDirectory:(NSURL *)observedURL childrenAtURLDidChange:(NSURL *)changedURL historical:(BOOL)historical resumeToken:(ArchDirectoryObservationResumeToken)resumeToken {
    if(!historical) {
        [ASKSyntax invalidateSyntaxes];
    }
}

- (void)observedDirectory:(NSURL *)observedURL descendantsAtURLDidChange:(NSURL *)changedURL reason:(ArchDirectoryObserverDescendantReason)reason historical:(BOOL)historical resumeToken:(ArchDirectoryObservationResumeToken)resumeToken {
    if(!historical) {
        [ASKSyntax invalidateSyntaxes];
    }
}

@end
