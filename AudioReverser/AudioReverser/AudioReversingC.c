//
//  AudioReversingC.c
//  AudioReverser
//
//  Created by Chris Adamson on 2/15/17.
//  Copyright © 2017 Subsequently & Furthermore, Inc. All rights reserved.
//

#include "AudioReversingC.h"
#import <AudioToolbox/AudioToolbox.h>

#define IF_ERR_RETURN if (err != noErr) { return err; }
#define IF_ERR_GOTO_CLEANUP_1 if (err != noErr) { goto cleanup1; }
#define IF_ERR_GOTO_CLEANUP_2 if (err != noErr) { goto cleanup2; }


OSStatus convertAndReverse(CFURLRef sourceURL, CFURLRef forwardURL, CFURLRef backwardURL) {

    OSStatus err = noErr;
    
    // open ExtAudioFile for URL input
    ExtAudioFileRef sourceExtAudioFile;
    err = ExtAudioFileOpenURL(sourceURL, &sourceExtAudioFile);
    IF_ERR_RETURN

    // declare LPCM format we are converting to
    AudioStreamBasicDescription format = {0};
    format.mSampleRate = 44100.0;
    format.mFormatID = kAudioFormatLinearPCM;
    //    format.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagIsPacked; // DOESN'T WORK
    format.mFormatFlags = kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger; // WORKS
    format.mBitsPerChannel = 16;
    format.mChannelsPerFrame = 2;
    format.mBytesPerFrame = 4;
    format.mFramesPerPacket = 1;
    format.mBytesPerPacket = 4;
    
    // set format we want to receive from sourceExtAudioFile
    err = ExtAudioFileSetProperty(sourceExtAudioFile,
                                  kExtAudioFileProperty_ClientDataFormat,
                                  sizeof(AudioStreamBasicDescription),
                                  &format);
    IF_ERR_RETURN
    
    // open AudioFile for output
    AudioFileID forwardAudioFile;
    err = AudioFileCreateWithURL(forwardURL,
                                 kAudioFileCAFType,
                                 &format,
                                 kAudioFileFlags_EraseFile,
                                 &forwardAudioFile);
    IF_ERR_RETURN
    
    
    // convert to a flat file
    // kind of borrowed from my Core Audio book
    size_t outputBufferSize = 0x8000; // 32 KB buffer
    UInt32 packetsPerBuffer = outputBufferSize / format.mBytesPerPacket;
    
    
    UInt8 *outputBuffer = (UInt8*) malloc(sizeof(UInt8) * outputBufferSize);

    SInt64 outputFilePacketPosition = 0;
    while(true) {
        AudioBufferList convertedData;
        convertedData.mNumberBuffers = 1;
        convertedData.mBuffers[0].mNumberChannels = format.mChannelsPerFrame;
        convertedData.mBuffers[0].mDataByteSize = outputBufferSize;
        convertedData.mBuffers[0].mData = outputBuffer;
        
        UInt32 frameCount = packetsPerBuffer;
        err = ExtAudioFileRead(sourceExtAudioFile,
                               &packetsPerBuffer,
                               &convertedData);
        IF_ERR_GOTO_CLEANUP_1
        
        if (frameCount == 0) {
            printf("done reading file\n");
            break;
        } else {
            printf("read %u packets\n", (unsigned int)frameCount);
            err = AudioFileWritePackets(forwardAudioFile,
                                        FALSE,
                                        frameCount,
                                        NULL,
                                        outputFilePacketPosition ,
                                        &frameCount,
                                        convertedData.mBuffers[0].mData);
            IF_ERR_GOTO_CLEANUP_1
            outputFilePacketPosition += frameCount ;
        }
        
        
    }

cleanup1:
    free(outputBuffer);
    ExtAudioFileDispose(sourceExtAudioFile);
    AudioFileClose(forwardAudioFile);
    IF_ERR_RETURN

    // read in the forward file and write its frames in reverse order
    err = AudioFileOpenURL(forwardURL,
                           kAudioFileReadPermission,
                           kAudioFileCAFType,
                           &forwardAudioFile);
    IF_ERR_RETURN
    
    AudioFileID backwardAudioFile;
    err = AudioFileCreateWithURL(backwardURL,
                                 kAudioFileCAFType,
                                 &format,
                                 kAudioFileFlags_EraseFile,
                                 &backwardAudioFile);
    IF_ERR_RETURN
    
    // buffer just large enough for one packet (which is also one frame)
    // (obviously, it would be more efficient to read larger buffers and
    // reverse them in memory, prior to writing them out… takes like a minute this way!)
    UInt8 *transferBuffer = (UInt8*) malloc(sizeof(UInt8) * format.mBytesPerPacket);
    SInt64 totalPackets = outputFilePacketPosition;
    for (SInt64 packetsProcessed = 0; packetsProcessed < totalPackets; packetsProcessed++) {
        UInt32 bytesToTransfer = format.mBytesPerPacket;
        UInt32 packetsToTransfer = 1;
        SInt64 inputPacketPosition = totalPackets - packetsProcessed - 1;
        err = AudioFileReadPacketData(forwardAudioFile,
                                      FALSE,
                                      &bytesToTransfer,
                                      NULL,
                                      inputPacketPosition,
                                      &packetsToTransfer,
                                      &transferBuffer);
        IF_ERR_GOTO_CLEANUP_2
        
        err = AudioFileWritePackets(backwardAudioFile,
                                    FALSE,
                                    bytesToTransfer,
                                    NULL,
                                    packetsProcessed,
                                    &packetsToTransfer,
                                    &transferBuffer);
        IF_ERR_GOTO_CLEANUP_2
        
        // log that we're actually working, every 1KB.
        if (packetsProcessed % 0x1000 == 0) {
            printf("processed %lld packets\n", packetsProcessed);
        }
    }

    
cleanup2:
    free(transferBuffer);
    AudioFileClose(forwardAudioFile);
    AudioFileClose(backwardAudioFile);
    
    return err;
}
