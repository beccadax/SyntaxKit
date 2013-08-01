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

- (void)marker:(ASKSyntaxMarker *)marker markInString:(NSMutableAttributedString *)string {
    if( [self.type isEqualToString: @"BlockComment"] )
    {
        [self marker:marker markCommentsInString:string];
    }
    else if( [self.type isEqualToString: @"OneLineComment"] )
    {
        [self marker:marker markOneLineCommentInString:string];
    }
    else if( [self.type isEqualToString: @"String"] )
    {
        [self marker:marker markStringsInString:string]; 
    }
    else if( [self.type isEqualToString: @"Tag"] )
    {
        [self marker:marker markTagInString:string];
    }
    else if( [self.type isEqualToString: @"Keywords"] )
    {
        NSArray* identifiers = self.keywords;
        if( !identifiers ) {
            identifiers = [marker.delegate syntaxMarker:marker userIdentifiersForKeywordMode:self.name];
        }
        if( identifiers )
        {
            for( NSString * vCurrIdent in identifiers ) {
                [self marker:marker markIdentifier:vCurrIdent inString: string];
            }
        }
    }
}

-(NSDictionary*)	textAttributes {
	return @{ ASKSyntaxModeAttributeName: self.name };
}

-(void)marker:(ASKSyntaxMarker*)marker markStringsInString: (NSMutableAttributedString*) s
{
	@try {
        NSScanner*			scanner = [NSScanner scannerWithString: [s string]];
        NSDictionary*		newAttributes = [self textAttributes];
        BOOL				isEndChar = NO;
        unichar				escapeChar = '\\';
        
        if( [self.escapeChar length] != 0 ) {
            escapeChar = [self.escapeChar characterAtIndex: 0];
        }
        
        while( ![scanner isAtEnd] )
        {
            NSUInteger startOffset, endOffset;
            isEndChar = NO;
            
            [marker.delegate syntaxMarkerIsMarking:marker];
            
            // Look for start of string:
            [scanner scanUpToString: self.start intoString: nil];
            startOffset = [scanner scanLocation];
            if( ![scanner scanString:self.start intoString:nil] )
                return;
            
            while( !isEndChar && ![scanner isAtEnd] )	// Loop until we find end-of-string marker or our text to color is finished:
            {
                [scanner scanUpToString: self.end intoString: nil];
                if( ([self.escapeChar length] == 0) || [[s string] characterAtIndex: ([scanner scanLocation] -1)] != escapeChar )	// Backslash before the end marker? That means ignore the end marker.
                    isEndChar = YES;	// A real one! Terminate loop.
                if( ![scanner scanString:self.end intoString:nil] )	// But skip this char before that.
                    return;
                
                [marker.delegate syntaxMarkerIsMarking:marker];
            }
            
            endOffset = [scanner scanLocation];
            
            // Now mess with the string's styles:
            [s addAttributes: newAttributes range: NSMakeRange( startOffset, endOffset - startOffset )];
        }
    }
    @catch ( ... ) {
        // Just ignore it, syntax coloring isn't that important.
    }
}


-(void)marker:(ASKSyntaxMarker*)marker markCommentsInString: (NSMutableAttributedString*) s
{
	@try
	{
		NSScanner*			scanner = [NSScanner scannerWithString: [s string]];
		NSDictionary*		newAttributes = [self textAttributes];
		
		while( ![scanner isAtEnd] )
		{
			NSUInteger startOffset, endOffset;
			
			// Look for start of multi-line comment:
			[scanner scanUpToString: self.start intoString: nil];
			startOffset = [scanner scanLocation];
			if( ![scanner scanString:self.start intoString:nil] )
				return;
            
			// Look for associated end-of-comment marker:
			[scanner scanUpToString: self.end intoString: nil];
			if( ![scanner scanString: self.end intoString: nil] )
            /*return*/;  // Don't exit. If user forgot trailing marker, indicate this by "bleeding" until end of string.
			endOffset = [scanner scanLocation];
			
			// Now mess with the string's styles:
			[s addAttributes: newAttributes range: NSMakeRange( startOffset, endOffset -startOffset )];
			
            [marker.delegate syntaxMarkerIsMarking:marker];
		}
	}
	@catch( ... )
	{
		// Just ignore it, syntax coloring isn't that important.
	}
}


-(void)marker:(ASKSyntaxMarker*)marker markOneLineCommentInString: (NSMutableAttributedString*) s
{
	@try
	{
		NSScanner*			scanner = [NSScanner scannerWithString: [s string]];
		NSDictionary*		newAttributes = [self textAttributes];
		
		while( ![scanner isAtEnd] )
		{
			NSUInteger startOffset, endOffset;
			
			// Look for start of one-line comment:
			[scanner scanUpToString: self.start intoString: nil];
			startOffset = [scanner scanLocation];
			if( ![scanner scanString:self.start intoString:nil] )
				return;
            
			// Look for associated line break:
			if( ![scanner skipUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString: @"\n\r"]] )
				;
			
			endOffset = [scanner scanLocation];
			
			// Now mess with the string's styles:
			[s addAttributes: newAttributes range: NSMakeRange( startOffset, endOffset -startOffset )];
			
            [marker.delegate syntaxMarkerIsMarking:marker];
		}
	}
	@catch( ... )
	{
		// Just ignore it, syntax coloring isn't that important.
	}
}


// -----------------------------------------------------------------------------
//	colorIdentifier:inString:
//		Colorize keywords in the text view.
// -----------------------------------------------------------------------------

-(void)marker:(ASKSyntaxMarker*)marker markIdentifier: (NSString*) ident inString: (NSMutableAttributedString*) s
{
	@try
	{
		NSScanner*			scanner = [NSScanner scannerWithString: [s string]];
		NSDictionary*		newAttributes = [self textAttributes];
		NSUInteger			startOffset = 0;
		
		// Skip any leading whitespace chars, somehow NSScanner doesn't do that:
		if( self.charset )
		{
			while( startOffset < [[s string] length] )
			{
				if( [self.charset characterIsMember: [[s string] characterAtIndex: startOffset]] )
					break;
				startOffset++;
			}
		}
		
		[scanner setScanLocation: startOffset];
		
		while( ![scanner isAtEnd] )
		{
			// Look for start of identifier:
			[scanner scanUpToString: ident intoString: nil];
			startOffset = [scanner scanLocation];
			if( ![scanner scanString:ident intoString:nil] )
				return;
			
			if( startOffset > 0 )	// Check that we're not in the middle of an identifier:
			{
				// Alphanum character before identifier start?
				if( [self.charset characterIsMember: [[s string] characterAtIndex: (startOffset - 1)]] )  // If charset is NIL, this evaluates to NO.
					continue;
			}
			
			if( (startOffset + [ident length] + 1) < [s length] )
			{
				// Alphanum character following our identifier?
				if( [self.charset characterIsMember: [[s string] characterAtIndex: (startOffset + [ident length])]] )  // If charset is NIL, this evaluates to NO.
					continue;
			}
			
			// Now mess with the string's styles:
			[s addAttributes: newAttributes range: NSMakeRange( startOffset, [ident length] )];
            
            [marker.delegate syntaxMarkerIsMarking:marker];
		}
	}
	@catch( ... )
	{
		// Just ignore it, syntax coloring isn't that important.
	}
}


-(void)marker:(ASKSyntaxMarker*)marker markTagInString: (NSMutableAttributedString*) s
{
	@try
	{
		NSScanner*			scanner = [NSScanner scannerWithString: [s string]];
		NSDictionary*		newAttributes = [self textAttributes];
		
		while( ![scanner isAtEnd] )
		{
			NSUInteger startOffset, endOffset;
			
			// Look for start of one-line comment:
			[scanner scanUpToString: self.start intoString: nil];
			startOffset = [scanner scanLocation];
			if( startOffset >= [s length] )
				return;
			NSString*   scMode = [s attribute:ASKSyntaxModeAttributeName atIndex:startOffset effectiveRange:NULL];
			if( ![scanner scanString:self.start intoString:nil] )
				return;
			
			// If start lies in range of ignored style, don't colorize it:
			if( self.ignoredComponent != nil && [scMode isEqualToString: self.ignoredComponent] )
				continue;
            
			// Look for matching end marker:
			while( ![scanner isAtEnd] )
			{
				// Scan up to the next occurence of the terminating sequence:
				[scanner scanUpToString: self.end intoString:nil];
				
				// Now, if the mode of the end marker is not the mode we were told to ignore,
				//  we're finished now and we can exit the inner loop:
				endOffset = [scanner scanLocation];
				if( endOffset < [s length] )
				{
					scMode = [s attribute:ASKSyntaxModeAttributeName atIndex:endOffset effectiveRange:NULL];
					[scanner scanString: self.end intoString: nil];   // Also skip the terminating sequence.
					if( self.ignoredComponent == nil || ![scMode isEqualToString: self.ignoredComponent] )
						break;
				}
				
				// Otherwise we keep going, look for the next occurence of endCh and hope it isn't in that style.
			}
			
			endOffset = [scanner scanLocation];
			
            [marker.delegate syntaxMarkerIsMarking:marker];
			
			// Now mess with the string's styles:
			[s addAttributes: newAttributes range: NSMakeRange( startOffset, endOffset - startOffset )];
		}
	}
	@catch( ... )
	{
		// Just ignore it, syntax coloring isn't that important.
	}
}

@end
