//
//  PlayerView.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 16/3/10.
//  Copyright © 2016年 zhongzhendong. All rights reserved.
//

import UIKit
import AVFoundation

typealias PlayerBackBlock = () -> ()

protocol PlayerControlInterface: class {
    func seekToProgress(progress: Float)
    func play()
    func pause()
    func switchFullScreen()
}

class PlayerView: UIView{
    
    var videoURL: NSURL? {
        didSet{
            startPlayer()
        }
    }
    
    internal lazy var player: AVPlayer? = {
        if let videoURL = self.videoURL {
            let playerItem = AVPlayerItem(URL: videoURL)
            let player = AVPlayer(playerItem: playerItem)
            
            return player
        }else {
            return nil
        }
    }()
    
    internal lazy var playerLayer: AVPlayerLayer? = {
        if let player = self.player{
            let playerLayer = AVPlayerLayer(player: player)
            return playerLayer
        }else {
            return nil
        }
    }()
    
    var playerControlView = PlayerControlView()
    var timer: NSTimer?
    var isFullScreen = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func awakeFromNib() {
        commonInit()
    }
    
    private func commonInit() {
        addSubview(playerControlView)
        playerControlView.snp_makeConstraints { (make) -> Void in
            make.edges.equalTo(self)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let playerLayer = playerLayer {
            playerLayer.frame = self.bounds
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        player?.currentItem?.removeObserver(self, forKeyPath: "status")
        player?.currentItem?.removeObserver(self, forKeyPath: "loadedTimeRanges")
        player?.currentItem?.removeObserver(self, forKeyPath: "playbackBufferEmpty")
        player?.currentItem?.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
    }
    
    //MARK:- player kvo 监听
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if object !== player?.currentItem {
            return
        }
        
        if player?.status == .ReadyToPlay {
            
        }else if keyPath == "loadedTimeRanges" {
            let timeInterval = availableDuration()
            let duration = player?.currentItem?.duration
            let totalDuration = CMTimeGetSeconds(duration!)
            
            let progress = timeInterval / totalDuration
            
            playerControlView.progressView.setProgress(Float(progress), animated: false)
        }
    }
    
    func playerTimerAction() {
        if player?.currentItem?.duration.timescale == 0 {
            return
        }
        
        if let playerItem = player?.currentItem {
            
            let timeProgress = CMTimeGetSeconds(playerItem.currentTime()) / (Float64(playerItem.duration.value) / Float64(playerItem.duration.timescale))
            
            playerControlView.videoSlider.maximumValue = 1
            playerControlView.videoSlider.value = Float(timeProgress)
            
            let currentMin = CMTimeGetSeconds(playerItem.currentTime()) / 60
            let currentSec = CMTimeGetSeconds(playerItem.currentTime()) % 60
            
            playerControlView.currentTimeLabel.text = String(format: "%02ld:%02ld", Int(currentMin), Int(currentSec))
            
            let totalMin = Float(playerItem.duration.value) / Float(playerItem.duration.timescale) / 60
            let totalSec = Float(playerItem.duration.value) / Float(playerItem.duration.timescale) % 60
            
            playerControlView.totalTimeLabel.text = String(format: "%02ld:%02ld", Int(totalMin), Int(totalSec))
        }
        
    }
    
    //MARK:- private func
    
    func startPlayer() {
        if let playerLayer = playerLayer, let player = player {
            
            layer.insertSublayer(playerLayer, atIndex: 0)
            player.play()
            
            playerControlView.playerControl = self
            
//            NSNotificationCenter.defaultCenter().addObserver(self, selector: "videoDidPlayEnd:", name: AVPlayerItemDidPlayToEndTimeNotification, object: nil)
            
            
            player.currentItem?.addObserver(self, forKeyPath: "status", options: .New, context: nil)
            player.currentItem?.addObserver(self, forKeyPath: "loadedTimeRanges", options: .New, context: nil)
            player.currentItem?.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .New, context: nil)
            player.currentItem?.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .New, context: nil)
            
            timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: "playerTimerAction", userInfo: nil, repeats: true)
        }
    }
    
    func availableDuration() -> NSTimeInterval {
        let loadedTimeRanges = player?.currentItem?.loadedTimeRanges
        let timeRange = loadedTimeRanges?.first?.CMTimeRangeValue
        
        let startSeconds = CMTimeGetSeconds((timeRange?.start)!)
        let durationSeconds = CMTimeGetSeconds((timeRange?.duration)!)
        
        return startSeconds + durationSeconds
    }
    
    func setInterfaceOrientation(orientation: UIInterfaceOrientation) {
        UIDevice.currentDevice().setValue(orientation.rawValue, forKey: "orientation")
    }
}

extension PlayerView: PlayerControlInterface {
    
    func play() {
        if let player = player {
            player.play()
        }
    }
    
    func pause() {
        if let player = player {
            player.pause()
        }
    }
    
    func switchFullScreen() {
        
        let orientation = UIDevice.currentDevice().orientation

        switch (orientation) {
            
        case .PortraitUpsideDown, .FaceUp :
            setInterfaceOrientation(.LandscapeRight)
            
        case .Portrait:
            setInterfaceOrientation(.LandscapeRight)
            
        case .LandscapeLeft:
            setInterfaceOrientation(.Portrait)
            
        case .LandscapeRight:
            setInterfaceOrientation(.Portrait)
        default:
            break
        }
    }
    
    func seekToProgress(progress: Float) {
        if let player = player  where player.status == AVPlayerStatus.ReadyToPlay {
            let total = (player.currentItem?.duration.value)! / Int64((player.currentItem?.duration.timescale)!)
            let dragedSecond = Int64(floorf(Float(total) * progress))
            let dragedCMTime = CMTimeMake(dragedSecond, 1)
            
            player.pause()
            player.seekToTime(dragedCMTime, completionHandler: { (finish) -> Void in
                player.play()
            })
        }
    }
}
