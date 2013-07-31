//
//  NSTextView+SyntaxKit.m
//  SyntaxKit
//
//  Created by Brent Royal-Gordon on 7/24/13.
//  Copyright (c) 2013 Architechies. All rights reserved.
//

#import "NSTextView+SyntaxKit.h"

const ASKLocation ASKLocationZero = { .line = 0, .character = 0 };

@implementation NSTextView (SyntaxKit)

- (ASKLocation)locationOfCharacterAtIndex:(NSUInteger)index {
    ASKLocation location = ASKLocationZero;
    
    NSUInteger lastLineStart = 0, lastBreakOffs = 0;
    unichar lastBreakChar = 0;
    
    for(NSUInteger i = 0; (i < index) && (i < self.string.length); i++) {
		unichar		theCh = [self.string characterAtIndex: i];
		switch( theCh )
		{
			case '\n':
				if( lastBreakOffs == (i-1) && lastBreakChar == '\r' )   // LF in CRLF sequence? Treat this as a single line break.
				{
					lastBreakOffs = 0;
					lastBreakChar = 0;
					continue;
				}
				// Else fall through!
				
			case '\r':
                location.line++;
				lastLineStart = i + 1;
				lastBreakOffs = i;
				lastBreakChar = theCh;
				break;
		}
	}
    
    location.character = (index - lastLineStart);
    
    return location;
}

- (ASKLocation)locationOfBeginningOfSelection {
    return [self locationOfCharacterAtIndex:self.selectedRange.location];
}

- (ASKLocation)locationOfEndOfSelection {
    return [self locationOfCharacterAtIndex:NSMaxRange(self.selectedRange)];
}

@end
