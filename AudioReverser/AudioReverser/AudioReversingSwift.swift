//
//  AudioReversingSwift.swift
//  AudioReverser
//
//  Created by Chris Adamson on 2/20/17.
//  Copyright © 2017 Subsequently & Furthermore, Inc. All rights reserved.
//

import Foundation
import AudioToolbox

func convertAndReverseSwift(sourceURL: CFURL, forwardURL: CFURL, backwardURL: CFURL) -> OSStatus {

    var err: OSStatus = noErr
    
    // open ExtAudioFile for URL input
    var sourceExtAudioFile: ExtAudioFileRef? = nil
    err = ExtAudioFileOpenURL(sourceURL, &sourceExtAudioFile)
    
    // declare LPCM format we are converting to
    var format = AudioStreamBasicDescription(mSampleRate: 44100.0,
                                             mFormatID: kAudioFormatLinearPCM,
                                             mFormatFlags: kAudioFormatFlagIsPacked + kAudioFormatFlagIsSignedInteger,
                                             mBytesPerPacket: 4,
                                             mFramesPerPacket: 1,
                                             mBytesPerFrame: 4,
                                             mChannelsPerFrame: 2,
                                             mBitsPerChannel: 16,
                                             mReserved: 0)

    // set format we want to receive from sourceExtAudioFile
    err = ExtAudioFileSetProperty(sourceExtAudioFile!,
                                  kExtAudioFileProperty_ClientDataFormat,
                                  UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
                                  &format)
    // IF_ERR_RETURN
    
    // open AudioFile for output
    var forwardAudioFile: AudioFileID?
    err = AudioFileCreateWithURL(forwardURL,
                                 kAudioFileCAFType,
                                 &format,
                                 AudioFileFlags.eraseFile, // notice: have an enum for this (but not for flags in the ASBD)
                                 &forwardAudioFile)
    // IF_ERR_RETURN

    // convert to a flat file
    // kind of borrowed from my Core Audio book
    let outputBufferSize: size_t = 0x8000 // 32 KB buffer
    var packetsPerBuffer: UInt32 = UInt32(outputBufferSize) / format.mBytesPerPacket

//    let outputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: MemoryLayout<UInt8>.size * outputBufferSize)
    let outputBuffer: UnsafeMutableRawPointer = malloc(MemoryLayout<UInt8>.size * outputBufferSize)
    var outputFilePacketPosition: Int64 = 0

    while(true) {
        var buffer = AudioBuffer()
        buffer.mNumberChannels = format.mChannelsPerFrame
        buffer.mDataByteSize = UInt32(outputBufferSize)
        buffer.mData = outputBuffer
        var convertedData = AudioBufferList()
        convertedData.mNumberBuffers = 1
        convertedData.mBuffers = buffer
        
        var frameCount = packetsPerBuffer
        err = ExtAudioFileRead(sourceExtAudioFile!,
                               &packetsPerBuffer,
                               &convertedData)
//        IF_ERR_GOTO_CLEANUP_1

        if (frameCount == 0) {
            print("done reading file")
            break
        } else {
            print("read \(frameCount) packets\n")
            err = AudioFileWritePackets(forwardAudioFile!,
                                        false,
                                        frameCount,
                                        nil,
                                        outputFilePacketPosition,
                                        &frameCount,
                                        buffer.mData!)
//            IF_ERR_GOTO_CLEANUP_1
            outputFilePacketPosition += Int64(frameCount)
        }
        
    }
    
//    cleanup1:
    
    free(outputBuffer)
    ExtAudioFileDispose(sourceExtAudioFile!)
    AudioFileClose(forwardAudioFile!)
//    IF_ERR_RETURN
    
    // open the forward file for reading
    err = AudioFileOpenURL(forwardURL,
                           .readPermission,
                           kAudioFileCAFType,
                           &forwardAudioFile)
//    IF_ERR_RETURN

    // open the backward file for writing
    var backwardAudioFile: AudioFileID? = nil
    err = AudioFileCreateWithURL(backwardURL,
                                 kAudioFileCAFType,
                                 &format,
                                 .eraseFile,
                                 &backwardAudioFile)
//    IF_ERR_RETURN

    // prepare to read buffers of audio from the forward file
    let transferBufferPacketCount: UInt32  = 0x2000
    let transferBufferSize: Int = MemoryLayout<UInt8>.size * Int(format.mBytesPerPacket * transferBufferPacketCount)
    let transferBuffer: UnsafeMutableRawPointer = malloc(transferBufferSize)
    let swapBuffer: UnsafeMutableRawPointer = malloc(MemoryLayout<UInt8>.size * Int(format.mBytesPerPacket))
    let totalPackets: Int64 = outputFilePacketPosition
    var packetsProcessed: Int64 = 0
    while (packetsProcessed < totalPackets) {

        // read from forward file, starting at the end of the file and moving forward
        var bytesToTransfer: UInt32 = UInt32(transferBufferSize)
        var packetsToTransfer: UInt32 = min(transferBufferPacketCount, UInt32(totalPackets - packetsProcessed))
        let inputPacketPosition: Int64 = totalPackets - packetsProcessed - Int64(packetsToTransfer)
        err = AudioFileReadPacketData(forwardAudioFile!,
                                      false,
                                      &bytesToTransfer,
                                      nil,
                                      inputPacketPosition,
                                      &packetsToTransfer,
                                      transferBuffer);
//        IF_ERR_GOTO_CLEANUP_2

        if packetsToTransfer == 0 {
            break
        }

        // swap packets inside transfer buffer
        for i in 0..<packetsToTransfer/2 {
            let swapSrc = transferBuffer.advanced(by: Int(i) * Int(format.mBytesPerPacket))
            let swapDst = transferBuffer.advanced(by: transferBufferSize - (Int(i+1) * Int(format.mBytesPerPacket)))
            memcpy(swapBuffer, swapSrc, Int(format.mBytesPerPacket))
            memcpy(swapSrc, swapDst, Int(format.mBytesPerPacket))
            memcpy(swapDst, swapBuffer, Int(format.mBytesPerPacket))
        }

        // write reversed buffer to backward file
        err = AudioFileWritePackets(backwardAudioFile!,
                                    false,
                                    bytesToTransfer,
                                    nil,
                                    packetsProcessed,
                                    &packetsToTransfer,
                                    transferBuffer);
//        IF_ERR_GOTO_CLEANUP_2

        // log that we're actually working, every 1KB.
        if (packetsProcessed % 0x1000 == 0) {
            print("swift processed \(packetsProcessed) packets")
        }
        
        // increment packet count
        packetsProcessed += Int64(packetsToTransfer)
        
    }
    
//    cleanup2:
    free(transferBuffer)
    free(swapBuffer)
    AudioFileClose(forwardAudioFile!)
    AudioFileClose(backwardAudioFile!)

    
    return err
}
