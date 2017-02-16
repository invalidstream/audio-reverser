//
//  AudioReversingC.h
//  AudioReverser
//
//  Created by Chris Adamson on 2/15/17.
//  Copyright © 2017 Subsequently & Furthermore, Inc. All rights reserved.
//

#ifndef AudioReversingC_h
#define AudioReversingC_h


#include <stdio.h>
#import <CoreFoundation/CoreFoundation.h>

#endif /* AudioReversingC_h */

/**
 Convert a source audio file (using any Core Audio-supported codec) and create LPCM .caf
 files for its forward and backward versions.
 
 - parameter sourceURL: A file URL containing the source audio to be read from
 - parameter forwardURL: A file URL with the destination to write the decompressed (LPCM) forward file
 - parameter backwardURL: A file URL witht he destination to write the backward file
 
 */
OSStatus convertAndReverse(CFURLRef sourceURL, CFURLRef forwardURL, CFURLRef backwardURL);
