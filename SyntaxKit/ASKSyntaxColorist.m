//
//  ASKSyntaxColorist.m
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

#import "ASKSyntaxColorist.h"

#import "ASKSyntax.h"
#import "ASKSyntaxMarker.h"
#import "ASKSyntaxColorPalette.h"

@interface ASKSyntaxColorist ()

@end

@implementation ASKSyntaxColorist

- (void)colorRange:(NSRange)range ofTextStorage:(NSTextStorage *)textStorage withSyntax:(ASKSyntax *)syntax defaultAttributes:(NSDictionary *)defaultTextAttributes {
    if(self.coloring)	 {
        // Prevent endless loop when recoloring's replacement of text causes processEditing to fire again.
        return;
    }
    
    [self.delegate syntaxColoristWillColor:self];
    
	@try {
		self.coloring = YES;
        
		[syntax.marker markRange:range ofAttributedString:textStorage withUserIdentifiers:
         [self.delegate syntaxColorist:self userIdentifiersForKeywordComponentName:@"UserIdentifiers"]];
        
        [textStorage enumerateAttribute:ASKSyntaxComponentAttributeName inRange:range options:0 usingBlock:^(ASKSyntaxComponent * component, NSRange range, BOOL *stop) {
            NSDictionary * attributes = defaultTextAttributes;
            
            if(component) {
                NSColor * color = [self.colorPalette colorForSyntaxComponent:component];
                attributes = [self textAttributesForComponent:component color:color defaultAttributes:attributes];
            }
            
            [textStorage setAttributes:attributes range:range];
        }];
		
		[textStorage fixFontAttributeInRange: range];	// Make sure Japanese etc. fallback fonts get applied.
	}
	@finally
	{
		self.coloring = NO;
        
        [self.delegate syntaxColoristDidColor:self];
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

- (NSDictionary*)textAttributesForComponent:(ASKSyntaxComponent*)component color:(NSColor*)color defaultAttributes:(NSDictionary *)defaultAttributes {
	NSMutableDictionary * newAttributes = [defaultAttributes mutableCopy];
    
    NSDictionary * additionalAttributes = [self.delegate syntaxColorist:self textAttributesForSyntaxComponent:component color:color];
    if(!additionalAttributes) {
        additionalAttributes = color ? @{ NSForegroundColorAttributeName: color } : @{};
    }
    
    [newAttributes addEntriesFromDictionary:additionalAttributes];
    
	// Make sure partial recoloring works:
	newAttributes[ASKSyntaxComponentAttributeName] = component;
	
	return newAttributes;
}

@end
