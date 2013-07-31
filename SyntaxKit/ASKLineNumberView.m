//
//  ASKLineNumberView.m
//  Architechies SyntaxKit
//
//  Created by Paul Kim on 9/28/08.
//  NoodleKit Copyright (c) 2008-2012 Noodlesoft, LLC. All rights reserved.
//  SyntaxKit Copyright (c) 2013 Architechies. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//

#import "ASKLineNumberView.h"
#import "ASKLineNumberMarker.h"
#import <tgmath.h>

#define DEFAULT_THICKNESS	22.0
#define RULER_MARGIN		5.0

@interface ASKLineNumberView (Private)

- (NSFont *)defaultFont;
- (NSColor *)defaultTextColor;
- (NSColor *)defaultAlternateTextColor;
- (NSMutableArray *)lineIndices;
- (void)invalidateLineIndicesFromCharacterIndex:(NSUInteger)charIndex;
- (void)calculateLines;
- (NSUInteger)lineNumberForCharacterIndex:(NSUInteger)index inText:(NSString *)text;
- (NSDictionary *)textAttributes;
- (NSDictionary *)markerTextAttributes;

@end

@implementation ASKLineNumberView

@synthesize font = _font;
@synthesize textColor = _textColor;
@synthesize alternateTextColor = _alternateTextColor;
@synthesize backgroundColor = _backgroundColor;

- (id)initWithScrollView:(NSScrollView *)aScrollView
{
    if ((self = [super initWithScrollView:aScrollView orientation:NSVerticalRuler]) != nil)
    {
        _lineIndices = [[NSMutableArray alloc] init];
		_linesToMarkers = [[NSMutableDictionary alloc] init];
		
        [self setClientView:[aScrollView documentView]];
    }
    return self;
}

- (void)awakeFromNib
{
    _lineIndices = [[NSMutableArray alloc] init];
	_linesToMarkers = [[NSMutableDictionary alloc] init];
	[self setClientView:[[self scrollView] documentView]];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSFont *)defaultFont
{
    return [NSFont labelFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]];
}

- (NSColor *)defaultTextColor
{
    return [NSColor colorWithCalibratedWhite:0.42 alpha:1.0];
}

- (NSColor *)defaultAlternateTextColor
{
    return [NSColor whiteColor];
}

- (void)setClientView:(NSView *)aView
{
	id		oldClientView;
	
	oldClientView = [self clientView];
	
    if ((oldClientView != aView) && [oldClientView isKindOfClass:[NSTextView class]])
    {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSTextStorageDidProcessEditingNotification object:[(NSTextView *)oldClientView textStorage]];
    }
    [super setClientView:aView];
    if ((aView != nil) && [aView isKindOfClass:[NSTextView class]])
    {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textStorageDidProcessEditing:) name:NSTextStorageDidProcessEditingNotification object:[(NSTextView *)aView textStorage]];

		[self invalidateLineIndicesFromCharacterIndex:0];
    }
}

- (NSMutableArray *)lineIndices
{
	if (_invalidCharacterIndex < NSUIntegerMax)
	{
		[self calculateLines];
	}
	return _lineIndices;
}

// Forces recalculation of line indicies starting from the given index
- (void)invalidateLineIndicesFromCharacterIndex:(NSUInteger)charIndex
{
    _invalidCharacterIndex = MIN(charIndex, _invalidCharacterIndex);
}

- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
    NSTextStorage       *storage;
    NSRange             range;
    
    storage = [notification object];

    // Invalidate the line indices. They will be recalculated and re-cached on demand.
    range = [storage editedRange];
    if (range.location != NSNotFound)
    {
        [self invalidateLineIndicesFromCharacterIndex:range.location];
        [self setNeedsDisplay:YES];
    }
}

- (void)calculateLines
{
    id              view;

    view = [self clientView];
    
    if ([view isKindOfClass:[NSTextView class]])
    {
        NSUInteger      charIndex, stringLength, lineEnd, contentEnd, count, lineIndex;
        NSString        *text;
        CGFloat         oldThickness, newThickness;
        
        text = [view string];
        stringLength = [text length];
        count = [_lineIndices count];

        charIndex = 0;
        lineIndex = [self lineNumberForCharacterIndex:_invalidCharacterIndex inText:text];
        if (count > 0)
        {
            charIndex = [_lineIndices[lineIndex] unsignedIntegerValue];
        }
        
        do
        {
            if (lineIndex < count)
            {
                _lineIndices[lineIndex] = @(charIndex);
            }
            else
            {
                [_lineIndices addObject:@(charIndex)];
            }
            
            charIndex = NSMaxRange([text lineRangeForRange:NSMakeRange(charIndex, 0)]);
            lineIndex++;
        }
        while (charIndex < stringLength);
        
        if (lineIndex < count)
        {
            [_lineIndices removeObjectsInRange:NSMakeRange(lineIndex, count - lineIndex)];
        }
        _invalidCharacterIndex = NSUIntegerMax;

        // Check if text ends with a new line.
        [text getLineStart:NULL end:&lineEnd contentsEnd:&contentEnd forRange:NSMakeRange([[_lineIndices lastObject] unsignedIntegerValue], 0)];
        if (contentEnd < lineEnd)
        {
            [_lineIndices addObject:@(charIndex)];
        }

        // See if we need to adjust the width of the view
        oldThickness = [self ruleThickness];
        newThickness = [self requiredThickness];
        if (fabs(oldThickness - newThickness) > 1)
        {
			NSInvocation			*invocation;
			
			// Not a good idea to resize the view during calculations (which can happen during
			// display). Do a delayed perform (using NSInvocation since arg is a float).
			invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:@selector(setRuleThickness:)]];
			[invocation setSelector:@selector(setRuleThickness:)];
			[invocation setTarget:self];
			[invocation setArgument:&newThickness atIndex:2];
			
			[invocation performSelector:@selector(invoke) withObject:nil afterDelay:0.0];
        }
	}
}

- (NSUInteger)lineNumberForCharacterIndex:(NSUInteger)charIndex inText:(NSString *)text
{
    NSUInteger			left, right, mid, lineStart;
	NSMutableArray		*lines;

    if (_invalidCharacterIndex < NSUIntegerMax)
    {
        // We do not want to risk calculating the indices again since we are probably doing it right now, thus
        // possibly causing an infinite loop.
        lines = _lineIndices;
    }
    else
    {
        lines = [self lineIndices];
    }
	
    // Binary search
    left = 0;
    right = [lines count];

    while ((right - left) > 1)
    {
        mid = (right + left) / 2;
        lineStart = [lines[mid] unsignedIntegerValue];
        
        if (charIndex < lineStart)
        {
            right = mid;
        }
        else if (charIndex > lineStart)
        {
            left = mid;
        }
        else
        {
            return mid;
        }
    }
    return left;
}

- (NSDictionary *)textAttributes
{
    NSFont  *font;
    NSColor *color;
    
    font = [self font];    
    if (font == nil)
    {
        font = [self defaultFont];
    }
    
    color = [self textColor];
    if (color == nil)
    {
        color = [self defaultTextColor];
    }
    
    return @{NSFontAttributeName: font, NSForegroundColorAttributeName: color};
}

- (NSDictionary *)markerTextAttributes
{
    NSFont  *font;
    NSColor *color;
    
    font = [self font];    
    if (font == nil)
    {
        font = [self defaultFont];
    }
    
    color = [self alternateTextColor];
    if (color == nil)
    {
        color = [self defaultAlternateTextColor];
    }
    
    return @{NSFontAttributeName: font, NSForegroundColorAttributeName: color};
}

- (CGFloat)requiredThickness
{
    NSUInteger			lineCount, digits, i;
    NSMutableString     *sampleString;
    NSSize              stringSize;
    
    lineCount = [[self lineIndices] count];
    digits = 1;
    if (lineCount > 0)
    {
        digits = (NSUInteger)log10(lineCount) + 1;
    }
	sampleString = [NSMutableString string];
    for (i = 0; i < digits; i++)
    {
        // Use "8" since it is one of the fatter numbers. Anything but "1"
        // will probably be ok here. I could be pedantic and actually find the fattest
		// number for the current font but nah.
        [sampleString appendString:@"8"];
    }
    
    stringSize = [sampleString sizeWithAttributes:[self textAttributes]];

	// Round up the value. There is a bug on 10.4 where the display gets all wonky when scrolling if you don't
	// return an integral value here.
    return ceil(MAX(DEFAULT_THICKNESS, stringSize.width + RULER_MARGIN * 2));
}

- (BOOL)getRect:(NSRectPointer)rectPointer forCharacterAtIndex:(NSUInteger)index inTextContainer:(NSTextContainer*)container withYInset:(CGFloat)yinset visibleRect:(CGRect)visibleRect {
    static NSRange nullRange = (NSRange){ .location = NSNotFound, .length = 0 };
    
    NSUInteger rectCount;
    NSRectArray rects = [container.layoutManager rectArrayForCharacterRange:NSMakeRange(index, 0) withinSelectedCharacterRange:nullRange inTextContainer:container rectCount:&rectCount];
    
    if(rectCount == 0) {
        return NO;
    }
    
    *rectPointer = rects[0];
    rectPointer->origin.y += yinset - NSMinY(visibleRect);

    return YES;
}

- (void)drawHashMarksAndLabelsInRect:(NSRect)aRect
{
    id			view;
	NSRect		bounds;

	bounds = [self bounds];

	if (_backgroundColor != nil)
	{
		[_backgroundColor set];
		NSRectFill(bounds);
		
		[self.borderColor set];
		[NSBezierPath strokeLineFromPoint:NSMakePoint(NSMaxX(bounds) - 0/5, NSMinY(bounds)) toPoint:NSMakePoint(NSMaxX(bounds) - 0.5, NSMaxY(bounds))];
	}
	
    view = [self clientView];
	
    if ([view isKindOfClass:[NSTextView class]])
    {
        NSLayoutManager			*layoutManager;
        NSTextContainer			*container;
        NSRect					visibleRect, markerRect;
        NSRange					range, glyphRange, nullRange;
        NSString				*text, *labelText;
        NSUInteger				index, line, count;
        CGFloat					yinset;
        NSDictionary			*textAttributes, *currentTextAttributes;
        NSSize					stringSize, markerSize;
		ASKLineNumberMarker	*marker;
		NSImage					*markerImage;
		NSMutableArray			*lines;
        NSRect containerLineRect;

        layoutManager = [view layoutManager];
        container = [view textContainer];
        text = [view string];
        nullRange = NSMakeRange(NSNotFound, 0);
		
		yinset = [view textContainerInset].height;        
        visibleRect = [[[self scrollView] contentView] bounds];

        textAttributes = [self textAttributes];
		
		lines = [self lineIndices];

        // Find the characters that are currently visible
        glyphRange = [layoutManager glyphRangeForBoundingRect:visibleRect inTextContainer:container];
        range = [layoutManager characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];
        
        // Fudge the range a tad in case there is an extra new line at end.
        // It doesn't show up in the glyphs so would not be accounted for.
        range.length++;
        
        count = [lines count];
        
        for (line = [self lineNumberForCharacterIndex:range.location inText:text]; line < count; line++)
        {
            index = [lines[line] unsignedIntegerValue];
            
            if (NSLocationInRange(index, range))
            {
                if ([self getRect:&containerLineRect forCharacterAtIndex:index inTextContainer:container withYInset:yinset visibleRect:visibleRect])
                {
                    // Note that the ruler view is only as tall as the visible
                    // portion. Need to compensate for the clipview's coordinates.
					
					marker = _linesToMarkers[@(line)];
					
					if (marker != nil)
					{
						markerImage = [marker image];
						markerSize = [markerImage size];
						markerRect = NSMakeRect(0.0, 0.0, markerSize.width, markerSize.height);

						// Marker is flush right and centered vertically within the line.
						markerRect.origin.x = NSWidth(bounds) - [markerImage size].width - 1.0;
						markerRect.origin.y = NSMidY(containerLineRect) - [marker imageOrigin].y;

						[markerImage drawInRect:markerRect fromRect:NSMakeRect(0, 0, markerSize.width, markerSize.height) operation:NSCompositeSourceOver fraction:1.0];
					}
                    
                    // Line numbers are internally stored starting at 0
                    labelText = [NSString stringWithFormat:@"%jd", (intmax_t)line + 1];
                    
                    stringSize = [labelText sizeWithAttributes:textAttributes];

					if (marker == nil)
					{
						currentTextAttributes = textAttributes;
					}
					else
					{
						currentTextAttributes = [self markerTextAttributes];
					}
                    
                    if(NSLocationInRange(line, self.rangeOfHighlightedLineNumbers)) {
                        CGRect lineAreaRect = CGRectMake(NSMinX(bounds), NSMinY(containerLineRect), NSWidth(bounds) - 1, 0);
                        NSRect nextLineRect;
                        if(line + 1 < count && [self getRect:&nextLineRect forCharacterAtIndex:[lines[line + 1] unsignedIntegerValue] inTextContainer:container withYInset:yinset visibleRect:visibleRect]) {
                            lineAreaRect.size.height = NSMinY(nextLineRect) - NSMinY(lineAreaRect);
                        }
                        else {
                            lineAreaRect.size.height = NSMaxY(bounds) - NSMinY(lineAreaRect);
                        }
                        
                        [self.highlightedLineBackgroundColor set];
                        NSRectFill(lineAreaRect);
                        
                        [self.borderColor set];
                        if(!NSMinY(lineAreaRect) == NSMinY(bounds) && line == self.rangeOfHighlightedLineNumbers.location) {
                            NSRectFill(NSMakeRect(NSMinX(lineAreaRect), NSMinY(lineAreaRect), NSWidth(lineAreaRect), 1));
                        }
                        if(line == NSMaxRange(self.rangeOfHighlightedLineNumbers) - 1) {
                            NSRectFill(NSMakeRect(NSMinX(lineAreaRect), NSMaxY(lineAreaRect) - 1, NSWidth(lineAreaRect), 1));
                        }
                    }
					
                    // Draw string flush right, centered vertically within the line
                    [labelText drawInRect:
                       NSMakeRect(NSWidth(bounds) - stringSize.width - RULER_MARGIN,
                                  NSMinY(containerLineRect) + (NSHeight(containerLineRect) - stringSize.height) / 2.0,
                                  NSWidth(bounds) - RULER_MARGIN * 2.0, NSHeight(containerLineRect))
                           withAttributes:currentTextAttributes];
                }
            }
			if (index > NSMaxRange(range))
			{
				break;
			}
        }
    }
}

- (NSColor *)highlightedLineBackgroundColor {
    return _highlightedLineBackgroundColor ?: [NSColor colorWithCalibratedWhite:0.80 alpha:1.0];
}

- (NSColor *)borderColor {
    return _borderColor ?: [NSColor colorWithCalibratedWhite:0.58 alpha:1.0];
}

- (void)setRangeOfHighlightedLineNumbers:(NSRange)highlightedLineNumbers {
    _rangeOfHighlightedLineNumbers = highlightedLineNumbers;
    [self setNeedsDisplay:YES];
}

- (NSUInteger)lineNumberForLocation:(CGFloat)location
{
	NSUInteger		line, count, index, rectCount, i;
	NSRectArray		rects;
	NSRect			visibleRect;
	NSLayoutManager	*layoutManager;
	NSTextContainer	*container;
	NSRange			nullRange;
	NSMutableArray	*lines;
	id				view;
    
	view = [self clientView];
	visibleRect = [[[self scrollView] contentView] bounds];
	
	lines = [self lineIndices];
    
	location += NSMinY(visibleRect);
	
	if ([view isKindOfClass:[NSTextView class]])
	{
		nullRange = NSMakeRange(NSNotFound, 0);
		layoutManager = [view layoutManager];
		container = [view textContainer];
		count = [lines count];
		
		for (line = 0; line < count; line++)
		{
			index = [lines[line] unsignedIntegerValue];
			
			rects = [layoutManager rectArrayForCharacterRange:NSMakeRange(index, 0)
								 withinSelectedCharacterRange:nullRange
											  inTextContainer:container
													rectCount:&rectCount];
			
			for (i = 0; i < rectCount; i++)
			{
				if ((location >= NSMinY(rects[i])) && (location < NSMaxY(rects[i])))
				{
					return line + 1;
				}
			}
		}	
	}
	return NSNotFound;
}

- (ASKLineNumberMarker *)markerAtLine:(NSUInteger)line
{
	return _linesToMarkers[@(line - 1)];
}

- (void)setMarkers:(NSArray *)markers
{
	NSEnumerator		*enumerator;
	NSRulerMarker		*marker;
	
	[_linesToMarkers removeAllObjects];
	[super setMarkers:nil];

	enumerator = [markers objectEnumerator];
	while ((marker = [enumerator nextObject]) != nil)
	{
		[self addMarker:marker];
	}
}

- (void)addMarker:(NSRulerMarker *)aMarker
{
	if ([aMarker isKindOfClass:[ASKLineNumberMarker class]])
	{
		_linesToMarkers[@([(ASKLineNumberMarker *)aMarker lineNumber] - 1)] = aMarker;
	}
	else
	{
		[super addMarker:aMarker];
	}
}

- (void)removeMarker:(NSRulerMarker *)aMarker
{
	if ([aMarker isKindOfClass:[ASKLineNumberMarker class]])
	{
		[_linesToMarkers removeObjectForKey:@([(ASKLineNumberMarker *)aMarker lineNumber] - 1)];
	}
	else
	{
		[super removeMarker:aMarker];
	}
}

#pragma mark NSCoding methods

#define NOODLE_FONT_CODING_KEY				@"font"
#define NOODLE_TEXT_COLOR_CODING_KEY		@"textColor"
#define NOODLE_ALT_TEXT_COLOR_CODING_KEY	@"alternateTextColor"
#define NOODLE_BACKGROUND_COLOR_CODING_KEY	@"backgroundColor"

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder]) != nil)
	{
		if ([decoder allowsKeyedCoding])
		{
			_font = [decoder decodeObjectForKey:NOODLE_FONT_CODING_KEY];
			_textColor = [decoder decodeObjectForKey:NOODLE_TEXT_COLOR_CODING_KEY];
			_alternateTextColor = [decoder decodeObjectForKey:NOODLE_ALT_TEXT_COLOR_CODING_KEY];
			_backgroundColor = [decoder decodeObjectForKey:NOODLE_BACKGROUND_COLOR_CODING_KEY];
		}
		else
		{
			_font = [decoder decodeObject];
			_textColor = [decoder decodeObject];
			_alternateTextColor = [decoder decodeObject];
			_backgroundColor = [decoder decodeObject];
		}
		
		_linesToMarkers = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];
	
	if ([encoder allowsKeyedCoding])
	{
		[encoder encodeObject:_font forKey:NOODLE_FONT_CODING_KEY];
		[encoder encodeObject:_textColor forKey:NOODLE_TEXT_COLOR_CODING_KEY];
		[encoder encodeObject:_alternateTextColor forKey:NOODLE_ALT_TEXT_COLOR_CODING_KEY];
		[encoder encodeObject:_backgroundColor forKey:NOODLE_BACKGROUND_COLOR_CODING_KEY];
	}
	else
	{
		[encoder encodeObject:_font];
		[encoder encodeObject:_textColor];
		[encoder encodeObject:_alternateTextColor];
		[encoder encodeObject:_backgroundColor];
	}
}

@end
