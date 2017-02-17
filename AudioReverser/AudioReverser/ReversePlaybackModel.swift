//
//  ReversePlaybackModel.swift
//  AudioReverser
//
//  Created by Chris Adamson on 2/15/17.
//  Copyright © 2017 Subsequently & Furthermore, Inc. All rights reserved.
//

import Foundation
import AVFoundation

class ReversePlaybackModel {

    enum State {
        case Loading
        case Error
        case Ready
    }
    
    var forwardURL: URL?
    var backwardURL: URL?

    var onStateChange : ((State) -> Void)?
    var state : State = .Loading {
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
            let err = convertAndReverse(source as CFURL!, self.forwardURL as CFURL!, self.backwardURL as CFURL!)
            print ("converter done, err is \(err)")
            self.state = (err == noErr) ? .Ready : .Error
        }
    }
    
}
