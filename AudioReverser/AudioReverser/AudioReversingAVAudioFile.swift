//
//  AudioReversingAVAudioFile.swift
//  AudioReverser
//
//  Created by Chris Adamson on 10/22/17.
//  Copyright © 2017 Subsequently & Furthermore, Inc. All rights reserved.
//

import Foundation
import AVFoundation

func convertAndReverseAVAudioFile(sourceURL: CFURL, forwardURL: CFURL, backwardURL: CFURL) throws {

    // open AVAudioFile for URL input
    let sourceAudioFile = try AVAudioFile(forReading: sourceURL as URL,
                                          commonFormat: .pcmFormatInt16,
                                          interleaved: true)
    
    // open AudioFile for output
    var forwardAudioFile = try AVAudioFile(forWriting: forwardURL as URL,
                                           settings: [:],
                                           commonFormat: .pcmFormatInt16,
                                           interleaved: true)
    
    // convert to a flat file
    let outputBufferSize: size_t = 0x8000 // 32 KB buffer
    let framesPerBuffer: UInt32 = UInt32(outputBufferSize) / 4

    // note: in PCM, frames == packets, so I'm leaving the "packets" terminology from
    // the Audio Toolbox code, even though AVAudioPCMBuffer is all about frames.
    
    let transferBuffer = AVAudioPCMBuffer(pcmFormat: sourceAudioFile.processingFormat, frameCapacity: framesPerBuffer)
    var totalFrameCount: Int64 = 0
    
    while(true) {
        do {
            try sourceAudioFile.read(into: transferBuffer)
        } catch {
            // FIXME: discern between empty read and genuine error.
            // this could happen if last read(from:) exactly filled the
            // buffer, and this one gets 0 frames.
            // empty read should break, real error should throw
            throw error
        }
        
        // this never happens, actually. earlier try fails instead
        guard transferBuffer.frameLength > 0 else {
            print ("done reading file")
            break
        }
        
        // increment frame count
        totalFrameCount += Int64(transferBuffer.frameLength)
        
        // write to fowardFile
        try forwardAudioFile.write(from: transferBuffer)
        
        if transferBuffer.frameLength < transferBuffer.frameCapacity {
            // didn't fill buffer; we're done
            break
        }
    }
    
    // open the forward file for reading
    forwardAudioFile = try AVAudioFile(forReading: forwardURL as URL,
                                       commonFormat: .pcmFormatInt16,
                                       interleaved: true)
    
    // open the backward file for writing
    let backwardAudioFile = try AVAudioFile(forWriting: backwardURL as URL,
                                            settings: [:],
                                            commonFormat: .pcmFormatInt16,
                                            interleaved: true)
    
    // prepare to read buffers of audio from the forward file
    let swapBuffer: UnsafeMutableRawPointer = malloc(MemoryLayout<UInt32>.size)
    var framesProcessed: Int64 = 0
    while (framesProcessed < totalFrameCount) {
        
        // read from forward file, starting at the end of the file and moving forward
        let framesToTransfer = min(transferBuffer.frameCapacity, UInt32(totalFrameCount - framesProcessed))
        let inputFramePosition: Int64 = totalFrameCount - framesProcessed - Int64(framesToTransfer)
        forwardAudioFile.framePosition = AVAudioFramePosition(inputFramePosition)
        try forwardAudioFile.read(into: transferBuffer)

        // swap packets inside transfer buffer
        guard let channelData = transferBuffer.int16ChannelData else {
            throw NSError(domain: "AudioReverser", code: -888888,
                          userInfo: [NSLocalizedDescriptionKey : "empty buffer"])
        }

        // TODO: pointer crash in here somewhere
//        for i in 0..<framesToTransfer/2 {
        for i in 0..<framesToTransfer/4/2 {
            let swapSrc = UnsafeMutableRawPointer(mutating: channelData.advanced(by: Int(i) * 4))
            let swapDst =  UnsafeMutableRawPointer(mutating: channelData.advanced(by: Int(framesPerBuffer) - (Int(i+1) * 4)))
            // TODO: memcpy()s don't actually change buffer contents
            // so the write below is just putting out-of-order forward-playing buffers into backwardAudioFile
            memcpy(swapBuffer, swapSrc, 4)
            memcpy(swapSrc, swapDst, 4)
            memcpy(swapDst, swapBuffer, 4)

            // TEST: write empty buffers to swapDst. doesn't matter.
//            let zeroPointer = UnsafeMutableRawPointer.allocate(bytes: 4, alignedTo: 1)
//            zeroPointer.storeBytes(of: 0x0000_0000, as: UInt32.self)
//            memcpy(swapDst, zeroPointer, 4)
        }
        
        // increment frame count
        framesProcessed += Int64(transferBuffer.frameLength)
        
        // write reversed buffer to backward file
        try backwardAudioFile.write(from: transferBuffer)
        
    }

}
