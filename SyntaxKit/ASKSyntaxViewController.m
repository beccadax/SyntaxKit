//
//  ASKTextViewController.m
//  Architechies SyntaxKit
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

// -----------------------------------------------------------------------------
//	Headers:
// -----------------------------------------------------------------------------

#import "ASKSyntaxViewController.h"
#import "UKHelperMacros.h"
#import "TDBindings.h"
#import "ASKTypesetter.h"
#import "NSTextView+SyntaxKit.h"
#import <objc/runtime.h>
#import "ASKLineNumberView.h"
#import "ASKSyntax.h"
#import "ASKSyntaxMarker.h"
#import "ASKSyntaxColorist.h"
#import "ASKSyntaxColorPalette.h"

static void * const KVO = (void*)&KVO;

// -----------------------------------------------------------------------------
//	Globals:
// -----------------------------------------------------------------------------

@interface ASKSyntaxViewController () <ASKSyntaxColoristDelegate>

- (void)recolorRange:(NSRange)range;
@property (assign) BOOL recoloring;

@property (strong) ASKSyntaxColorist * syntaxColorist;

@end


// -----------------------------------------------------------------------------
//	Macros:
// -----------------------------------------------------------------------------

@implementation ASKSyntaxViewController

- (void)setSyntax:(ASKSyntax *)syntax {
    _syntax = syntax;
    
    [self recolorCompleteFile:nil];
}

- (NSTextView*)view {
    return (NSTextView*)[super view];
}

- (void)prep {
    _colorPalette = ASKSyntaxColorPalette.standardColorPalette;
    
    _syntaxColorist = [ASKSyntaxColorist new];
    _syntaxColorist.delegate = self;
    
    _maintainIndentation = YES;
    _wrapsLines = NO;
    _tabDepth = 4;
}

-(id)initWithNibName:(NSString*)inNibName bundle:(NSBundle*)inBundle {
    if((self = [super initWithNibName: inNibName bundle: inBundle])) {
        [self prep];
	}
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if((self = [super initWithCoder:aDecoder])) {
        [self prep];
    }
    return self;
}

- (void)setUpSyntaxColoring {
    self.view.layoutManager.typesetter = [ASKTypesetter new];
	
	// Register for "text changed" notifications of our text storage
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(processEditing:) name:NSTextStorageDidProcessEditingNotification object:self.view.textStorage];
	
	// Make sure text isn't wrapped
	self.wrapsLines = self.wrapsLines;
    
    // Set up tab depth
    [self addObserver:self forKeyPath:@"view.font" options:NSKeyValueObservingOptionInitial context:KVO];
	
	// Do initial syntax coloring of our file
	[self recolorCompleteFile:nil];
	
	// Text view selects at end of text, use something more sensible
	NSRange startSelRange = [self defaultSelectedRange];
	self.view.selectedRange = startSelRange;
    
    // Set up line numbering
    self.view.enclosingScrollView.verticalRulerView = [[ASKLineNumberView alloc] initWithScrollView:self.view.enclosingScrollView];
    self.showsLineNumbers = self.showsLineNumbers;
	
    // Updates active line number
    [self textViewDidChangeSelection:[NSNotification notificationWithName:nil object:self.view]];
	
    self.view.usesFindPanel = YES;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
    [self removeObserver:self forKeyPath:@"view.font" context:KVO];
    
    self.view.enclosingScrollView.verticalRulerView = nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if(context != KVO) {
        return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    
    if([keyPath isEqualToString:@"view.font"]) {
        [self updateParagraphStyleTabDepth];
    }
}

@dynamic view;

- (void)setView:(NSTextView*)theView {
    super.view = theView;
	
	theView.delegate = self;
	[self setUpSyntaxColoring];	// TODO: If someone calls this twice, we should only call part of this twice!
}

- (void)processEditing:(NSNotification*)notification {
    NSTextStorage	* textStorage = notification.object;
	NSRange range = textStorage.editedRange;
	NSUInteger changeInLen = textStorage.changeInLength;
	BOOL textLengthMayHaveChanged = NO;
	
	// Was delete op or undo that could have changed text length?
	if(self.undoManager.isUndoing || self.undoManager.isRedoing) {
		textLengthMayHaveChanged = YES;
		range = self.view.selectedRange;
	}
	if(changeInLen <= 0) {
		textLengthMayHaveChanged = YES;
    }
	
	// Try to get chars around this to recolor any identifier we're in:
	if(textLengthMayHaveChanged) {
		if(range.location > 0) {
			range.location--;
        }
        
		if((range.location + range.length + 2) < textStorage.length) {
			range.length += 2;
        }
		else if((range.location +range.length + 1) < textStorage.length) {
			range.length += 1;
        }
	}
	
	NSRange currRange = range;
    
	// Perform the syntax coloring:
	if( range.length > 0 ) {
		NSRange effectiveRange;
		ASKSyntaxComponent * rangeMode = [textStorage attribute:ASKSyntaxComponentAttributeName atIndex:currRange.location effectiveRange:&effectiveRange];
		
		NSUInteger i = range.location;
		
		/* TODO: If we're in a multi-line comment and we're typing a comment-end
			character, or we're in a string and we're typing a quote character,
			this should include the rest of the text up to the next comment/string
			end character in the recalc. */
		
		// Scan up to prev line break:
		while(i > 0) {
			if([self newlineAtIndex:i ofString:textStorage.string]) {
				break;
            }
			--i;
		}
		
		currRange.location = i;
		
		// Scan up to next line break:
		i = range.location + range.length;
		
		while(i < textStorage.length) {
			if([self newlineAtIndex:i ofString:textStorage.string]) {
				break;
            }
			++i;
		}
		
		currRange.length = i - currRange.location;
		
		// Open identifier, comment etc.? Make sure we include the whole range.
		if(rangeMode != nil) {
			currRange = NSUnionRange(currRange, effectiveRange);
        }
		
		// Actually recolor the changed part:
		[self recolorRange:currRange];
	}
}

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString {
    if([self.delegate respondsToSelector:@selector(textView:shouldChangeTextInRange:replacementString:)]) {
        if(![self.delegate textView:textView shouldChangeTextInRange:affectedCharRange replacementString:replacementString]) {
            return NO;
        }
    }
    
	if(self.maintainIndentation) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Queue this up on the event loop. If we change the text here, we only confuse the undo stack.
            [self didChangeTextInRange:affectedCharRange replacementString:replacementString];
        });
	}
	
	return YES;
}

- (void)didChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString*)replacementString {
    if(!self.maintainIndentation) {
        return;
    }
    if(![replacementString isEqualToString:@"\n"] && ![replacementString isEqualToString:@"\r"]) {
        return;
    }
    
    BOOL hadSpaces = NO;
    NSUInteger lastSpace = affectedCharRange.location, prevLineBreak = 0;
    NSUInteger i = (affectedCharRange.location == 0) ? 0 : affectedCharRange.location - 1;
    NSString * tsString = self.view.textStorage.string;
    
    while(YES) {
        if(i > (tsString.length - 1)) {
            break;
        }
        
        unichar theChar = [tsString characterAtIndex:i];
        
        switch(theChar) {
            case '\n':
            case '\r':
                prevLineBreak = i + 1;
                i = 0;  // Terminate the loop.
                break;
            
            case ' ':
            case '\t':
                if(!hadSpaces) {
                    lastSpace = i;
                    hadSpaces = YES;
                }
                break;
            
            default:
                hadSpaces = NO;
                break;
        }
        
        if(i == 0) {
            break;
        }
        
        i--;
    }
    
    NSRange spacesRange = { 0, 0 };
    
    if(hadSpaces) {
        spacesRange.location = prevLineBreak;
        spacesRange.length = lastSpace - prevLineBreak + 1;
        
        if(spacesRange.length > 0) {
            [self.view insertText:[tsString substringWithRange:spacesRange]];
        }
    }
}

- (IBAction)toggleMaintainIndentation:(id)sender {
	self.maintainIndentation = !self.maintainIndentation;
    [self propagateValue:@(self.maintainIndentation) forBinding:@"maintainIndentation"];
}

- (void)goToLine:(NSUInteger)lineNum {
	NSRange	 theRange = { 0, 0 };
	NSString * vString = self.view.string;
	NSUInteger currLine = 1;
	NSUInteger lastBreakOffs = 0;
	unichar lastBreakChar = 0;
	
	for(NSUInteger i = 0; i < vString.length; i++ ) {
		// Skip non-linebreak chars:
		if(![self newlineAtIndex:i ofString:vString]) {
			continue;
        }
        
        unichar theCh = [vString characterAtIndex:i];
		
		// If this is the LF in a CRLF sequence, only count it as one line break:
		if(theCh == '\n' && lastBreakOffs == (i - 1) && lastBreakChar == '\r') {
			lastBreakOffs = 0;
			lastBreakChar = 0;
			theRange.location++;
			continue;
		}
		
		// Calc range and increase line number:
		theRange.length = i - theRange.location + 1;
		if(currLine >= lineNum) {
			break;
        }
		currLine++;
		theRange.location = theRange.location +theRange.length;
		lastBreakOffs = i;
		lastBreakChar = theCh;
	}
	
	[self.view scrollRangeToVisible:theRange];
	self.view.selectedRange = theRange;
}

- (void)goToCharacter:(NSUInteger)charNum {
	[self goToRangeFrom:charNum toChar:charNum + 1];
}

- (void)goToRangeFrom:(NSUInteger)startCh toChar:(NSUInteger)endCh {
	NSRange theRange = { 0, 0 };
    
	theRange.location = startCh - 1;
	theRange.length = endCh - startCh;
	
	if(startCh == 0 || startCh > self.view.string.length) {
		return;
    }
	
	[self.view scrollRangeToVisible: theRange];
	self.view.selectedRange = theRange;
}

- (void)setWrapsLines:(BOOL)wrap {
    _wrapsLines = wrap;
    
	NSScrollView * textScrollView = self.view.enclosingScrollView;
	NSSize contentSize = textScrollView.contentSize;
	NSTextContainer * textContainer = self.view.textContainer;
    
    self.view.minSize = contentSize;
    
	if (wrap) {
        // Turn off now-unnecessary scroller:
        textScrollView.hasHorizontalScroller = NO;
        
        // Make text container width match text view:
        textContainer.containerSize = NSMakeSize(contentSize.width, CGFLOAT_MAX);
        textContainer.widthTracksTextView = YES;
        
        // Make sure text view width matches scroll view:
        self.view.maxSize = NSMakeSize(contentSize.width, CGFLOAT_MAX);
        self.view.horizontallyResizable = NO;
        self.view.autoresizingMask = NSViewWidthSizable;
	}
    else {        
        // Make sure we can see right edge of line:
        textScrollView.hasHorizontalScroller = YES;
        
        // Make text container so wide it won't wrap:
        textContainer.containerSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
        textContainer.widthTracksTextView = NO;
        
        // Make sure text view is wide enough:
        self.view.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
        self.view.horizontallyResizable = YES;
        self.view.autoresizingMask = NSViewNotSizable;
	}
}

- (void)toggleWrapsLines:(id)sender {
    self.wrapsLines = !self.wrapsLines;
    [self propagateValue:@(self.wrapsLines) forBinding:@"wrapsLines"];
}

- (void)restoreText:(NSString*)textToRestore {
    //		Main bottleneck for our (very primitive and inefficient) undo
    //		implementation. This takes a copy of the previous state of the
    //		*entire text* and restores it.
    
	[self.undoManager disableUndoRegistration];
	self.view.string = textToRestore;
	[self.undoManager enableUndoRegistration];
}

- (void)withUndo:(dispatch_block_t)block {
    [self.undoManager beginUndoGrouping];
    
	NSString * prevText = [self.view.textStorage.string copy];
    [[self.undoManager prepareWithInvocationTarget:self] restoreText:prevText];
    
    block();
    
    [self.undoManager endUndoGrouping];
}

- (BOOL)newlineAtIndex:(NSUInteger)index ofString:(NSString*)string {
    unichar ch = [string characterAtIndex:index];
    return ch == '\n' || ch == '\r';
}

- (NSRange)rangeExcludingTrailingNewline:(NSRange)selRange fromString:(NSString*)str {
    if(selRange.length > 1) {
        if([self newlineAtIndex:NSMaxRange(selRange) - 1 ofString:str]) {
            selRange.length--;
        }
    }
    return selRange;
}

- (IBAction)indentSelection:(id)sender {
	[self withUndo:^{
        NSRange selRange = self.view.selectedRange, nuSelRange = selRange;
        NSMutableString * str = self.view.textStorage.mutableString;
        
        // Unselect any trailing returns so we don't indent the next line after a full-line selection.
        selRange = [self rangeExcludingTrailingNewline:selRange fromString:str];
        
        for(NSUInteger i = NSMaxRange(selRange) - 1; i >= selRange.location; i--) {
            if([self newlineAtIndex:i ofString:str]) {
                [str insertString:[self indentation] atIndex:i + 1];
                nuSelRange.length++;
            }
            
            if(i == 0) {
                break;
            }
        }
        
        [str insertString:[self indentation] atIndex:nuSelRange.location];
        nuSelRange.length++;
        
        self.view.selectedRange = nuSelRange;
    }];
}

- (IBAction)unindentSelection:(id)sender {
	__block NSRange selRange = self.view.selectedRange, nuSelRange = selRange;
	NSUInteger lastIndex = selRange.location + selRange.length - 1;
	NSMutableString * str = self.view.textStorage.mutableString;
	
	// Unselect any trailing returns so we don't indent the next line after a full-line selection.
    selRange = [self rangeExcludingTrailingNewline:selRange fromString:str];
	
	if(selRange.length == 0) {
		return;
    }
	
	[self withUndo:^{
        for(NSUInteger i = lastIndex; i >= selRange.location; i--) {
            if([self newlineAtIndex:i ofString:str]) {
                if((i + 1) <= lastIndex) {
                    if([str characterAtIndex:i + 1] == '\t') {
                        [str deleteCharactersInRange:NSMakeRange(i + 1, 1)];
                        nuSelRange.length--;
                    }
                    else {
                        for(NSUInteger j = i + 1; (j <= (i + 4 /* XXX */)) && (j <= lastIndex); j++ )
                        {
                            if([str characterAtIndex:i + 1] != ' ') {
                                break;
                            }
                            [str deleteCharactersInRange:NSMakeRange(i + 1, 1)];
                            nuSelRange.length--;
                        }
                    }
                }
            }
            
            if(i == 0) {
                break;
            }
        }
        
        if([str characterAtIndex:nuSelRange.location] == '\t') {
            [str deleteCharactersInRange:NSMakeRange(nuSelRange.location, 1)];
            nuSelRange.length--;
        }
        else {
            for(NSUInteger n = 1; (n <= 4 /* XXX */) && (n <= lastIndex); n++) {
                if([str characterAtIndex: nuSelRange.location] != ' ') {
                    break;
                }
                [str deleteCharactersInRange:NSMakeRange(nuSelRange.location, 1)];
                nuSelRange.length--;
            }
        }
        
        self.view.selectedRange = nuSelRange;
    }];
}

- (IBAction)toggleCommentForSelection:(id)sender {
	__block NSRange selRange = self.view.selectedRange;
	NSMutableString * str = self.view.textStorage.mutableString;
	
	if(selRange.length == 0) {
		selRange.length++;
    }
	
	// Are we at the end of a line?
	if ([self newlineAtIndex:selRange.location ofString:str]) {
		if(selRange.location > 0) {
			selRange.location--;
			selRange.length++;
		}
	}
	
	// Move the selection to the start of a line
	while(selRange.location > 0) {
		if([self newlineAtIndex:selRange.location ofString:str]) {
			selRange.location++;
			selRange.length--;
			break;
		}
		selRange.location--;
		selRange.length++;
	}

	// Select up to the end of a line
	while (NSMaxRange(selRange) < str.length && ![self newlineAtIndex:NSMaxRange(selRange) - 1 ofString:str]) {
		selRange.length++;
	}
	
	if (selRange.length == 0) {
		return;
    }
	
	[self withUndo:^{
        // Unselect any trailing returns so we don't comment the next line after a full-line selection.
        selRange = [self rangeExcludingTrailingNewline:selRange fromString:str];
        
        NSRange nuSelRange = selRange;
        
        NSString * commentPrefix = self.syntax.oneLineCommentPrefix;
        if(!commentPrefix || [commentPrefix length] == 0) {
            commentPrefix = @"# ";
        }
        
        NSUInteger commentPrefixLength = commentPrefix.length;
        NSString * trimmedCommentPrefix = [commentPrefix stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        if(!trimmedCommentPrefix || trimmedCommentPrefix.length == 0 ) {
            // Comments apparently *are* whitespace.
            trimmedCommentPrefix = commentPrefix;
        }
        
        NSUInteger trimmedCommentPrefixLength = trimmedCommentPrefix.length;
        
        for(NSUInteger i = selRange.location + selRange.length - 1; i >= selRange.location; i--) {
            BOOL hitEnd = (i == selRange.location);
            BOOL hitLineBreak = [self newlineAtIndex:i ofString:str];
            
            if(hitLineBreak || hitEnd) {
                NSUInteger	startOffs = i + 1;
                if(hitEnd && !hitLineBreak) {
                    startOffs = i;
                }
                
                NSUInteger possibleCommentLength = 0;
                if(commentPrefixLength <= (selRange.length + selRange.location - startOffs)) {
                    possibleCommentLength = commentPrefixLength;
                }
                else if(trimmedCommentPrefixLength <= (selRange.length + selRange.location - startOffs)) {
                    possibleCommentLength = trimmedCommentPrefixLength;
                }
                
                NSString	* lineStart = [str substringWithRange: NSMakeRange(startOffs, possibleCommentLength)];
                BOOL haveWhitespaceToo = [lineStart hasPrefix:commentPrefix];
                
                if([lineStart hasPrefix:trimmedCommentPrefix]) {
                    NSInteger commentLength = haveWhitespaceToo ? commentPrefixLength : trimmedCommentPrefixLength;
                    [str deleteCharactersInRange: NSMakeRange(startOffs, commentLength)];
                    nuSelRange.length -= commentLength;
                }
                else {
                    [str insertString:commentPrefix atIndex:startOffs];
                    nuSelRange.length += commentPrefixLength;
                }
            }
            
            if(i == 0) {
                break;
            }
        }
        
        self.view.selectedRange = nuSelRange;
    }];
}

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem {
	if(menuItem.action == @selector(toggleMaintainIndentation:)) {
		menuItem.state = self.maintainIndentation;
		return YES;
	}
    else if(menuItem.action == @selector(toggleWrapsLines:)) {
        menuItem.state = self.wrapsLines;
        return YES;
    }
    else if(menuItem.action == @selector(takeTabDepth:)) {
        menuItem.state = (self.tabDepth == menuItem.tag);
        return YES;
    }
    else if(menuItem.action == @selector(toggleIndentsWithSpaces:)) {
        menuItem.state = self.indentsWithSpaces;
        return YES;
    }
    else if(menuItem.action == @selector(toggleShowsLineNumbers:)) {
        menuItem.state = self.showsLineNumbers;
        return YES;
    }
	else {
		return [super validateMenuItem:menuItem];
    }
}

- (IBAction)recolorCompleteFile:(id)sender {
	NSRange range = NSMakeRange(0, self.view.textStorage.length);
	[self recolorRange: range];
}

-(void)recolorRange:(NSRange)range {	
    //		The range passed in here is special, and may not include partial
    //		identifiers or the end of a comment. Make sure you include the entire
    //		multi-line comment etc. or it'll lose color.
    
	if(self.view == nil || range.length == 0 )	{
        // Don't like doing useless stuff.
		return;
    }
    
    if(self.recoloring) {
        // Prevent endless loop when recoloring's changes cause processEditing to fire again.
        return;
    }
    
    if(self.syntax) {
        self.recoloring = YES;
        if([self.delegate respondsToSelector:@selector(syntaxViewController:willColorRange:)]) {
            [self.delegate syntaxViewController:self willColorRange:range];
        }
        
        [self.syntax.marker markRange:range ofAttributedString:self.view.textStorage withUserIdentifiers:self.userIdentifiers];
        
        self.syntaxColorist.colorPalette = self.colorPalette;
        [self.syntaxColorist colorRange:range ofTextStorage:self.view.textStorage withDefaultAttributes:self.defaultTextAttributes];
        
        if([self.delegate respondsToSelector:@selector(syntaxViewController:didColorRange:)]) {
            [self.delegate syntaxViewController:self didColorRange:range];
        }
        self.recoloring = NO;
    }
    else {
        [self.view.textStorage setAttributes:self.defaultTextAttributes range:range];
    }

    [self textViewDidChangeSelection:[NSNotification notificationWithName:nil object:self.view]];
}

- (NSDictionary *)syntaxColorist:(ASKSyntaxColorist *)syntaxColorist textAttributesForSyntaxComponent:(ASKSyntaxComponent *)component color:(NSColor *)color {
    if([self.delegate respondsToSelector:@selector(syntaxViewController:syntax:textAttributesForSyntaxComponent:color:)]) {
        return [self.delegate syntaxViewController:self syntax:self.syntax textAttributesForSyntaxComponent:component color:color];
    }
    else {
        return nil;
    }
}

- (void)textViewDidChangeSelection:(NSNotification *)notification {
    NSTextView * textView = notification.object;
    
    // Update lineNumberView's highlighted lines
    ASKLocation startLocation = textView.locationOfBeginningOfSelection;
    ASKLocation endLocation = textView.locationOfEndOfSelection;
	
    self.lineNumberView.rangeOfHighlightedLineNumbers = NSMakeRange(startLocation.line, endLocation.line - startLocation.line + 1);
    
    if([self.delegate respondsToSelector:@selector(textViewDidChangeSelection:)]) {
        [self.delegate textViewDidChangeSelection:notification];
    }
}

- (NSDictionary*)defaultTextAttributes {
	return @{ NSFontAttributeName: self.view.font, NSParagraphStyleAttributeName: self.view.defaultParagraphStyle };
}

- (NSRange)defaultSelectedRange {
	return NSMakeRange(0,0);
}

- (void)setTabDepth:(NSUInteger)tabDepth {
    _tabDepth = tabDepth;
    [self updateParagraphStyleTabDepth];
}

- (void)takeTabDepth:(id)sender {
    self.tabDepth = [sender tag];
    [self propagateValue:@(self.tabDepth) forBinding:@"tabDepth"];
}

- (void)updateParagraphStyleTabDepth {
    if(!self.view.font) {
        return;
    }
    
    NSMutableParagraphStyle * style = [self.view.defaultParagraphStyle ?: [NSParagraphStyle defaultParagraphStyle] mutableCopy];
    
    style.defaultTabInterval = [[self.view.layoutManager substituteFontForFont:self.view.font] advancementForGlyph:(NSGlyph)' '].width * self.tabDepth;

    style.tabStops = @[];
    for(NSUInteger i = 1; i <= 20 /* if you need deeper indentation, you go to hell. you go to hell and you die */; i++) {
        NSTextTab * tab = [[NSTextTab alloc] initWithType:NSLeftTabStopType location:style.defaultTabInterval * i];
        NSAssert(tab.location != 0, @"Zero tab stop");
        [style addTabStop:tab];
    }    
    
    self.view.defaultParagraphStyle = style;
    
    [self.view.layoutManager invalidateLayoutForCharacterRange:NSMakeRange(0, self.view.textStorage.length) actualCharacterRange:NULL];
}

- (void)toggleIndentsWithSpaces:(id)sender {
    self.indentsWithSpaces = !self.indentsWithSpaces;
    [self propagateValue:@(self.indentsWithSpaces) forBinding:@"indentsWithSpaces"];
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if([self.delegate respondsToSelector:@selector(textView:doCommandBySelector:)]) {
        if([self.delegate textView:textView doCommandBySelector:commandSelector]) {
            return YES;
        }
    }
    
    if(commandSelector == @selector(insertTab:)) {
        [textView insertText:[self indentation]];
        return YES;
    }
    return NO;
}

- (NSString*)indentation {
    if(!self.indentsWithSpaces) {
        return @"\t";
    }
    
    NSMutableString * str = [NSMutableString new];
    for(NSUInteger i = 0; i < self.tabDepth; i++) {
        [str appendString:@" "];
    }
    return str;
}

- (void)setShowsLineNumbers:(BOOL)showsLineNumbers {
    _showsLineNumbers = showsLineNumbers;
    
    self.view.enclosingScrollView.rulersVisible = self.showsLineNumbers;
}

- (void)toggleShowsLineNumbers:(id)sender {
    self.showsLineNumbers = !self.showsLineNumbers;
    [self propagateValue:@(self.showsLineNumbers) forBinding:@"showsLineNumbers"];
}

- (ASKLineNumberView *)lineNumberView {
    return (id)self.view.enclosingScrollView.verticalRulerView;
}

// Chaining to delegates

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    NSMethodSignature * sig = [super methodSignatureForSelector:aSelector];
    
    if(!sig) {
        struct objc_method_description method = protocol_getMethodDescription(@protocol(NSTextViewDelegate), aSelector, NO, YES);
        if(!method.name) {
            method = protocol_getMethodDescription(@protocol(ASKSyntaxColoristDelegate), aSelector, NO, YES);
        }
        
        if(method.name && [self.delegate respondsToSelector:aSelector]) {
            sig = [NSMethodSignature signatureWithObjCTypes:method.types];
        }
    }
    
    return sig;
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    return self.delegate;
}

@end
