//
//  DetailViewController.swift
//  AudioReverser
//
//  Created by Chris Adamson on 2/15/17.
//  Copyright © 2017 Subsequently & Furthermore, Inc. All rights reserved.
//

import UIKit

class ReversedPlayerViewController: UIViewController {

    @IBOutlet weak var detailDescriptionLabel: UILabel!

    private var reversePlaybackModel : ReversePlaybackModel?
    
    var songFile : SongFile? {
        didSet {
            if let songFile = songFile {
                reversePlaybackModel = ReversePlaybackModel(source: songFile.url)
            }
            if view != nil {
                // TODO: would be nice to eliminate double refreshes
                updateUI()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUI()
    }
    
    private func updateUI() {
        
    }
    
}

