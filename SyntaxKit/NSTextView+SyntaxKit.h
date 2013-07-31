//
//  NSTextView+SyntaxKit.h
//  SyntaxKit
//
//  Created by Brent Royal-Gordon on 7/24/13.
//  Copyright (c) 2013 Architechies. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef struct {
    NSUInteger line;
    NSUInteger character;
} ASKLocation;

extern const ASKLocation ASKLocationZero;

@interface NSTextView (SyntaxKit)

- (ASKLocation)locationOfCharacterAtIndex:(NSUInteger)index;

@property (readonly) ASKLocation locationOfBeginningOfSelection;
@property (readonly) ASKLocation locationOfEndOfSelection;

@end
