//
//  ASKSyntax.h
//  SyntaxKit
//
//  Created by Brent Royal-Gordon on 7/25/13.
//  Copyright (c) 2013 Architechies. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ASKSyntaxComponent.h"

@protocol ASKSyntaxMarker;

@interface ASKSyntax : NSObject

- (id)initWithDefinition:(NSDictionary*)definition;
- (id)initWithDefinitionURL:(NSURL*)URL;

// A syntax marker is used to annotate an NSAttributedString with ASKSyntaxComponentAttributeName attributes. 
// Each attribute points to an ASKSyntaxComponent for the item in question.
@property (strong) id <ASKSyntaxMarker> marker;

@property (readonly) NSArray * components;
@property (readonly) NSString * oneLineCommentPrefix;
@property (readonly) NSSet * preferredUTIs;
@property (readonly) NSSet * compatibleUTIs;

@end

extern NSString * const ASKSyntaxComponentAttributeName;

@protocol ASKSyntaxMarker <NSObject>

@property (weak) ASKSyntax * syntax;

- (void)markRange:(NSRange)range ofAttributedString:(NSMutableAttributedString*)string withUserIdentifiers:(NSArray*)userIdentifiers;

@end
