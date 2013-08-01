//
//  ASKSyntaxColorPalette.h
//  SyntaxKit
//
//  Created by Brent Royal-Gordon on 7/31/13.
//  Copyright (c) 2013 Architechies. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ASKSyntaxComponent;

@interface ASKSyntaxColorPalette : NSObject

+ (instancetype)standardColorPalette;

- (id)initWithDefinition:(NSDictionary*)definition;
- (id)initWithDefinitionURL:(NSURL*)URL;

@property (readonly) NSDictionary * definition;

- (NSColor*)colorForSyntaxComponent:(ASKSyntaxComponent*)component;

@end
