//
//  ASKSyntax.h
//  SyntaxKit
//
//  Created by Brent Royal-Gordon on 7/25/13.
//  Copyright (c) 2013 Architechies. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ASKSyntax : NSObject

- (id)initWithDefinition:(NSDictionary*)definition;
- (id)initWithDefinitionURL:(NSURL*)URL;

@property (strong) NSDictionary * definition;

@end
