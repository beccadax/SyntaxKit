//
//  ASKSyntax+GSTType.h
//  Ingist
//
//  Created by Brent Royal-Gordon on 7/25/13.
//  Copyright (c) 2013 Architechies. All rights reserved.
//

#import "ASKSyntax.h"

extern NSString * const ASKSyntaxWillInvalidateSyntaxesNotification;
extern NSString * const ASKSyntaxDidInvalidateSyntaxesNotification;

@interface ASKSyntax (syntaxForType)

+ (instancetype)syntaxForType:(NSString*)type;

+ (void)invalidateSyntaxes;
+ (NSURL *)userSyntaxesURL;

@end
