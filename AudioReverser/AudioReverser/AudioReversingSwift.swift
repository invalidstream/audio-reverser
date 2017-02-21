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
    if err != noErr { return err }
    
    // open AudioFile for output
    var forwardAudioFile: AudioFileID?
    err = AudioFileCreateWithURL(forwardURL,
                                 kAudioFileCAFType,
                                 &format,
                                 AudioFileFlags.eraseFile, // notice: have an enum for this (but not for flags in the ASBD)
                                 &forwardAudioFile)
    if err != noErr { return err }

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
        if err != noErr {
            cleanup1(outputBuffer: outputBuffer, sourceExtAudioFile: sourceExtAudioFile, forwardAudioFile: forwardAudioFile)
            return err
        }

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
            if err != noErr {
                cleanup1(outputBuffer: outputBuffer, sourceExtAudioFile: sourceExtAudioFile, forwardAudioFile: forwardAudioFile)
                return err
            }

            outputFilePacketPosition += Int64(frameCount)
        }
        
    }
    
//    cleanup1:
    cleanup1(outputBuffer: outputBuffer, sourceExtAudioFile: sourceExtAudioFile, forwardAudioFile: forwardAudioFile)
    
    // open the forward file for reading
    err = AudioFileOpenURL(forwardURL,
                           .readPermission,
                           kAudioFileCAFType,
                           &forwardAudioFile)
    if err != noErr { return err }

    // open the backward file for writing
    var backwardAudioFile: AudioFileID? = nil
    err = AudioFileCreateWithURL(backwardURL,
                                 kAudioFileCAFType,
                                 &format,
                                 .eraseFile,
                                 &backwardAudioFile)
    if err != noErr { return err }

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
        if err != noErr {
            cleanup2(transferBuffer: transferBuffer, swapBuffer: swapBuffer, forwardAudioFile: forwardAudioFile, backwardAudioFile: backwardAudioFile)
            return err
        }
        
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
        if err != noErr {
            cleanup2(transferBuffer: transferBuffer, swapBuffer: swapBuffer, forwardAudioFile: forwardAudioFile, backwardAudioFile: backwardAudioFile)
            return err
        }

        // log that we're actually working, every 1KB.
        if (packetsProcessed % 0x1000 == 0) {
            print("swift processed \(packetsProcessed) packets")
        }
        
        // increment packet count
        packetsProcessed += Int64(packetsToTransfer)
        
    }
    
//    cleanup2:
    cleanup2(transferBuffer: transferBuffer, swapBuffer: swapBuffer, forwardAudioFile: forwardAudioFile, backwardAudioFile: backwardAudioFile)
    
    return err
}

fileprivate func cleanup1(outputBuffer: UnsafeMutableRawPointer?, sourceExtAudioFile: ExtAudioFileRef?, forwardAudioFile: AudioFileID?) {
    if let outputBuffer = outputBuffer { free(outputBuffer) }
    if let sourceExtAudioFile = sourceExtAudioFile { ExtAudioFileDispose(sourceExtAudioFile) }
    if let forwardAudioFile = forwardAudioFile { AudioFileClose(forwardAudioFile) }
}

fileprivate func cleanup2(transferBuffer: UnsafeMutableRawPointer?, swapBuffer: UnsafeMutableRawPointer?,
                          forwardAudioFile: AudioFileID?, backwardAudioFile: AudioFileID?) {
    
    if let transferBuffer = transferBuffer { free(transferBuffer) }
    if let swapBuffer = swapBuffer { free(swapBuffer) }
    if let forwardAudioFile = forwardAudioFile { AudioFileClose(forwardAudioFile) }
    if let backwardAudioFile = backwardAudioFile { AudioFileClose(backwardAudioFile) }
}
