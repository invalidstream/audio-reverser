//
//  SongFile.swift
//  AudioReverser
//
//  Created by Chris Adamson on 2/15/17.
//  Copyright © 2017 Subsequently & Furthermore, Inc. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

struct SongFile {
    
    let url: URL
    var artist: String!
    var title: String!
    var albumArt: UIImage?
    
    static let knownFileExtensions = ["mp3", "m4a", "aac", "mp4"]
    
    init? (fileURL: URL) {
        let fileExtension = fileURL.pathExtension
        guard SongFile.knownFileExtensions.contains(fileExtension) else { return nil }
        
        let asset = AVAsset(url: fileURL)
        
        self.url = fileURL
        populateMyMetadata(from: asset.commonMetadata)
        
    }
    
    private mutating func populateMyMetadata(from metadata: [AVMetadataItem]) {
        for item in metadata{
            guard let key = item.commonKey else { continue }
            switch key {
            case AVMetadataCommonKeyArtist:
                self.artist = item.stringValue
            case AVMetadataCommonKeyTitle:
                self.title = item.stringValue
            case AVMetadataCommonKeyArtwork:
                if let imageData = item.dataValue, let image = UIImage(data: imageData) {
                    albumArt = image
                }
            default:
                NSLog ("skipping: \(key)")
            }
        }
        // TODO: if albumArt not set, load the asynch album art and get it later
    }
    
}
