//
//  ReversePlaybackModel.swift
//  AudioReverser
//
//  Created by Chris Adamson on 2/15/17.
//  Copyright © 2017 Subsequently & Furthermore, Inc. All rights reserved.
//

import Foundation
import AVFoundation

private enum CONVERTER_OPTION {
    case useToolboxSwift
    case useToolboxC
    case useAVAudioFile
}

private let converterOption: CONVERTER_OPTION = .useToolboxC

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
            guard let forwardURL = self.forwardURL, let backwardURL = self.backwardURL
                else { return }
            var err: OSStatus = noErr
            switch converterOption {
            case .useToolboxSwift:
                err = convertAndReverseSwift(sourceURL: source as CFURL,
                                             forwardURL: forwardURL as CFURL,
                                             backwardURL: backwardURL as CFURL)
            case .useToolboxC:
                err = convertAndReverse(source as CFURL,
                                        forwardURL as CFURL,
                                        backwardURL as CFURL)
            case .useAVAudioFile:
                do {
                    try convertAndReverseAVAudioFile(sourceURL: source as CFURL,
                                                     forwardURL: forwardURL as CFURL,
                                                     backwardURL: backwardURL as CFURL)
                } catch {
                    print ("convertAndReverseAVAudioFile failed: \(error)")
                    err = -99999
                }
            }
            print ("converter done, err is \(err)")
            self.state = (err == noErr) ? .ready : .error
        }
    }
    
}
