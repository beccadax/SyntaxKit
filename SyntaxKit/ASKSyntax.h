//
//  ASKSyntax.h
//  SyntaxKit
//
//  Created by Brent Royal-Gordon on 7/25/13.
//  Copyright (c) 2013 Architechies. All rights reserved.
//

#import <Foundation/Foundation.h>

#define TD_USER_DEFINED_IDENTIFIERS			@"SyntaxColoring:UserIdentifiers"		// Key in user defaults holding user-defined identifiers to colorize.
#define TD_SYNTAX_COLORING_MODE_ATTR		@"UKTextDocumentSyntaxColoringMode"		// Anything we colorize gets this attribute. The value is an NSString holding the component name.

@protocol ASKSyntaxDelegate;

@interface ASKSyntax : NSObject

- (id)initWithDefinition:(NSDictionary*)definition;
- (id)initWithDefinitionURL:(NSURL*)URL;

@property (strong) NSDictionary * definition;
@property (weak) id <ASKSyntaxDelegate> delegate;

@property (assign,getter = isColoring) BOOL coloring;

- (void)colorRange:(NSRange)range ofTextStorage:(NSTextStorage *)textStorage defaultAttributes:(NSDictionary*)defaultTextAttributes;

@end

@protocol ASKSyntaxDelegate <NSObject>

- (void)syntaxWillColor:(ASKSyntax*)syntax;
- (void)syntaxIsColoring:(ASKSyntax*)syntax;
- (void)syntaxDidColor:(ASKSyntax*)syntax;

- (NSArray*)syntax:(ASKSyntax*)syntax userIdentifiersForKeywordComponentName:(NSString*)inModeName;
- (NSDictionary*)syntax:(ASKSyntax*)syntax textAttributesForComponentName:(NSString*)name color:(NSColor*)color;

@end
