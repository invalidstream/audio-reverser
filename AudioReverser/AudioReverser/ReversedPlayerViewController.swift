//
//  DetailViewController.swift
//  AudioReverser
//
//  Created by Chris Adamson on 2/15/17.
//  Copyright © 2017 Subsequently & Furthermore, Inc. All rights reserved.
//

import UIKit
import AVFoundation

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
    
    private var forwardPlayer: AVPlayer?
    private var backwardPlayer: AVPlayer?
    private var forwardTime: CMTime = kCMTimeZero
    
    private var reversePlaybackModel : ReversePlaybackModel?
    
    var songFile : SongFile? {
        didSet {
            if let songFile = songFile {
                reversePlaybackModel = ReversePlaybackModel(source: songFile.url)
                reversePlaybackModel?.onStateChange = { [weak self] state in
                    guard let strongSelf = self else { return }
                    DispatchQueue.main.async {
                        if state == .ready {
                            strongSelf.buildPlayers()
                        }
                        strongSelf.updateUI()
                    }
                }
            }
            updateUI()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        forwardTime = kCMTimeZero
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
        guard let reversePlaybackModel = reversePlaybackModel, reversePlaybackModel.state == .ready else {
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
        
    }
    
    private func buildPlayers() {
        guard let reversePlaybackModel = reversePlaybackModel,
            let forwardURL = reversePlaybackModel.forwardURL,
            let backwardURL = reversePlaybackModel.backwardURL else { return }
        
        
        // kill any old players
        forwardPlayer?.pause()
        backwardPlayer?.pause()
        forwardTime = kCMTimeZero
        
        // make new players
        forwardPlayer = AVPlayer(url: forwardURL)
        backwardPlayer = AVPlayer(url: backwardURL)

        forwardPlayer?.currentItem?.asset.loadValuesAsynchronously(forKeys: ["duration"]) {
            guard let duration = self.forwardPlayer?.currentItem?.asset.duration else { return }
            DispatchQueue.main.async() {
                self.scrubber.minimumValue = 0.0
                self.scrubber.maximumValue = Float(CMTimeGetSeconds(duration))
                self.updateTimeLabel()
                self.updateScrubberTime()
            }
        }
        
        // observe time changes
        forwardPlayer?.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(0.25, 600), queue: nil) { [weak self] cmTime in
            if let strongSelf = self {
                strongSelf.forwardTime = cmTime
                strongSelf.updateTimeLabel()
                strongSelf.updateScrubberTime()
            }
        }
        
        backwardPlayer?.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(0.25, 600), queue: nil) { [weak self] cmTime in
            if let strongSelf = self, let duration = strongSelf.forwardPlayer?.currentItem?.duration,
                let backwardPlayer = strongSelf.backwardPlayer, backwardPlayer.rate != 0 {
                strongSelf.forwardTime = CMTimeSubtract(duration, cmTime)
                strongSelf.updateTimeLabel()
                strongSelf.updateScrubberTime()
            }
        }
    }

    private func updateTimeLabel() {
        let totalSeconds = CMTimeGetSeconds(forwardTime)
        let seconds = Int(totalSeconds.truncatingRemainder(dividingBy: 60.0))
        let minutes = Int(totalSeconds/60)
        let secondsString = seconds < 10 ? "0\(seconds)" : "\(seconds)"
        timeLabel.text = "\(minutes):\(secondsString)"
    }
    
    private func updateScrubberTime() {
        scrubber.value = Float(CMTimeGetSeconds(forwardTime))
    }
    
    @IBAction func handleBackwardTapped(_ sender: Any) {
        forwardPlayer?.rate = 0
        let backwardTime = backwardTimeForForwardTime(forwardTime)
        backwardPlayer?.seek(to: backwardTime)
        backwardPlayer?.play()
    }
    
    @IBAction func handleForwardTapped(_ sender: Any) {
        backwardPlayer?.rate = 0
        forwardPlayer?.seek(to: forwardTime)
        forwardPlayer?.play()
    }
    
    @IBAction func handlePauseTapped(_ sender: Any) {
        forwardPlayer?.pause()
        backwardPlayer?.pause()
    }
    
    @IBAction func handleScrubberValueChanged(_ sender: UISlider) {
        let scrubTime = CMTimeMakeWithSeconds(Float64(sender.value), 600)
        
        forwardTime = scrubTime
        forwardPlayer?.seek(to: forwardTime)
        backwardPlayer?.seek(to: backwardTimeForForwardTime(forwardTime))
        updateTimeLabel()
    }

    @IBAction func handleScrubberTouchDown(_ sender: Any) {
        forwardPlayer?.pause()
        backwardPlayer?.pause()
    }
    
    private func backwardTimeForForwardTime(_ time: CMTime) -> CMTime {
        guard let duration = forwardPlayer?.currentItem?.duration else { return kCMTimeZero }
        return CMTimeSubtract(duration, time)
    }
    
}

// TODO: custom +, -, == operator overloads for CMTime would be nice to demo

