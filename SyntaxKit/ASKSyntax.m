//
//  ASKSyntax.m
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

#import "ASKSyntax.h"
#import "NSArray+Color.h"
#import "NSScanner+SkipUpToCharset.h"

@interface ASKSyntax ()

@property (strong) NSDictionary * defaultTextAttributes;

@end


@implementation ASKSyntax

- (id)initWithDefinition:(NSDictionary *)definition {
    if((self = [super init])) {
        _definition = definition;
    }
    return self;
}

- (id)initWithDefinitionURL:(NSURL *)URL {
    return [self initWithDefinition:[NSDictionary dictionaryWithContentsOfURL:URL]];
}

- (void)colorRange:(NSRange)range ofTextStorage:(NSTextStorage *)textStorage defaultAttributes:(NSDictionary*)defaultTextAttributes {
    self.defaultTextAttributes = defaultTextAttributes;
    
    [self.delegate syntaxWillColor:self];
    
	@try
	{
        if(self.coloring)	// Prevent endless loop when recoloring's replacement of text causes processEditing to fire again.
            return;
        
		self.coloring = YES;
        
		
		// Kludge fix for case where we sometimes exceed text length:ra
		NSInteger diff = [textStorage length] -(range.location +range.length);
		if( diff < 0 )
			range.length += diff;
				
		// Get the text we'll be working with:
		NSMutableAttributedString*	vString = [[NSMutableAttributedString alloc] initWithString: [textStorage.string substringWithRange: range] attributes: self.defaultTextAttributes];
				
		// Load colors and fonts to use from preferences:
		// Load our dictionary which contains info on coloring this language:
		NSDictionary*				vSyntaxDefinition = self.definition;
		NSEnumerator*				vComponentsEnny = [vSyntaxDefinition[@"Components"] objectEnumerator];
		
		if( vComponentsEnny == nil )	// No list of components to colorize?
		{
			// @finally takes care of cleaning up syntaxColoringBusy etc. here.
			return;
		}
		
		// Loop over all available components:
		NSDictionary*				vCurrComponent = nil;
		NSUserDefaults*				vPrefs = [NSUserDefaults standardUserDefaults];

		while( (vCurrComponent = [vComponentsEnny nextObject]) )
		{
			NSString*   vComponentType = vCurrComponent[@"Type"];
			NSString*   vComponentName = vCurrComponent[@"Name"];
			NSString*   vColorKeyName = [@"SyntaxColoring:Color:" stringByAppendingString: vComponentName];
			NSColor*	vColor = [[vPrefs arrayForKey: vColorKeyName] colorValue];
			
			if( !vColor )
				vColor = [vCurrComponent[@"Color"] colorValue];
			
			if( [vComponentType isEqualToString: @"BlockComment"] )
			{
				[self colorCommentsFrom: vCurrComponent[@"Start"]
						to: vCurrComponent[@"End"] inString: vString
						withColor: vColor andMode: vComponentName];
			}
			else if( [vComponentType isEqualToString: @"OneLineComment"] )
			{
				[self colorOneLineComment: vCurrComponent[@"Start"]
						inString: vString withColor: vColor andMode: vComponentName];
			}
			else if( [vComponentType isEqualToString: @"String"] )
			{
				[self colorStringsFrom: vCurrComponent[@"Start"]
						to: vCurrComponent[@"End"]
						inString: vString withColor: vColor andMode: vComponentName
						andEscapeChar: vCurrComponent[@"EscapeChar"]]; 
			}
			else if( [vComponentType isEqualToString: @"Tag"] )
			{
				[self colorTagFrom: vCurrComponent[@"Start"]
						to: vCurrComponent[@"End"] inString: vString
						withColor: vColor andMode: vComponentName
						exceptIfMode: vCurrComponent[@"IgnoredComponent"]];
			}
			else if( [vComponentType isEqualToString: @"Keywords"] )
			{
				NSArray* vIdents = vCurrComponent[@"Keywords"];
				if( !vIdents )
					vIdents = [self.delegate syntax:self userIdentifiersForKeywordComponentName:vComponentName];
				if( !vIdents )
					vIdents = [[NSUserDefaults standardUserDefaults] objectForKey: [@"SyntaxColoring:Keywords:" stringByAppendingString: vComponentName]];
				if( !vIdents && [vComponentName isEqualToString: @"UserIdentifiers"] )
					vIdents = [[NSUserDefaults standardUserDefaults] objectForKey: TD_USER_DEFINED_IDENTIFIERS];
				if( vIdents )
				{
					NSCharacterSet*		vIdentCharset = nil;
					NSString*			vCurrIdent = nil;
					NSString*			vCsStr = vCurrComponent[@"Charset"];
					if( vCsStr )
						vIdentCharset = [NSCharacterSet characterSetWithCharactersInString: vCsStr];
					
					NSEnumerator*	vItty = [vIdents objectEnumerator];
					while( vCurrIdent = [vItty nextObject] )
						[self colorIdentifier: vCurrIdent inString: vString withColor: vColor
									andMode: vComponentName charset: vIdentCharset];
				}
			}
		}
		
		// Replace the range with our recolored part:
		[textStorage replaceCharactersInRange: range withAttributedString: vString];
		[textStorage fixFontAttributeInRange: range];	// Make sure Japanese etc. fallback fonts get applied.
	}
	@finally
	{
		self.coloring = NO;
        
        [self.delegate syntaxDidColor:self];
	}
}


// -----------------------------------------------------------------------------
//	textAttributesForComponentName:color:
//		Return the styles to use for the given mode/color. This calls upon the
//		delegate to provide the styles, or if not, just set the color. This is
//		also responsible for setting the TD_SYNTAX_COLORING_MODE_ATTR attribute
//		so we can extend a range for partial recoloring to color the full block
//		comment or whatever which is being changed (in case the user types a
//		sequence that would end that block comment or similar).
// -----------------------------------------------------------------------------

-(NSDictionary*)	textAttributesForComponentName: (NSString*)attr color: (NSColor*)col
{
	NSDictionary*		vLocalStyles = [self.delegate syntax:self textAttributesForComponentName: attr color: col];
	NSMutableDictionary*vStyles = [[self defaultTextAttributes] mutableCopy];
	if( vLocalStyles )
		[vStyles addEntriesFromDictionary: vLocalStyles];
	else
		vStyles[NSForegroundColorAttributeName] = col;
	
	// Make sure partial recoloring works:
	vStyles[TD_SYNTAX_COLORING_MODE_ATTR] = attr;
	
	return vStyles;
}


// -----------------------------------------------------------------------------
//	colorStringsFrom:to:inString:withColor:andMode:andEscapeChar:
//		Apply syntax coloring to all strings. This is basically the same code
//		as used for multi-line comments, except that it ignores the end
//		character if it is preceded by a backslash.
// -----------------------------------------------------------------------------

-(void)	colorStringsFrom: (NSString*) startCh to: (NSString*) endCh inString: (NSMutableAttributedString*) s
               withColor: (NSColor*) col andMode:(NSString*)attr andEscapeChar: (NSString*)vStringEscapeCharacter
{
	NS_DURING
    NSScanner*			vScanner = [NSScanner scannerWithString: [s string]];
    NSDictionary*		vStyles = [self textAttributesForComponentName: attr color: col];
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
        
        [self.delegate syntaxIsColoring:self];
        
        // Look for start of string:
        [vScanner scanUpToString: startCh intoString: nil];
        vStartOffs = [vScanner scanLocation];
        if( ![vScanner scanString:startCh intoString:nil] )
            NS_VOIDRETURN;
        
        while( !vIsEndChar && ![vScanner isAtEnd] )	// Loop until we find end-of-string marker or our text to color is finished:
        {
            [vScanner scanUpToString: endCh intoString: nil];
            if( ([vStringEscapeCharacter length] == 0) || [[s string] characterAtIndex: ([vScanner scanLocation] -1)] != vEscChar )	// Backslash before the end marker? That means ignore the end marker.
                vIsEndChar = YES;	// A real one! Terminate loop.
            if( ![vScanner scanString:endCh intoString:nil] )	// But skip this char before that.
                return;
            
            [self.delegate syntaxIsColoring:self];
        }
        
        vEndOffs = [vScanner scanLocation];
        
        // Now mess with the string's styles:
        [s setAttributes: vStyles range: NSMakeRange( vStartOffs, vEndOffs -vStartOffs )];
    }
	NS_HANDLER
    // Just ignore it, syntax coloring isn't that important.
	NS_ENDHANDLER
}


// -----------------------------------------------------------------------------
//	colorCommentsFrom:to:inString:withColor:andMode:
//		Colorize block-comments in the text view.
// -----------------------------------------------------------------------------

-(void)	colorCommentsFrom: (NSString*) startCh to: (NSString*) endCh inString: (NSMutableAttributedString*) s
                withColor: (NSColor*) col andMode:(NSString*)attr
{
	@try
	{
		NSScanner*			vScanner = [NSScanner scannerWithString: [s string]];
		NSDictionary*		vStyles = [self textAttributesForComponentName: attr color: col];
		
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
			[s setAttributes: vStyles range: NSMakeRange( vStartOffs, vEndOffs -vStartOffs )];
			
            [self.delegate syntaxIsColoring:self];
		}
	}
	@catch( ... )
	{
		// Just ignore it, syntax coloring isn't that important.
	}
}


// -----------------------------------------------------------------------------
//	colorOneLineComment:inString:withColor:andMode:
//		Colorize one-line-comments in the text view.
// -----------------------------------------------------------------------------

-(void)	colorOneLineComment: (NSString*) startCh inString: (NSMutableAttributedString*) s
                  withColor: (NSColor*) col andMode:(NSString*)attr
{
	@try
	{
		NSScanner*			vScanner = [NSScanner scannerWithString: [s string]];
		NSDictionary*		vStyles = [self textAttributesForComponentName: attr color: col];
		
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
			[s setAttributes: vStyles range: NSMakeRange( vStartOffs, vEndOffs -vStartOffs )];
			
            [self.delegate syntaxIsColoring:self];
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

-(void)	colorIdentifier: (NSString*) ident inString: (NSMutableAttributedString*) s
              withColor: (NSColor*) col andMode:(NSString*)attr charset: (NSCharacterSet*)cset
{
	@try
	{
		NSScanner*			vScanner = [NSScanner scannerWithString: [s string]];
		NSDictionary*		vStyles = [self textAttributesForComponentName: attr color: col];
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
			[s setAttributes: vStyles range: NSMakeRange( vStartOffs, [ident length] )];
            
            [self.delegate syntaxIsColoring:self];
		}
	}
	@catch( ... )
	{
		// Just ignore it, syntax coloring isn't that important.
	}
}


// -----------------------------------------------------------------------------
//	colorTagFrom:to:inString:withColor:andMode:exceptIfMode:
//		Colorize HTML tags or similar constructs in the text view.
// -----------------------------------------------------------------------------

-(void)	colorTagFrom: (NSString*) startCh to: (NSString*)endCh inString: (NSMutableAttributedString*) s
           withColor: (NSColor*) col andMode:(NSString*)attr exceptIfMode: (NSString*)ignoreAttr
{
	@try
	{
		NSScanner*			vScanner = [NSScanner scannerWithString: [s string]];
		NSDictionary*		vStyles = [self textAttributesForComponentName: attr color: col];
		
		while( ![vScanner isAtEnd] )
		{
			NSUInteger		vStartOffs,
            vEndOffs;
			
			// Look for start of one-line comment:
			[vScanner scanUpToString: startCh intoString: nil];
			vStartOffs = [vScanner scanLocation];
			if( vStartOffs >= [s length] )
				return;
			NSString*   scMode = [s attributesAtIndex:vStartOffs effectiveRange: nil][TD_SYNTAX_COLORING_MODE_ATTR];
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
					scMode = [s attributesAtIndex:vEndOffs effectiveRange: nil][TD_SYNTAX_COLORING_MODE_ATTR];
					[vScanner scanString: endCh intoString: nil];   // Also skip the terminating sequence.
					if( ignoreAttr == nil || ![scMode isEqualToString: ignoreAttr] )
						break;
				}
				
				// Otherwise we keep going, look for the next occurence of endCh and hope it isn't in that style.
			}
			
			vEndOffs = [vScanner scanLocation];
			
            [self.delegate syntaxIsColoring:self];
			
			// Now mess with the string's styles:
			[s setAttributes: vStyles range: NSMakeRange( vStartOffs, vEndOffs -vStartOffs )];
		}
	}
	@catch( ... )
	{
		// Just ignore it, syntax coloring isn't that important.
	}
}

@end
