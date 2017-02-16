//
//  ReversePlaybackModel.swift
//  AudioReverser
//
//  Created by Chris Adamson on 2/15/17.
//  Copyright © 2017 Subsequently & Furthermore, Inc. All rights reserved.
//

import Foundation
import AVFoundation

struct ReversePlaybackModel {
    
    var forwardURL: URL
    var backwardURL: URL
    
    init (source: URL) {
        let tempDirURL: URL = URL(fileURLWithPath: NSTemporaryDirectory())
        let stripExtension = source.deletingPathExtension()
        let filenameStub = stripExtension.pathComponents.last!
        
        forwardURL = tempDirURL.appendingPathComponent(filenameStub + "-forward.caf")
        backwardURL = tempDirURL.appendingPathComponent(filenameStub + "-backward.caf")
        
        let err = convertAndReverse(source as CFURL!, forwardURL as CFURL!, backwardURL as CFURL!)
        
        print ("converter done, err is \(err)")
    }
    
}
