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
        [self marker:marker markCommentsFrom: self.start
                            to: self.end inString: string
                      withMode: self.name];
    }
    else if( [self.type isEqualToString: @"OneLineComment"] )
    {
        [self marker:marker markOneLineComment: self.start
                        inString: string withMode: self.name];
    }
    else if( [self.type isEqualToString: @"String"] )
    {
        [self marker:marker markStringsFrom: self.start
                           to: self.end
                     inString: string withMode: self.name
                andEscapeChar: self.escapeChar]; 
    }
    else if( [self.type isEqualToString: @"Tag"] )
    {
        [self marker:marker markTagFrom: self.start
                       to: self.end inString: string
                 withMode: self.name
             exceptIfMode: self.ignoredComponent];
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
                [self marker:marker markIdentifier: vCurrIdent inString: string withMode: self.name charset: self.charset];
            }
        }
    }
}

-(NSDictionary*)	textAttributesForComponentName: (NSString*)attr {
	return @{ ASKSyntaxModeAttributeName: attr };
}

-(void)marker:(ASKSyntaxMarker*)marker markStringsFrom: (NSString*) startCh to: (NSString*) endCh inString: (NSMutableAttributedString*) s
               withMode:(NSString*)attr andEscapeChar: (NSString*)vStringEscapeCharacter
{
	@try {
        NSScanner*			vScanner = [NSScanner scannerWithString: [s string]];
        NSDictionary*		vStyles = [self textAttributesForComponentName: attr];
        BOOL				vIsEndChar = NO;
        unichar				vEscChar = '\\';
        
        if( vStringEscapeCharacter )
        {
            if( [vStringEscapeCharacter length] != 0 )
                vEscChar = [vStringEscapeCharacter characterAtIndex: 0];
        }
        
        while( ![vScanner isAtEnd] )
        {
            NSUInteger		vStartOffs,
            vEndOffs;
            vIsEndChar = NO;
            
            [marker.delegate syntaxMarkerIsMarking:marker];
            
            // Look for start of string:
            [vScanner scanUpToString: startCh intoString: nil];
            vStartOffs = [vScanner scanLocation];
            if( ![vScanner scanString:startCh intoString:nil] )
                return;
            
            while( !vIsEndChar && ![vScanner isAtEnd] )	// Loop until we find end-of-string marker or our text to color is finished:
            {
                [vScanner scanUpToString: endCh intoString: nil];
                if( ([vStringEscapeCharacter length] == 0) || [[s string] characterAtIndex: ([vScanner scanLocation] -1)] != vEscChar )	// Backslash before the end marker? That means ignore the end marker.
                    vIsEndChar = YES;	// A real one! Terminate loop.
                if( ![vScanner scanString:endCh intoString:nil] )	// But skip this char before that.
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


-(void)marker:(ASKSyntaxMarker*)marker markCommentsFrom: (NSString*) startCh to: (NSString*) endCh inString: (NSMutableAttributedString*) s
                withMode:(NSString*)attr
{
	@try
	{
		NSScanner*			vScanner = [NSScanner scannerWithString: [s string]];
		NSDictionary*		vStyles = [self textAttributesForComponentName: attr];
		
		while( ![vScanner isAtEnd] )
		{
			NSUInteger		vStartOffs,
            vEndOffs;
			
			// Look for start of multi-line comment:
			[vScanner scanUpToString: startCh intoString: nil];
			vStartOffs = [vScanner scanLocation];
			if( ![vScanner scanString:startCh intoString:nil] )
				return;
            
			// Look for associated end-of-comment marker:
			[vScanner scanUpToString: endCh intoString: nil];
			if( ![vScanner scanString: endCh intoString: nil] )
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


-(void)marker:(ASKSyntaxMarker*)marker markOneLineComment: (NSString*) startCh inString: (NSMutableAttributedString*) s
                  withMode:(NSString*)attr
{
	@try
	{
		NSScanner*			vScanner = [NSScanner scannerWithString: [s string]];
		NSDictionary*		vStyles = [self textAttributesForComponentName: attr];
		
		while( ![vScanner isAtEnd] )
		{
			NSUInteger		vStartOffs,
            vEndOffs;
			
			// Look for start of one-line comment:
			[vScanner scanUpToString: startCh intoString: nil];
			vStartOffs = [vScanner scanLocation];
			if( ![vScanner scanString:startCh intoString:nil] )
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
              withMode:(NSString*)attr charset: (NSCharacterSet*)cset
{
	@try
	{
		NSScanner*			vScanner = [NSScanner scannerWithString: [s string]];
		NSDictionary*		vStyles = [self textAttributesForComponentName: attr];
		NSUInteger			vStartOffs = 0;
		
		// Skip any leading whitespace chars, somehow NSScanner doesn't do that:
		if( cset )
		{
			while( vStartOffs < [[s string] length] )
			{
				if( [cset characterIsMember: [[s string] characterAtIndex: vStartOffs]] )
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
				if( [cset characterIsMember: [[s string] characterAtIndex: (vStartOffs -1)]] )  // If charset is NIL, this evaluates to NO.
					continue;
			}
			
			if( (vStartOffs +[ident length] +1) < [s length] )
			{
				// Alphanum character following our identifier?
				if( [cset characterIsMember: [[s string] characterAtIndex: (vStartOffs +[ident length])]] )  // If charset is NIL, this evaluates to NO.
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


-(void)marker:(ASKSyntaxMarker*)marker markTagFrom: (NSString*) startCh to: (NSString*)endCh inString: (NSMutableAttributedString*) s
           withMode:(NSString*)attr exceptIfMode: (NSString*)ignoreAttr
{
	@try
	{
		NSScanner*			vScanner = [NSScanner scannerWithString: [s string]];
		NSDictionary*		vStyles = [self textAttributesForComponentName: attr];
		
		while( ![vScanner isAtEnd] )
		{
			NSUInteger		vStartOffs,
            vEndOffs;
			
			// Look for start of one-line comment:
			[vScanner scanUpToString: startCh intoString: nil];
			vStartOffs = [vScanner scanLocation];
			if( vStartOffs >= [s length] )
				return;
			NSString*   scMode = [s attribute:ASKSyntaxModeAttributeName atIndex:vStartOffs effectiveRange:NULL];
			if( ![vScanner scanString:startCh intoString:nil] )
				return;
			
			// If start lies in range of ignored style, don't colorize it:
			if( ignoreAttr != nil && [scMode isEqualToString: ignoreAttr] )
				continue;
            
			// Look for matching end marker:
			while( ![vScanner isAtEnd] )
			{
				// Scan up to the next occurence of the terminating sequence:
				[vScanner scanUpToString: endCh intoString:nil];
				
				// Now, if the mode of the end marker is not the mode we were told to ignore,
				//  we're finished now and we can exit the inner loop:
				vEndOffs = [vScanner scanLocation];
				if( vEndOffs < [s length] )
				{
					scMode = [s attribute:ASKSyntaxModeAttributeName atIndex:vEndOffs effectiveRange:NULL];
					[vScanner scanString: endCh intoString: nil];   // Also skip the terminating sequence.
					if( ignoreAttr == nil || ![scMode isEqualToString: ignoreAttr] )
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
