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

// -----------------------------------------------------------------------------
//	Globals:
// -----------------------------------------------------------------------------

static BOOL			sSyntaxColoredTextDocPrefsInited = NO;

@interface ASKSyntaxViewController () <ASKSyntaxDelegate>

+(void) 	makeSurePrefsAreInited;		// No need to call this.

-(void) recolorRange: (NSRange) range;

@end


// -----------------------------------------------------------------------------
//	Macros:
// -----------------------------------------------------------------------------

@implementation ASKSyntaxViewController {
	NSRange								affectedCharRange;
	NSString*							replacementString;
}

- (void)setSyntax:(ASKSyntax *)syntax {
    self.syntax.delegate = nil;
    _syntax = syntax;
    self.syntax.delegate = self;
    
    [self recolorCompleteFile:nil];
}

- (NSTextView*)view {
    return (NSTextView*)[super view];
}

// -----------------------------------------------------------------------------
//	makeSurePrefsAreInited
//		Called by each view on creation to make sure we load the default colors
//		and user-defined identifiers from SyntaxColorDefaults.plist.
// -----------------------------------------------------------------------------

+(void) makeSurePrefsAreInited
{
	if( !sSyntaxColoredTextDocPrefsInited )
	{
		NSUserDefaults*	prefs = [NSUserDefaults standardUserDefaults];
        [prefs registerDefaults:[NSDictionary dictionaryWithContentsOfURL:[[NSBundle bundleForClass:self] URLForResource:@"SyntaxColorDefaults" withExtension:@"plist"]]];

		sSyntaxColoredTextDocPrefsInited = YES;
	}
}


// -----------------------------------------------------------------------------
//	initWithNibName:bundle:
//		Constructor that inits sourceCode member variable as a flag. It's
//		storage for the text until the NIB's been loaded.
// -----------------------------------------------------------------------------

- (void)prep {
    _maintainIndentation = YES;
    _wrapsLines = NO;
    _tabDepth = 4;
}

-(id)	initWithNibName: (NSString*)inNibName bundle: (NSBundle*)inBundle
{
    self = [super initWithNibName: inNibName bundle: inBundle];
    if( self )
	{
        [self prep];
	}
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if( self )
    {
        [self prep];
    }
    return self;
}

-(void)	dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
    [self removeObserver:self forKeyPath:@"view.font" context:KVO];
    
    self.view.enclosingScrollView.verticalRulerView = nil;
}


-(void)	setUpSyntaxColoring
{
	// Set up some sensible defaults for syntax coloring:
	[[self class] makeSurePrefsAreInited];
        
    self.view.layoutManager.typesetter = [ASKTypesetter new];
	
	// Register for "text changed" notifications of our text storage:
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(processEditing:)
					name: NSTextStorageDidProcessEditingNotification
					object: [[self view] textStorage]];
	
	// Make sure text isn't wrapped:
	[self setWrapsLines:self.wrapsLines];
    
    // Set up tab depth
    [self addObserver:self forKeyPath:@"view.font" options:NSKeyValueObservingOptionInitial context:KVO];
	
	// Do initial syntax coloring of our file:
	[self recolorCompleteFile: nil];
	
	// Text view selects at end of text, use something more sensible:
	NSRange		startSelRange = [self defaultSelectedRange];
	[[self view] setSelectedRange: startSelRange];
    
    self.view.enclosingScrollView.verticalRulerView = [[ASKLineNumberView alloc] initWithScrollView:self.view.enclosingScrollView];
    self.showsLineNumbers = self.showsLineNumbers;
	
    [self textViewDidChangeSelection:[NSNotification notificationWithName:nil object:self.view]];
	
	// Make sure we can use "find" if we're on 10.3:
	if( [[self view] respondsToSelector: @selector(setUsesFindPanel:)] )
		[[self view] setUsesFindPanel: YES];
}

static void * const KVO = (void*)&KVO;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if(context != KVO) {
        return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    
    if([keyPath isEqualToString:@"view.font"]) {
        [self updateParagraphStyleTabDepth];
    }
}


// -----------------------------------------------------------------------------
//	setView:
//		We've just been given a view! Apply initial syntax coloring.
// -----------------------------------------------------------------------------

@dynamic view;

-(void)	setView: (NSTextView*)theView
{
    [super setView: theView];
	
	[theView setDelegate: self];
	[self setUpSyntaxColoring];	// TODO: If someone calls this twice, we should only call part of this twice!
}


// -----------------------------------------------------------------------------
//	processEditing:
//		Part of the text was changed. Recolor it.
// -----------------------------------------------------------------------------

-(void) processEditing: (NSNotification*)notification
{
    NSTextStorage	*textStorage = [notification object];
	NSRange			range = [textStorage editedRange];
	NSUInteger		changeInLen = [textStorage changeInLength];
	BOOL			wasInUndoRedo = [[self undoManager] isUndoing] || [[self undoManager] isRedoing];
	BOOL			textLengthMayHaveChanged = NO;
	
	// Was delete op or undo that could have changed text length?
	if( wasInUndoRedo )
	{
		textLengthMayHaveChanged = YES;
		range = [[self view] selectedRange];
	}
	if( changeInLen <= 0 )
		textLengthMayHaveChanged = YES;
	
	//	Try to get chars around this to recolor any identifier we're in:
	if( textLengthMayHaveChanged )
	{
		if( range.location > 0 )
			range.location--;
		if( (range.location +range.length +2) < [textStorage length] )
			range.length += 2;
		else if( (range.location +range.length +1) < [textStorage length] )
			range.length += 1;
	}
	
	NSRange						currRange = range;
    
	// Perform the syntax coloring:
	if( range.length > 0 )
	{
		NSRange			effectiveRange;
		NSString*		rangeMode;
		
		
		rangeMode = [textStorage attribute: ASKSyntaxModeAttributeName
								atIndex: currRange.location
								effectiveRange: &effectiveRange];
		
		NSUInteger		x = range.location;
		
		/* TODO: If we're in a multi-line comment and we're typing a comment-end
			character, or we're in a string and we're typing a quote character,
			this should include the rest of the text up to the next comment/string
			end character in the recalc. */
		
		// Scan up to prev line break:
		while( x > 0 )
		{
			unichar theCh = [[textStorage string] characterAtIndex: x];
			if( theCh == '\n' || theCh == '\r' )
				break;
			--x;
		}
		
		currRange.location = x;
		
		// Scan up to next line break:
		x = range.location +range.length;
		
		while( x < [textStorage length] )
		{
			unichar theCh = [[textStorage string] characterAtIndex: x];
			if( theCh == '\n' || theCh == '\r' )
				break;
			++x;
		}
		
		currRange.length = x -currRange.location;
		
		// Open identifier, comment etc.? Make sure we include the whole range.
		if( rangeMode != nil )
			currRange = NSUnionRange( currRange, effectiveRange );
		
		// Actually recolor the changed part:
		[self recolorRange: currRange];
	}
}


// -----------------------------------------------------------------------------
//	textView:shouldChangeTextinRange:replacementString:
//		Perform indentation-maintaining if we're supposed to.
// -----------------------------------------------------------------------------

-(BOOL) textView:(NSTextView *)tv shouldChangeTextInRange:(NSRange)afcr replacementString:(NSString *)rps
{
    if([self.delegate respondsToSelector:@selector(textView:shouldChangeTextInRange:replacementString:)]) {
        if(![self.delegate textView:tv shouldChangeTextInRange:afcr replacementString:rps]) {
            return NO;
        }
    }
    
	if( self.maintainIndentation )
	{
		affectedCharRange = afcr;
		replacementString = rps;
		
		[self performSelector: @selector(didChangeText) withObject: nil afterDelay: 0.0];	// Queue this up on the event loop. If we change the text here, we only confuse the undo stack.
	}
	
	return YES;
}


-(void)	didChangeText	// This actually does what we want to do in textView:shouldChangeTextInRange:
{
	if( self.maintainIndentation && replacementString && ([replacementString isEqualToString:@"\n"]
		|| [replacementString isEqualToString:@"\r"]) )
	{
		NSMutableAttributedString*  textStore = [[self view] textStorage];
		BOOL						hadSpaces = NO;
		NSUInteger					lastSpace = affectedCharRange.location,
									prevLineBreak = 0;
		NSRange						spacesRange = { 0, 0 };
		unichar						theChar = 0;
		NSUInteger					x = (affectedCharRange.location == 0) ? 0 : affectedCharRange.location -1;
		NSString*					tsString = [textStore string];
		
		while( YES )
		{
			if( x > ([tsString length] -1) )
				break;
			
			theChar = [tsString characterAtIndex: x];
			
			switch( theChar )
			{
				case '\n':
				case '\r':
					prevLineBreak = x +1;
					x = 0;  // Terminate the loop.
					break;
				
				case ' ':
				case '\t':
					if( !hadSpaces )
					{
						lastSpace = x;
						hadSpaces = YES;
					}
					break;
				
				default:
					hadSpaces = NO;
					break;
			}
			
			if( x == 0 )
				break;
			
			x--;
		}
		
		if( hadSpaces )
		{
			spacesRange.location = prevLineBreak;
			spacesRange.length = lastSpace -prevLineBreak +1;
			if( spacesRange.length > 0 )
				[[self view] insertText: [tsString substringWithRange:spacesRange]];
		}
	}
}


// -----------------------------------------------------------------------------
//	toggleMaintainIndentation:
//		Action for menu item that toggles indentation maintaining on and off.
// -----------------------------------------------------------------------------

-(IBAction)	toggleMaintainIndentation: (id)sender
{
	[self setMaintainIndentation: ![self maintainIndentation]];
    [self propagateValue:@(self.maintainIndentation) forBinding:@"maintainIndentation"];
}


// -----------------------------------------------------------------------------
//	goToLine:
//		This selects the specified line of the document.
// -----------------------------------------------------------------------------

-(void)	goToLine: (NSUInteger)lineNum
{
	NSRange			theRange = { 0, 0 };
	NSString*		vString = [[self view] string];
	NSUInteger		currLine = 1;
	NSCharacterSet* vSet = [NSCharacterSet characterSetWithCharactersInString: @"\n\r"];
	unsigned		x;
	unsigned		lastBreakOffs = 0;
	unichar			lastBreakChar = 0;
	
	for( x = 0; x < [vString length]; x++ )
	{
		unichar		theCh = [vString characterAtIndex: x];
		
		// Skip non-linebreak chars:
		if( ![vSet characterIsMember: theCh] )
			continue;
		
		// If this is the LF in a CRLF sequence, only count it as one line break:
		if( theCh == '\n' && lastBreakOffs == (x-1)
			&& lastBreakChar == '\r' )
		{
			lastBreakOffs = 0;
			lastBreakChar = 0;
			theRange.location++;
			continue;
		}
		
		// Calc range and increase line number:
		theRange.length = x -theRange.location +1;
		if( currLine >= lineNum )
			break;
		currLine++;
		theRange.location = theRange.location +theRange.length;
		lastBreakOffs = x;
		lastBreakChar = theCh;
	}
	
	[[self view] scrollRangeToVisible: theRange];
	[[self view] setSelectedRange: theRange];
}


// -----------------------------------------------------------------------------
//	turnOffWrapping
//		Makes the view so wide that text won't wrap anymore.
// -----------------------------------------------------------------------------

- (void)setWrapsLines:(BOOL)wrap
{
    _wrapsLines = wrap;
    
	NSScrollView *textScrollView = [[self view] enclosingScrollView];
	NSSize contentSize = [textScrollView contentSize];
	[[self view] setMinSize:contentSize];
	NSTextContainer *textContainer = [[self view] textContainer];
    
	if (wrap) {
        // Turn off now-unnecessary scroller:
        [textScrollView setHasHorizontalScroller: NO];
        
        // Make text container width match text view:
        [textContainer setContainerSize: NSMakeSize(contentSize.width, CGFLOAT_MAX)];
        [textContainer setWidthTracksTextView: YES];
        
        // Make sure text view width matches scroll view:
        [[self view] setMaxSize: NSMakeSize(contentSize.width, CGFLOAT_MAX)];
        [[self view] setHorizontallyResizable: NO];
        [[self view] setAutoresizingMask: NSViewWidthSizable];
	} else {        
        // Make sure we can see right edge of line:
        [textScrollView setHasHorizontalScroller: YES];
        
        // Make text container so wide it won't wrap:
        [textContainer setContainerSize: NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
        [textContainer setWidthTracksTextView: NO];
        
        // Make sure text view is wide enough:
        [[self view] setMaxSize: NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
        [[self view] setHorizontallyResizable: YES];
        [[self view] setAutoresizingMask: NSViewNotSizable];
	}
    
}

- (void)toggleWrapsLines:(id)sender {
    self.wrapsLines = !self.wrapsLines;
    [self propagateValue:@(self.wrapsLines) forBinding:@"wrapsLines"];
}


// -----------------------------------------------------------------------------
//	goToCharacter:
//		This selects the specified character in the document.
// -----------------------------------------------------------------------------

-(void)	goToCharacter: (NSUInteger)charNum
{
	[self goToRangeFrom: charNum toChar: charNum +1];
}


// -----------------------------------------------------------------------------
//	goToRangeFrom:toChar:
//		Main bottleneck for selecting ranges in our file.
// -----------------------------------------------------------------------------

-(void) goToRangeFrom: (NSUInteger)startCh toChar: (NSUInteger)endCh
{
	NSRange		theRange = { 0, 0 };

	theRange.location = startCh -1;
	theRange.length = endCh -startCh;
	
	if( startCh == 0 || startCh > [[[self view] string] length] )
		return;
	
	[[self view] scrollRangeToVisible: theRange];
	[[self view] setSelectedRange: theRange];
}


// -----------------------------------------------------------------------------
//	restoreText:
//		Main bottleneck for our (very primitive and inefficient) undo
//		implementation. This takes a copy of the previous state of the
//		*entire text* and restores it.
// -----------------------------------------------------------------------------

-(void)	restoreText: (NSString*)textToRestore
{
	[[self undoManager] disableUndoRegistration];
	[[self view] setString: textToRestore];
	[[self undoManager] enableUndoRegistration];
}


// -----------------------------------------------------------------------------
//	indentSelection:
//		Indent the selected lines by one more level (i.e. one more tab).
// -----------------------------------------------------------------------------

-(IBAction) indentSelection: (id)sender
{
	[[self undoManager] beginUndoGrouping];
	NSString*	prevText = [[[[self view] textStorage] string] copy];
	[[self undoManager] registerUndoWithTarget: self selector: @selector(restoreText:) object: prevText];
	
	NSRange				selRange = [[self view] selectedRange],
						nuSelRange = selRange;
	NSUInteger			x;
	NSMutableString*	str = [[[self view] textStorage] mutableString];
	
	// Unselect any trailing returns so we don't indent the next line after a full-line selection.
	if( selRange.length > 1 && ([str characterAtIndex: selRange.location +selRange.length -1] == '\n'
		|| [str characterAtIndex: selRange.location +selRange.length -1] == '\r') )
		selRange.length--;
	
	for( x = selRange.location +selRange.length -1; x >= selRange.location; x-- )
	{
		if( [str characterAtIndex: x] == '\n'
			|| [str characterAtIndex: x] == '\r' )
		{
			[str insertString:[self indentation] atIndex: x+1];
			nuSelRange.length++;
		}
		
		if( x == 0 )
			break;
	}
	
	[str insertString:[self indentation] atIndex: nuSelRange.location];
	nuSelRange.length++;
	[[self view] setSelectedRange: nuSelRange];
	[[self undoManager] endUndoGrouping];
}


// -----------------------------------------------------------------------------
//	unindentSelection:
//		Un-indent the selected lines by one level (i.e. remove one tab from each
//		line's start).
// -----------------------------------------------------------------------------

-(IBAction) unindentSelection: (id)sender
{
	NSRange				selRange = [[self view] selectedRange],
						nuSelRange = selRange;
	NSUInteger			x, n;
	NSUInteger			lastIndex = selRange.location +selRange.length -1;
	NSMutableString*	str = [[[self view] textStorage] mutableString];
	
	// Unselect any trailing returns so we don't indent the next line after a full-line selection.
	if( selRange.length > 1 && ([str characterAtIndex: selRange.location +selRange.length -1] == '\n'
		|| [str characterAtIndex: selRange.location +selRange.length -1] == '\r') )
		selRange.length--;
	
	if( selRange.length == 0 )
		return;
	
	[[self undoManager] beginUndoGrouping];
	NSString*	prevText = [[[[self view] textStorage] string] copy];
	[[self undoManager] registerUndoWithTarget: self selector: @selector(restoreText:) object: prevText];
		
	for( x = lastIndex; x >= selRange.location; x-- )
	{
		if( [str characterAtIndex: x] == '\n'
			|| [str characterAtIndex: x] == '\r' )
		{
			if( (x +1) <= lastIndex)
			{
				if( [str characterAtIndex: x+1] == '\t' )
				{
					[str deleteCharactersInRange: NSMakeRange(x+1,1)];
					nuSelRange.length--;
				}
				else
				{
					for( n = x+1; (n <= (x+4)) && (n <= lastIndex); n++ )
					{
						if( [str characterAtIndex: x+1] != ' ' )
							break;
						[str deleteCharactersInRange: NSMakeRange(x+1,1)];
						nuSelRange.length--;
					}
				}
			}
		}
		
		if( x == 0 )
			break;
	}
	
	if( [str characterAtIndex: nuSelRange.location] == '\t' )
	{
		[str deleteCharactersInRange: NSMakeRange(nuSelRange.location,1)];
		nuSelRange.length--;
	}
	else
	{
		for( n = 1; (n <= 4) && (n <= lastIndex); n++ )
		{
			if( [str characterAtIndex: nuSelRange.location] != ' ' )
				break;
			[str deleteCharactersInRange: NSMakeRange(nuSelRange.location,1)];
			nuSelRange.length--;
		}
	}
	
	[[self view] setSelectedRange: nuSelRange];
	[[self undoManager] endUndoGrouping];
}


// -----------------------------------------------------------------------------
//	toggleCommentForSelection:
//		Add a comment to the start of this line/remove an existing comment.
// -----------------------------------------------------------------------------

-(IBAction)	toggleCommentForSelection: (id)sender
{
	NSRange				selRange = [[self view] selectedRange];
	NSUInteger			x;
	NSMutableString*	str = [[[self view] textStorage] mutableString];
	
	if( selRange.length == 0 )
		selRange.length++;
	
	// Are we at the end of a line?
	if ([str characterAtIndex: selRange.location] == '\n' ||
			[str characterAtIndex: selRange.location] == '\r') 
	{
		if( selRange.location > 0 )
		{
			selRange.location--;
			selRange.length++;
		}
	}
	
	// Move the selection to the start of a line
	while( selRange.location > 0 )
	{
		if( [str characterAtIndex: selRange.location] == '\n'
			|| [str characterAtIndex: selRange.location] == '\r')
		{
			selRange.location++;
			selRange.length--;
			break;
		}
		selRange.location--;
		selRange.length++;
	}

	// Select up to the end of a line
	while ( (selRange.location +selRange.length) < [str length]  
				&& !([str characterAtIndex:selRange.location+selRange.length-1] == '\n' 
					|| [str characterAtIndex:selRange.location+selRange.length-1] == '\r') ) 
	{
		selRange.length++;
	}
	
	if (selRange.length == 0)
		return;
	
	[[self undoManager] beginUndoGrouping];
	NSString*	prevText = [[[[self view] textStorage] string] copy];
	[[self undoManager] registerUndoWithTarget: self selector: @selector(restoreText:) object: prevText];
	
	// Unselect any trailing returns so we don't comment the next line after a full-line selection.
	while( ([str characterAtIndex: selRange.location +selRange.length -1] == '\n' ||
				[str characterAtIndex: selRange.location +selRange.length -1] == '\r')
				&& selRange.length > 0 )
	{
		selRange.length--;
	}
	
	
	NSRange nuSelRange = selRange;
	
	NSString*	commentPrefix = self.syntax.definition[@"OneLineCommentPrefix"];
	if( !commentPrefix || [commentPrefix length] == 0 )
		commentPrefix = @"# ";
	NSUInteger	commentPrefixLength = [commentPrefix length];
	NSString*	trimmedCommentPrefix = [commentPrefix stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
	if( !trimmedCommentPrefix || [trimmedCommentPrefix length] == 0 )	// Comments apparently *are* whitespace.
		trimmedCommentPrefix = commentPrefix;
	NSUInteger	trimmedCommentPrefixLength = [trimmedCommentPrefix length];
	
	for( x = selRange.location +selRange.length -1; x >= selRange.location; x-- )
	{
		BOOL	hitEnd = (x == selRange.location);
		BOOL	hitLineBreak = [str characterAtIndex: x] == '\n' || [str characterAtIndex: x] == '\r';
		if( hitLineBreak || hitEnd )
		{
			NSUInteger	startOffs = x+1;
			if( hitEnd && !hitLineBreak )
				startOffs = x;
			NSUInteger	possibleCommentLength = 0;
			if( commentPrefixLength <= (selRange.length +selRange.location -startOffs) )
				possibleCommentLength = commentPrefixLength;
			else if( trimmedCommentPrefixLength <= (selRange.length +selRange.location -startOffs) )
				possibleCommentLength = trimmedCommentPrefixLength;
			
			NSString	*	lineStart = [str substringWithRange: NSMakeRange( startOffs, possibleCommentLength )];
			BOOL			haveWhitespaceToo = [lineStart hasPrefix: commentPrefix];
			if( [lineStart hasPrefix: trimmedCommentPrefix] )
			{
				NSInteger	commentLength = haveWhitespaceToo ? commentPrefixLength : trimmedCommentPrefixLength;
				[str deleteCharactersInRange: NSMakeRange(startOffs, commentLength)];
				nuSelRange.length -= commentLength;
			}
			else
			{
				[str insertString: commentPrefix atIndex: startOffs];
				nuSelRange.length += commentPrefixLength;
			}
		}
		
		if( x == 0 )
			break;
	}
	
	[[self view] setSelectedRange: nuSelRange];
	[[self undoManager] endUndoGrouping];
	
}


// -----------------------------------------------------------------------------
//	validateMenuItem:
//		Make sure check marks of the "Toggle auto syntax coloring" and "Maintain
//		indentation" menu items are set up properly.
// -----------------------------------------------------------------------------

-(BOOL)	validateMenuItem: (NSMenuItem*)menuItem
{
	if( [menuItem action] == @selector(toggleMaintainIndentation:) )
	{
		[menuItem setState: [self maintainIndentation]];
		return YES;
	}
    else if( [menuItem action] == @selector(toggleWrapsLines:)) {
        [menuItem setState: [self wrapsLines]];
        return YES;
    }
    else if( [menuItem action] == @selector(takeTabDepth:)) {
        [menuItem setState: (self.tabDepth == [menuItem tag]) ];
        return YES;
    }
    else if( [menuItem action] == @selector(toggleIndentsWithSpaces:)) {
        [menuItem setState: self.indentsWithSpaces];
        return YES;
    }
    else if( [menuItem action] == @selector(toggleShowsLineNumbers:) ) {
        [menuItem setState: self.showsLineNumbers];
        return YES;
    }
	else
		return [super validateMenuItem: menuItem];
}


// -----------------------------------------------------------------------------
//	recolorCompleteFile:
//		IBAction to do a complete recolor of the whole friggin' document.
//		This is called once after the document's been loaded and leaves some
//		custom styles in the document which are used by recolorRange to properly
//		perform recoloring of parts.
// -----------------------------------------------------------------------------

-(IBAction)	recolorCompleteFile: (id)sender
{
	NSRange		range = NSMakeRange( 0, [[[self view] textStorage] length] );
	[self recolorRange: range];
}


// -----------------------------------------------------------------------------
//	recolorRange:
//		Try to apply syntax coloring to the text in our text view. This
//		overwrites any styles the text may have had before. This function
//		guarantees that it'll preserve the selection.
//		
//		Note that the order in which the different things are colorized is
//		important. E.g. identifiers go first, followed by comments, since that
//		way colors are removed from identifiers inside a comment and replaced
//		with the comment color, etc. 
//		
//		The range passed in here is special, and may not include partial
//		identifiers or the end of a comment. Make sure you include the entire
//		multi-line comment etc. or it'll lose color.
// -----------------------------------------------------------------------------

-(void)		recolorRange: (NSRange)range
{	
	if(self.view == nil || range.length == 0 )	// Don't like doing useless stuff.
		return;
    
    if(self.syntax) {
        [self.syntax colorRange:range ofTextStorage:self.view.textStorage defaultAttributes:self.defaultTextAttributes];
    }
    else {
        [self.view.textStorage setAttributes:self.defaultTextAttributes range:range];
    }

    [self textViewDidChangeSelection:[NSNotification notificationWithName:nil object:self.view]];
}

- (void)syntaxWillColor:(ASKSyntax *)syntax {
    if([self.delegate respondsToSelector:@selector(syntaxViewController:syntaxWillColor:)]) {
        [self.delegate syntaxViewController:self syntaxWillColor:syntax];
    }
}

- (void)syntaxIsColoring:(ASKSyntax *)syntax {
    if([self.delegate respondsToSelector:@selector(syntaxViewController:syntaxIsColoring:)]) {
        [self.delegate syntaxViewController:self syntaxIsColoring:syntax];
    }
}

- (void)syntaxDidColor:(ASKSyntax *)syntax {
    if([self.delegate respondsToSelector:@selector(syntaxViewController:syntaxDidColor:)]) {
        [self.delegate syntaxViewController:self syntaxDidColor:syntax];
    }
}

- (NSArray *)syntax:(ASKSyntax *)syntax userIdentifiersForKeywordComponentName:(NSString *)inModeName {
    if([inModeName isEqualToString:@"UserIdentifiers"]) {
        return self.userIdentifiers;
    }
    
    NSLog(@"Unknown component name in -syntax:userIdentifiersForKeywordComponentName: %@", inModeName);
    
    return nil;
}

- (NSDictionary *)syntax:(ASKSyntax *)syntax textAttributesForComponentName:(NSString *)name color:(NSColor *)color {
    if([self.delegate respondsToSelector:@selector(syntaxViewController:syntax:textAttributesForComponentName:color:)]) {
        return [self.delegate syntaxViewController:self syntax:syntax textAttributesForComponentName:name color:color];
    }
    else {
        return nil;
    }
}

// -----------------------------------------------------------------------------
//	textViewDidChangeSelection:
//		Delegate method called when our selection changes. Updates our status
//		display to indicate which characters are selected.
// -----------------------------------------------------------------------------

- (void)textViewDidChangeSelection:(NSNotification *)notification {
    NSTextView * textView = notification.object;
    
    ASKLocation startLocation = textView.locationOfBeginningOfSelection;
    ASKLocation endLocation = textView.locationOfEndOfSelection;
	
    self.lineNumberView.rangeOfHighlightedLineNumbers = NSMakeRange(startLocation.line, endLocation.line - startLocation.line + 1);
    
    if([self.delegate respondsToSelector:@selector(textViewDidChangeSelection:)]) {
        [self.delegate textViewDidChangeSelection:notification];
    }
}

// -----------------------------------------------------------------------------
//	defaultTextAttributes
//		Return the text attributes to use for the text in our text view.
// -----------------------------------------------------------------------------

-(NSDictionary*)	defaultTextAttributes
{
	return @{ NSFontAttributeName: self.view.font, NSParagraphStyleAttributeName: self.view.defaultParagraphStyle };
}


// -----------------------------------------------------------------------------
//	defaultSelectedRange
//		Put selection at top like Project Builder has it, so user sees it. You
//		can also override this and save/restore the selection for each document.
// -----------------------------------------------------------------------------

-(NSRange)	defaultSelectedRange
{
	return NSMakeRange(0,0);
}

// Tab depth

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

// Indents with spaces

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

// Line numbers

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
            method = protocol_getMethodDescription(@protocol(ASKSyntaxDelegate), aSelector, NO, YES);
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
