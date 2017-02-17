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

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var artistLabel: UILabel!
    @IBOutlet var coverArtImageView: UIImageView!
    @IBOutlet var scrubber: UISlider!
    @IBOutlet var timeLabel: UILabel!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var convertingHUDView: UIView!
    
    // outlet collections
    @IBOutlet var metadataViews: [UIView]!
    @IBOutlet var playbackControls: [UIControl]!
    
    private var reversePlaybackModel : ReversePlaybackModel?
    
    var songFile : SongFile? {
        didSet {
            if let songFile = songFile {
                reversePlaybackModel = ReversePlaybackModel(source: songFile.url)
                reversePlaybackModel?.onStateChange = { [weak self] _ in
                    guard let strongSelf = self else { return }
                    DispatchQueue.main.async {
                        strongSelf.updateUI()
                    }
                }
            }
            updateUI()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUI()
    }
    
    private func updateUI() {
        guard view != nil else { return }

        // metadata
        guard let songFile = songFile else {
            for metadataView in metadataViews  {
               metadataView.isHidden = true
            }
            return
        }
        for metadataView in metadataViews  {
            metadataView.isHidden = false
        }
        titleLabel.text = songFile.title
        artistLabel.text = songFile.artist
        coverArtImageView.image = songFile.albumArt
        
        // TODO: handle model.state.Error
        
        // playback
        guard let reversePlaybackModel = reversePlaybackModel, reversePlaybackModel.state == .Ready else {
            for playbackControl in playbackControls {
                playbackControl.isEnabled = false
            }
            convertingHUDView.isHidden = false
            return
        }
        for playbackControl in playbackControls {
            playbackControl.isEnabled = true
        }
        convertingHUDView.isHidden = true
        
        // TODO: build players

    }
    
    
    @IBAction func handleBackwardTapped(_ sender: Any) {
    }
    
    @IBAction func handleForwardTapped(_ sender: Any) {
    }
    
    @IBAction func handleScrubberValueChanged(_ sender: Any) {
    }
    
    
}

