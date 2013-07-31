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

@property (strong) NSDictionary * definition;

@end
