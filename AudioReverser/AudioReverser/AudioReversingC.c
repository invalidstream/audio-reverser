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
#define MIN(X, Y) (((X) < (Y)) ? (X) : (Y))

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

    // open the forward file for reading
    err = AudioFileOpenURL(forwardURL,
                           kAudioFileReadPermission,
                           kAudioFileCAFType,
                           &forwardAudioFile);
    IF_ERR_RETURN
    
    // open the backward file for writing
    AudioFileID backwardAudioFile;
    err = AudioFileCreateWithURL(backwardURL,
                                 kAudioFileCAFType,
                                 &format,
                                 kAudioFileFlags_EraseFile,
                                 &backwardAudioFile);
    IF_ERR_RETURN
    
    // prepare to read buffers of audio from the forward file
    UInt32 transferBufferPacketCount = 0x2000;
    UInt32 transferBufferSize = sizeof(UInt8) * format.mBytesPerPacket * transferBufferPacketCount;
    UInt8 *transferBuffer = (UInt8*) malloc(transferBufferSize);
    UInt8 *swapBuffer = (UInt8*) malloc(sizeof(UInt8) * format.mBytesPerPacket);
    SInt64 totalPackets = outputFilePacketPosition;
    SInt64 packetsProcessed = 0;
    while (packetsProcessed < totalPackets) {

        // read from forward file, starting at the end of the file and moving forward
        UInt32 bytesToTransfer = transferBufferSize;
        UInt32 packetsToTransfer = MIN(transferBufferPacketCount, totalPackets - packetsProcessed);
        SInt64 inputPacketPosition = totalPackets - packetsProcessed - packetsToTransfer;
        err = AudioFileReadPacketData(forwardAudioFile,
                                      FALSE,
                                      &bytesToTransfer,
                                      NULL,
                                      inputPacketPosition,
                                      &packetsToTransfer,
                                      transferBuffer);
        IF_ERR_GOTO_CLEANUP_2
        
        if (packetsToTransfer == 0) {
            goto cleanup2;
        }
        
        // swap packets inside transfer buffer
        for (int i=0; i<packetsToTransfer/2; i++) {
            UInt8 *swapSrc = transferBuffer + (i * format.mBytesPerPacket);
            UInt8 *swapDst = transferBuffer + transferBufferSize - ((i+1) * format.mBytesPerPacket);
            memcpy(swapBuffer, swapSrc, format.mBytesPerPacket);
            memcpy(swapSrc, swapDst, format.mBytesPerPacket);
            memcpy(swapDst, swapBuffer, format.mBytesPerPacket);
        }
        
        // write reversed buffer to backward file
        err = AudioFileWritePackets(backwardAudioFile,
                                    FALSE,
                                    bytesToTransfer,
                                    NULL,
                                    packetsProcessed,
                                    &packetsToTransfer,
                                    transferBuffer);
        IF_ERR_GOTO_CLEANUP_2
        
        // log that we're actually working, every 1KB.
        if (packetsProcessed % 0x1000 == 0) {
            printf("processed %lld packets\n", packetsProcessed);
        }
        
        // increment packet count
        packetsProcessed += packetsToTransfer;
    }

    
cleanup2:
    free(transferBuffer);
    free(swapBuffer);
    AudioFileClose(forwardAudioFile);
    AudioFileClose(backwardAudioFile);
    
    return err;
}
