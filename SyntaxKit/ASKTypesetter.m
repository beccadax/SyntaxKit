//
//  ASKTypesetter.m
//  Architechies SyntaxKit
//
//  Created by Brent Royal-Gordon on 7/23/13.
//  Copyright (c) 2013 Architechies. All rights reserved.
//

#import "ASKTypesetter.h"

const CGFloat kExtraCharactersIndented = 4;

@implementation ASKTypesetter

- (void)getLineFragmentRect:(NSRectPointer)lineFragmentRect usedRect:(NSRectPointer)lineFragmentUsedRect remainingRect:(NSRectPointer)remainingRect forStartingGlyphAtIndex:(NSUInteger)startingGlyphIndex proposedRect:(NSRect)proposedRect lineSpacing:(CGFloat)lineSpacing paragraphSpacingBefore:(CGFloat)paragraphSpacingBefore paragraphSpacingAfter:(CGFloat)paragraphSpacingAfter {
    if(self.paragraphGlyphRange.location != startingGlyphIndex) {
        if(NSMinX(proposedRect) == 0) {
            // We are laying out the first character of a line, but not the first line of the paragraph.
            NSRange indentationGlyphRange = [self rangeOfWhitespaceGlyphsAtBeginningOfParagraph];
            
            if (indentationGlyphRange.length + kExtraCharactersIndented <= self.paragraphGlyphRange.length) {
                indentationGlyphRange.length += kExtraCharactersIndented;
            }
            
            CGFloat width = [self.layoutManager locationForGlyphAtIndex:NSMaxRange(indentationGlyphRange)].x - self.currentTextContainer.lineFragmentPadding;
            proposedRect.origin.x += width;
        }
    }
    
    [super getLineFragmentRect:lineFragmentRect usedRect:lineFragmentUsedRect remainingRect:remainingRect forStartingGlyphAtIndex:startingGlyphIndex proposedRect:proposedRect lineSpacing:lineSpacing paragraphSpacingBefore:paragraphSpacingBefore paragraphSpacingAfter:paragraphSpacingAfter];
}

- (NSRange)rangeOfWhitespaceGlyphsAtBeginningOfParagraph {
    NSRange paragraphCharacterRange = self.paragraphCharacterRange;
    
    NSRange firstNonSpace = [self.attributedString.string rangeOfCharacterFromSet:[NSCharacterSet.whitespaceCharacterSet invertedSet] options:0 range:paragraphCharacterRange];
    if(firstNonSpace.location == NSNotFound) {
        return self.paragraphGlyphRange;
    }
    
    NSRange spacesRange = NSMakeRange(paragraphCharacterRange.location, firstNonSpace.location - paragraphCharacterRange.location);
    return [self glyphRangeForCharacterRange:spacesRange actualCharacterRange:NULL];
}

@end
