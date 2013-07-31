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
        NSArray* vIdents = self.keywords;
        if( !vIdents ) {
            vIdents = [marker.delegate syntaxMarker:marker userIdentifiersForKeywordMode:self.name];
        }
        if( vIdents )
        {
            for( NSString * vCurrIdent in vIdents ) {
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
        NSScanner*			vScanner = [NSScanner scannerWithString: [s string]];
        NSDictionary*		vStyles = [self textAttributes];
        BOOL				vIsEndChar = NO;
        unichar				vEscChar = '\\';
        
        if( [self.escapeChar length] != 0 ) {
            vEscChar = [self.escapeChar characterAtIndex: 0];
        }
        
        while( ![vScanner isAtEnd] )
        {
            NSUInteger		vStartOffs,
            vEndOffs;
            vIsEndChar = NO;
            
            [marker.delegate syntaxMarkerIsMarking:marker];
            
            // Look for start of string:
            [vScanner scanUpToString: self.start intoString: nil];
            vStartOffs = [vScanner scanLocation];
            if( ![vScanner scanString:self.start intoString:nil] )
                return;
            
            while( !vIsEndChar && ![vScanner isAtEnd] )	// Loop until we find end-of-string marker or our text to color is finished:
            {
                [vScanner scanUpToString: self.end intoString: nil];
                if( ([self.escapeChar length] == 0) || [[s string] characterAtIndex: ([vScanner scanLocation] -1)] != vEscChar )	// Backslash before the end marker? That means ignore the end marker.
                    vIsEndChar = YES;	// A real one! Terminate loop.
                if( ![vScanner scanString:self.end intoString:nil] )	// But skip this char before that.
                    return;
                
                [marker.delegate syntaxMarkerIsMarking:marker];
            }
            
            vEndOffs = [vScanner scanLocation];
            
            // Now mess with the string's styles:
            [s addAttributes: vStyles range: NSMakeRange( vStartOffs, vEndOffs -vStartOffs )];
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
		NSScanner*			vScanner = [NSScanner scannerWithString: [s string]];
		NSDictionary*		vStyles = [self textAttributes];
		
		while( ![vScanner isAtEnd] )
		{
			NSUInteger		vStartOffs,
            vEndOffs;
			
			// Look for start of multi-line comment:
			[vScanner scanUpToString: self.start intoString: nil];
			vStartOffs = [vScanner scanLocation];
			if( ![vScanner scanString:self.start intoString:nil] )
				return;
            
			// Look for associated end-of-comment marker:
			[vScanner scanUpToString: self.end intoString: nil];
			if( ![vScanner scanString: self.end intoString: nil] )
            /*return*/;  // Don't exit. If user forgot trailing marker, indicate this by "bleeding" until end of string.
			vEndOffs = [vScanner scanLocation];
			
			// Now mess with the string's styles:
			[s addAttributes: vStyles range: NSMakeRange( vStartOffs, vEndOffs -vStartOffs )];
			
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
		NSScanner*			vScanner = [NSScanner scannerWithString: [s string]];
		NSDictionary*		vStyles = [self textAttributes];
		
		while( ![vScanner isAtEnd] )
		{
			NSUInteger		vStartOffs,
            vEndOffs;
			
			// Look for start of one-line comment:
			[vScanner scanUpToString: self.start intoString: nil];
			vStartOffs = [vScanner scanLocation];
			if( ![vScanner scanString:self.start intoString:nil] )
				return;
            
			// Look for associated line break:
			if( ![vScanner skipUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString: @"\n\r"]] )
				;
			
			vEndOffs = [vScanner scanLocation];
			
			// Now mess with the string's styles:
			[s addAttributes: vStyles range: NSMakeRange( vStartOffs, vEndOffs -vStartOffs )];
			
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
		NSScanner*			vScanner = [NSScanner scannerWithString: [s string]];
		NSDictionary*		vStyles = [self textAttributes];
		NSUInteger			vStartOffs = 0;
		
		// Skip any leading whitespace chars, somehow NSScanner doesn't do that:
		if( self.charset )
		{
			while( vStartOffs < [[s string] length] )
			{
				if( [self.charset characterIsMember: [[s string] characterAtIndex: vStartOffs]] )
					break;
				vStartOffs++;
			}
		}
		
		[vScanner setScanLocation: vStartOffs];
		
		while( ![vScanner isAtEnd] )
		{
			// Look for start of identifier:
			[vScanner scanUpToString: ident intoString: nil];
			vStartOffs = [vScanner scanLocation];
			if( ![vScanner scanString:ident intoString:nil] )
				return;
			
			if( vStartOffs > 0 )	// Check that we're not in the middle of an identifier:
			{
				// Alphanum character before identifier start?
				if( [self.charset characterIsMember: [[s string] characterAtIndex: (vStartOffs -1)]] )  // If charset is NIL, this evaluates to NO.
					continue;
			}
			
			if( (vStartOffs +[ident length] +1) < [s length] )
			{
				// Alphanum character following our identifier?
				if( [self.charset characterIsMember: [[s string] characterAtIndex: (vStartOffs +[ident length])]] )  // If charset is NIL, this evaluates to NO.
					continue;
			}
			
			// Now mess with the string's styles:
			[s addAttributes: vStyles range: NSMakeRange( vStartOffs, [ident length] )];
            
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
		NSScanner*			vScanner = [NSScanner scannerWithString: [s string]];
		NSDictionary*		vStyles = [self textAttributes];
		
		while( ![vScanner isAtEnd] )
		{
			NSUInteger		vStartOffs,
            vEndOffs;
			
			// Look for start of one-line comment:
			[vScanner scanUpToString: self.start intoString: nil];
			vStartOffs = [vScanner scanLocation];
			if( vStartOffs >= [s length] )
				return;
			NSString*   scMode = [s attribute:ASKSyntaxModeAttributeName atIndex:vStartOffs effectiveRange:NULL];
			if( ![vScanner scanString:self.start intoString:nil] )
				return;
			
			// If start lies in range of ignored style, don't colorize it:
			if( self.ignoredComponent != nil && [scMode isEqualToString: self.ignoredComponent] )
				continue;
            
			// Look for matching end marker:
			while( ![vScanner isAtEnd] )
			{
				// Scan up to the next occurence of the terminating sequence:
				[vScanner scanUpToString: self.end intoString:nil];
				
				// Now, if the mode of the end marker is not the mode we were told to ignore,
				//  we're finished now and we can exit the inner loop:
				vEndOffs = [vScanner scanLocation];
				if( vEndOffs < [s length] )
				{
					scMode = [s attribute:ASKSyntaxModeAttributeName atIndex:vEndOffs effectiveRange:NULL];
					[vScanner scanString: self.end intoString: nil];   // Also skip the terminating sequence.
					if( self.ignoredComponent == nil || ![scMode isEqualToString: self.ignoredComponent] )
						break;
				}
				
				// Otherwise we keep going, look for the next occurence of endCh and hope it isn't in that style.
			}
			
			vEndOffs = [vScanner scanLocation];
			
            [marker.delegate syntaxMarkerIsMarking:marker];
			
			// Now mess with the string's styles:
			[s addAttributes: vStyles range: NSMakeRange( vStartOffs, vEndOffs -vStartOffs )];
		}
	}
	@catch( ... )
	{
		// Just ignore it, syntax coloring isn't that important.
	}
}

@end
