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
#import "ASKSyntaxComponent+Marking.h"

NSString * const ASKSyntaxComponentAttributeName = @"ASKSyntaxMode";

@implementation ASKSyntaxMarker

- (void)markRange:(NSRange)range ofAttributedString:(NSMutableAttributedString *)string withSyntax:(ASKSyntax *)syntax userIdentifiers:(NSArray *)userIdentifiers {
    // Kludge fix for case where we sometimes exceed text length:ra
    NSInteger diff = string.length - (range.location + range.length);
    if(diff < 0) {
        range.length += diff;
    }
    
    // Get the text we'll be working with:
    NSMutableAttributedString * scratchString = [[NSMutableAttributedString alloc] initWithString:[string.string substringWithRange:range]];
    
    for(ASKSyntaxComponent * component in syntax.components) {
        [component marker:self markInString:scratchString withUserIdentifiers:userIdentifiers];
    }
    
    // Replace the range with our recolored part:
    [scratchString enumerateAttribute:ASKSyntaxComponentAttributeName inRange:NSMakeRange(0, scratchString.length) options:0 usingBlock:^(id value, NSRange scratchRange, BOOL *stop) {
        NSRange realRange = NSMakeRange(scratchRange.location + range.location, scratchRange.length);
        
        if(value) {
            [string addAttribute:ASKSyntaxComponentAttributeName value:value range:realRange];
        }
        else {
            [string removeAttribute:ASKSyntaxComponentAttributeName range:realRange];
        }
    }];
}

@end
