//
//  ASKSyntaxComponent+Marking.m
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

#import "ASKSyntaxComponent+Marking.h"
#import "NSScanner+SkipUpToCharset.h"

@implementation ASKSyntaxComponent (Marking)

- (void)marker:(ASKSyntaxMarker *)marker markInString:(NSMutableAttributedString *)string withUserIdentifiers:(NSArray *)userIdentifiers {
    @try {
        if([self.type isEqualToString:@"BlockComment"]) {
            [self marker:marker markCommentsInString:string];
        }
        else if([self.type isEqualToString:@"OneLineComment"]) {
            [self marker:marker markOneLineCommentInString:string];
        }
        else if([self.type isEqualToString:@"String"]) {
            [self marker:marker markStringsInString:string]; 
        }
        else if([self.type isEqualToString:@"Tag"]) {
            [self marker:marker markTagInString:string];
        }
        else if([self.type isEqualToString:@"Keywords"]) {
            NSArray* identifiers = self.keywords ?: userIdentifiers;
            
            for(NSString * identifier in identifiers) {
                [self marker:marker markIdentifier:identifier inString:string];
            }
        }
    }
    @catch (NSException *exception) {
        // We don't really care that much about these, but let's at least indicate they happened.
        NSLog(@"Exception while marking component of type '%@' named '%@': %@", self.type, self.name, exception);
    }
}

-(NSDictionary*)textAttributes {
	return @{ ASKSyntaxComponentAttributeName: self };
}

- (void)marker:(ASKSyntaxMarker*)marker markStringsInString:(NSMutableAttributedString*)string {
    NSScanner * scanner = [NSScanner scannerWithString:string.string];
    NSDictionary * newAttributes = [self textAttributes];
    BOOL isEndChar = NO;
    
    unichar escapeChar = self.escapeChar.length ? [self.escapeChar characterAtIndex:0] : '\\';
    
    while(!scanner.isAtEnd) {
        isEndChar = NO;
        
        // Look for start of string:
        [scanner scanUpToString:self.start intoString:NULL];
        NSUInteger startOffset = scanner.scanLocation;
        if(![scanner scanString:self.start intoString:NULL]) {
            return;
        }
        
        // Until we reach an end character or the end of the string...
        while(!isEndChar && !scanner.isAtEnd) {
            [scanner scanUpToString:self.end intoString:NULL];
            
            // Look behind. Is there an escape character?
            // "scanner.scanLocation - 1" is safe because we must have already scanned self.start in.
            // XXX We really want to check if there's an *odd* number of escape characters.
            if(self.escapeChar.length == 0 || [string.string characterAtIndex:(scanner.scanLocation - 1)] != escapeChar) {
                // No! Terminate the loop.
                isEndChar = YES;
            }
            
            // Consume the terminator.
            if(![scanner scanString:self.end intoString:NULL]) {
                return;
            }
        }
        
        NSUInteger endOffset = scanner.scanLocation;
        
        [string addAttributes:newAttributes range:NSMakeRange(startOffset, endOffset - startOffset)];
    }
}

- (void)marker:(ASKSyntaxMarker*)marker markCommentsInString:(NSMutableAttributedString*)string {
    NSScanner * scanner = [NSScanner scannerWithString:string.string];
    NSDictionary * newAttributes = [self textAttributes];
    
    while(!scanner.isAtEnd) {
        // Look for start of multi-line comment:
        [scanner scanUpToString:self.start intoString:NULL];
        NSUInteger startOffset = scanner.scanLocation;
        if(![scanner scanString:self.start intoString:NULL]) {
            return;
        }
        
        // Look for associated end-of-comment marker:
        [scanner scanUpToString:self.end intoString:NULL];
        if(![scanner scanString:self.end intoString:NULL]) {
            // Don't exit. If user forgot trailing marker, indicate this by "bleeding" until end of string.
            /* return; */  
        }
        NSUInteger endOffset = scanner.scanLocation;
        
        [string addAttributes:newAttributes range:NSMakeRange(startOffset, endOffset - startOffset)];
    }
}


- (void)marker:(ASKSyntaxMarker*)marker markOneLineCommentInString:(NSMutableAttributedString*)string {
    NSScanner * scanner = [NSScanner scannerWithString:string.string];
    NSDictionary * newAttributes = [self textAttributes];
    
    while(!scanner.isAtEnd) {
        // Look for start of one-line comment:
        [scanner scanUpToString:self.start intoString:NULL];
        NSUInteger startOffset = scanner.scanLocation;
        if(![scanner scanString:self.start intoString:NULL]) {
            return;
        }
        
        // Look for associated line break:
        if(![scanner skipUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\n\r"]]) {
            /* return; */
        }
        NSUInteger endOffset = scanner.scanLocation;
        
        [string addAttributes:newAttributes range:NSMakeRange(startOffset, endOffset - startOffset)];
    }
}


// -----------------------------------------------------------------------------
//	colorIdentifier:inString:
//		Colorize keywords in the text view.
// -----------------------------------------------------------------------------

- (void)marker:(ASKSyntaxMarker*)marker markIdentifier:(NSString*)identifier inString:(NSMutableAttributedString*)string {
    NSScanner * scanner = [NSScanner scannerWithString:string.string];
    NSDictionary * newAttributes = [self textAttributes];
    NSUInteger startOffset = 0;
    
    // Skip any leading whitespace chars, somehow NSScanner doesn't do that:
    if(self.charset) {
        while(startOffset < string.length) {
            if([self.charset characterIsMember:[string.string characterAtIndex:startOffset]]) {
                break;
            }
            startOffset++;
        }
    }
    
    scanner.scanLocation = startOffset;
    
    while(!scanner.isAtEnd) {
        // Look for start of identifier:
        [scanner scanUpToString:identifier intoString:NULL];
        startOffset = scanner.scanLocation;
        if(![scanner scanString:identifier intoString:NULL]) {
            return;
        }
        
        // Check that we're not in the middle of an identifier:
        
        // Is there a previous character?
        if(startOffset > 0)	{
            // Is it a valid identifier character?
            if([self.charset characterIsMember:[string.string characterAtIndex:(startOffset - 1)]]) {
                // Skip this.
                continue;
            }
        }
        
        // Is there a next character?
        if((startOffset + identifier.length + 1) < string.length) {
            // Is it a valid identifier character?
            if([self.charset characterIsMember:[string.string characterAtIndex:(startOffset + identifier.length)]]) {
                // Skip this.
                continue;
            }
        }
        
        // If we got here, this really is a whole identifier, not a substring of something larger. Mark it.
        [string addAttributes:newAttributes range:NSMakeRange(startOffset, identifier.length)];
    }
}

- (void)marker:(ASKSyntaxMarker*)marker markTagInString:(NSMutableAttributedString*)string {
    NSScanner * scanner = [NSScanner scannerWithString:string.string];
    NSDictionary * newAttributes = [self textAttributes];
    
    while(!scanner.isAtEnd) {
        [scanner scanUpToString:self.start intoString:NULL];
        NSUInteger startOffset = scanner.scanLocation;
        
        // Look for start of ignored style:
        if(startOffset >= string.length) {
            return;
        }
        ASKSyntaxComponent * currentComponent = [string attribute:ASKSyntaxComponentAttributeName atIndex:startOffset effectiveRange:NULL];
        
        if(![scanner scanString:self.start intoString:NULL]) {
            return;
        }
        
        // If start lies in range of ignored style, don't colorize it:
        if(self.ignoredComponent != nil && [currentComponent.name isEqualToString:self.ignoredComponent]) {
            continue;
        }
        
        // Look for matching end marker:
        while(!scanner.isAtEnd) {
            // Scan up to the next occurence of the terminating sequence:
            [scanner scanUpToString:self.end intoString:NULL];
            
            // Now, if the mode of the end marker is not the mode we were told to ignore,
            //  we're finished now and we can exit the inner loop:
            NSUInteger candidateEndOffset = scanner.scanLocation;
            if(candidateEndOffset < string.length) {
                currentComponent = [string attribute:ASKSyntaxComponentAttributeName atIndex:candidateEndOffset effectiveRange:NULL];
                [scanner scanString:self.end intoString:NULL];   // Also skip the terminating sequence.
                if(self.ignoredComponent == nil || ![currentComponent.name isEqualToString:self.ignoredComponent]) {
                    // We found the end marker!
                    break;
                }
            }
            
            // Otherwise we keep going, look for the next occurence of endCh and hope it isn't in that style.
        }
        NSUInteger endOffset = scanner.scanLocation;
        
        [string addAttributes:newAttributes range:NSMakeRange(startOffset, endOffset - startOffset)];
    }
}

@end
