//
//  ReversePlaybackModel.swift
//  AudioReverser
//
//  Created by Chris Adamson on 2/15/17.
//  Copyright © 2017 Subsequently & Furthermore, Inc. All rights reserved.
//

import Foundation
import AVFoundation

let USE_SWIFT_CONVERTER = true

class ReversePlaybackModel {

    enum State {
        case loading
        case error
        case ready
    }
    
    var forwardURL: URL?
    var backwardURL: URL?

    var onStateChange : ((State) -> Void)?
    var state : State = .loading {
        didSet {
            onStateChange?(state)
        }
    }
    
    init (source: URL) {
        let tempDirURL: URL = URL(fileURLWithPath: NSTemporaryDirectory())
        let stripExtension = source.deletingPathExtension()
        let filenameStub = stripExtension.pathComponents.last!
        
        forwardURL = tempDirURL.appendingPathComponent(filenameStub + "-forward.caf")
        backwardURL = tempDirURL.appendingPathComponent(filenameStub + "-backward.caf")

        DispatchQueue.global(qos: .default).async {
            var err: OSStatus = noErr
            if USE_SWIFT_CONVERTER {
                err = convertAndReverseSwift(sourceURL: source as CFURL,
                                             forwardURL: self.forwardURL as! CFURL,
                                             backwardURL: self.backwardURL as! CFURL)
            } else {
                err = convertAndReverse(source as CFURL!, self.forwardURL as CFURL!, self.backwardURL as CFURL!)
            }
            print ("converter done, err is \(err)")
            self.state = (err == noErr) ? .ready : .error
        }
    }
    
}
