//
//  TDBindings.h
//  SectionedCollectionView
//
//  Created by Brent Royal-Gordon on 6/15/11.
//  Copyright 2011 Architechies. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (TDBindings)

-(void) propagateValue:(id)value forBinding:(NSString*)binding;

@end
