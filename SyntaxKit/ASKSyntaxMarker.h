//
//  ASKSyntaxMarker.h
//  SyntaxKit
//
//  Created by Uli Kusterer on 13.03.10.
//  UKSyntaxColoredTextViewController Copyright 2010 Uli Kusterer.
//  SyntaxKit Copyright (c) 2013 Architechies. All rights reserved.
//
//	This software is provided 'as-is', without any express or implied
//	warranty. In no event will the authors be held liable for any damages
//	arising from the use of this software.
//
//	Permission is granted to anyone to use this software for any purpose,
//	including commercial applications, and to alter it and redistribute it
//	freely, subject to the following restrictions:
//
//	   1. The origin of this software must not be misrepresented; you must not
//	   claim that you wrote the original software. If you use this software
//	   in a product, an acknowledgment in the product documentation would be
//	   appreciated but is not required.
//
//	   2. Altered source versions must be plainly marked as such, and must not be
//	   misrepresented as being the original software.
//
//	   3. This notice may not be removed or altered from any source
//	   distribution.
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