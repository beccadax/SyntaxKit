//
//  ASKTextViewController.h
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

#import <Cocoa/Cocoa.h>

@class ASKLineNumberView;
@class ASKSyntax;

@protocol ASKSyntaxViewControllerDelegate;

// -----------------------------------------------------------------------------
//	Class:
// -----------------------------------------------------------------------------

@interface ASKSyntaxViewController : NSViewController <NSTextViewDelegate>

@property (weak) id <ASKSyntaxViewControllerDelegate, NSTextViewDelegate> delegate;
@property (strong) NSTextView * view;

@property (strong, nonatomic) ASKSyntax * syntax;
@property (copy, nonatomic) NSArray * userIdentifiers;

@property (assign) BOOL maintainIndentation;
-(IBAction)	toggleMaintainIndentation: (id)sender;

@property (assign, nonatomic) BOOL wrapsLines;
- (IBAction)toggleWrapsLines:(id)sender;

@property (assign, nonatomic) NSUInteger tabDepth;
- (IBAction)takeTabDepth:(id)sender;

@property (assign, nonatomic) BOOL indentsWithSpaces;
- (IBAction)toggleIndentsWithSpaces:(id)sender;

@property (assign, nonatomic) BOOL showsLineNumbers;
- (IBAction)toggleShowsLineNumbers:(id)sender;
@property (readonly) ASKLineNumberView * lineNumberView;

-(IBAction)	recolorCompleteFile: (id)sender;
-(IBAction) indentSelection: (id)sender;
-(IBAction) unindentSelection: (id)sender;
-(IBAction)	toggleCommentForSelection: (id)sender;

-(void)		goToLine: (NSUInteger)lineNum;
-(void)		goToCharacter: (NSUInteger)charNum;
-(void)		goToRangeFrom: (NSUInteger)startCh toChar: (NSUInteger)endCh;

// Override any of the following in one of your subclasses to customize this object further:
-(NSDictionary*)	defaultTextAttributes;		// Style attributes dictionary for an NSAttributedString.
-(NSRange)			defaultSelectedRange;		// Selected text range when document is opened.

@end

@protocol ASKSyntaxViewControllerDelegate <NSObject>

@optional

- (void)syntaxViewController:(ASKSyntaxViewController*)controller syntaxWillColor:(ASKSyntax*)syntax;
- (void)syntaxViewController:(ASKSyntaxViewController*)controller syntaxIsColoring:(ASKSyntax*)syntax;
- (void)syntaxViewController:(ASKSyntaxViewController*)controller syntaxDidColor:(ASKSyntax*)syntax;

- (NSDictionary*)syntaxViewController:(ASKSyntaxViewController*)controller syntax:(ASKSyntax*)syntax textAttributesForComponentName:(NSString*)name color:(NSColor*)color;

@end
