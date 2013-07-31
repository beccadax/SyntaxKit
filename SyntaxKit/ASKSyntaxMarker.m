//
//  ASKSyntaxMarker.m
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

#import "ASKSyntaxMarker.h"
#import "ASKSyntax.h"
#import "NSScanner+SkipUpToCharset.h"

NSString * const ASKSyntaxModeAttributeName = @"ASKSyntaxMode";

@implementation ASKSyntaxMarker

- (void)markRange:(NSRange)range ofAttributedString:(NSMutableAttributedString *)string withSyntax:(ASKSyntax *)syntax {
    // Kludge fix for case where we sometimes exceed text length:ra
    NSInteger diff = [string length] -(range.location +range.length);
    if( diff < 0 )
        range.length += diff;
    
    // Get the text we'll be working with:
    NSMutableAttributedString*	vString = [string mutableCopy];
    [vString removeAttribute:ASKSyntaxModeAttributeName range:range];
    
    // Load colors and fonts to use from preferences:
    // Load our dictionary which contains info on coloring this language:
    for(ASKSyntaxComponent *vCurrComponent in syntax.components)
    {
        NSString*   vComponentType = vCurrComponent.type;
        NSString*   vComponentName = vCurrComponent.name;
        
        if( [vComponentType isEqualToString: @"BlockComment"] )
        {
            [self markCommentsFrom: vCurrComponent.start
                                 to: vCurrComponent.end inString: vString
                          withMode: vComponentName];
        }
        else if( [vComponentType isEqualToString: @"OneLineComment"] )
        {
            [self markOneLineComment: vCurrComponent.start
                             inString: vString withMode: vComponentName];
        }
        else if( [vComponentType isEqualToString: @"String"] )
        {
            [self markStringsFrom: vCurrComponent.start
                                to: vCurrComponent.end
                          inString: vString withMode: vComponentName
                     andEscapeChar: vCurrComponent.escapeChar]; 
        }
        else if( [vComponentType isEqualToString: @"Tag"] )
        {
            [self markTagFrom: vCurrComponent.start
                            to: vCurrComponent.end inString: vString
                     withMode: vComponentName
                  exceptIfMode: vCurrComponent.ignoredComponent];
        }
        else if( [vComponentType isEqualToString: @"Keywords"] )
        {
            NSArray* vIdents = vCurrComponent.keywords;
            if( !vIdents ) {
                vIdents = [self.delegate syntaxMarker:self userIdentifiersForKeywordMode:vComponentName];
            }
            if( vIdents )
            {
                NSCharacterSet*		vIdentCharset = vCurrComponent.charset;
                
                for( NSString * vCurrIdent in vIdents ) {
                    [self markIdentifier: vCurrIdent inString: vString withMode: vComponentName charset: vIdentCharset];
                }
            }
        }
    }
    
    // Replace the range with our recolored part:
    [string replaceCharactersInRange: range withAttributedString: vString];
}

-(NSDictionary*)	textAttributesForComponentName: (NSString*)attr {
	return @{ ASKSyntaxModeAttributeName: attr };
}

-(void)	markStringsFrom: (NSString*) startCh to: (NSString*) endCh inString: (NSMutableAttributedString*) s
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
            
            [self.delegate syntaxMarkerIsMarking:self];
            
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
                
                [self.delegate syntaxMarkerIsMarking:self];
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


-(void)	markCommentsFrom: (NSString*) startCh to: (NSString*) endCh inString: (NSMutableAttributedString*) s
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
			
            [self.delegate syntaxMarkerIsMarking:self];
		}
	}
	@catch( ... )
	{
		// Just ignore it, syntax coloring isn't that important.
	}
}


-(void)	markOneLineComment: (NSString*) startCh inString: (NSMutableAttributedString*) s
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
			
            [self.delegate syntaxMarkerIsMarking:self];
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

-(void)	markIdentifier: (NSString*) ident inString: (NSMutableAttributedString*) s
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
            
            [self.delegate syntaxMarkerIsMarking:self];
		}
	}
	@catch( ... )
	{
		// Just ignore it, syntax coloring isn't that important.
	}
}


-(void)	markTagFrom: (NSString*) startCh to: (NSString*)endCh inString: (NSMutableAttributedString*) s
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
			
            [self.delegate syntaxMarkerIsMarking:self];
			
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
