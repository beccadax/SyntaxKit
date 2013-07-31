//
//  ASKSyntaxColorist.h
//  SyntaxKit
//
//  Created by Brent Royal-Gordon on 7/31/13.
//  Copyright (c) 2013 Architechies. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ASKSyntax;
@protocol ASKSyntaxColoristDelegate;

@interface ASKSyntaxColorist : NSObject

@property (weak) id <ASKSyntaxColoristDelegate> delegate;

@property (assign,getter = isColoring) BOOL coloring;

- (void)colorRange:(NSRange)range ofTextStorage:(NSTextStorage *)textStorage withSyntax:(ASKSyntax*)syntax defaultAttributes:(NSDictionary*)defaultTextAttributes;

@end

@protocol ASKSyntaxColoristDelegate <NSObject>

- (void)syntaxColoristWillColor:(ASKSyntaxColorist*)syntaxColorist;
- (void)syntaxColoristIsColoring:(ASKSyntaxColorist*)syntaxColorist;
- (void)syntaxColoristDidColor:(ASKSyntaxColorist*)syntaxColorist;

- (NSArray*)syntaxColorist:(ASKSyntaxColorist*)syntaxColorist userIdentifiersForKeywordComponentName:(NSString*)inModeName;
- (NSDictionary*)syntaxColorist:(ASKSyntaxColorist*)syntaxColorist textAttributesForComponentName:(NSString*)name color:(NSColor*)color;

@end
