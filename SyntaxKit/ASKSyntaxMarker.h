//
//  ASKSyntaxMarker.h
//  SyntaxKit
//
//  Created by Brent Royal-Gordon on 7/31/13.
//  Copyright (c) 2013 Architechies. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const ASKSyntaxModeAttributeName;

@class ASKSyntax;
@protocol ASKSyntaxMarkerDelegate;

@interface ASKSyntaxMarker : NSObject

@property (weak) id <ASKSyntaxMarkerDelegate> delegate;

- (void)markRange:(NSRange)range ofAttributedString:(NSMutableAttributedString*)string withSyntax:(ASKSyntax*)syntax;

@end

@protocol ASKSyntaxMarkerDelegate <NSObject>

- (void)syntaxMarkerIsMarking:(ASKSyntaxMarker*)marker;
- (NSArray*)syntaxMarker:(ASKSyntaxMarker*)marker userIdentifiersForKeywordMode:(NSString*)name;

@end