//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import <CoreFoundation/CoreFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

OSStatus convertAndReverse(CFURLRef sourceURL, CFURLRef forwardURL, CFURLRef backwardURL);
