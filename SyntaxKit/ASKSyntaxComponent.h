//
//  ASKSyntaxComponent.h
//  SyntaxKit
//
//  Created by Brent Royal-Gordon on 7/31/13.
//  Copyright (c) 2013 Architechies. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ASKSyntaxComponent : NSObject

- (id)initWithDefinition:(NSDictionary*)definition;

@property (strong) NSString * type;
@property (strong) NSString * name;

@property (strong) NSString * start;
@property (strong) NSString * end;
@property (strong) NSString * escapeChar;
@property (strong) NSCharacterSet * charset;

@property (strong) NSArray * keywords;

@property (strong) NSString * ignoredComponent;

@property (strong) NSColor * color;

@end
