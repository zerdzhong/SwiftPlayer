//
//  PlayerView.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 16/3/10.
//  Copyright © 2016年 zhongzhendong. All rights reserved.
//

import UIKit
import AVFoundation

enum PlayerState {
    case playing
    case pause
    case buffering
    case seeking
}

class PlayerView: UIView {
    
    var videoURL: URL? {
        didSet {
            if  videoURL != nil{
                startPlayer()
            }
        }
    }
    
    internal lazy var player: AVPlayer? = {
        if let videoURL = self.videoURL {
            let playerItem = AVPlayerItem(url: videoURL)
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
    
    weak var delegate: PlayerCallbackDelegate?
    var timeObserver: Any?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let playerLayer = playerLayer {
            playerLayer.frame = self.bounds
        }
    }
    
    deinit {
        print("deinit")
    }
    
    //MARK:- private func
    
    func startPlayer() {
        if let playerLayer = playerLayer, let player = player {
            
            layer.insertSublayer(playerLayer, at: 0)
            player.play()

            addPlayerObserver()
            addTimeObserver()
        }
    }
    
    func destory() {
        pause()
        removePlayerObserver()
        removeTimeObserver()
    }
    
    func addPlayerObserver() {
        guard let playerItem = player?.currentItem else {
            return
        }
        playerItem.addObserver(self, forKeyPath: "status", options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: "presentationSize", options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: "currentItem", options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: "rate", options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: "airPlayVideoActive", options: .new, context: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(didPlayToEndNotification(notification:)), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.addObserver(self, selector: #selector(failedPlayToEndNotification(notification:)), name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
    }
    
    func removePlayerObserver() {
        guard let playerItem = player?.currentItem else {
            return
        }
        playerItem.removeObserver(self, forKeyPath: "status")
        playerItem.removeObserver(self, forKeyPath: "playbackBufferEmpty")
        playerItem.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
        playerItem.removeObserver(self, forKeyPath: "presentationSize")
        playerItem.removeObserver(self, forKeyPath: "currentItem")
        playerItem.removeObserver(self, forKeyPath: "rate")
        playerItem.removeObserver(self, forKeyPath: "airPlayVideoActive")
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
    }
    
    func addTimeObserver() {
        guard let player = self.player, self.timeObserver == nil else {
            return
        }
        
        self.timeObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMake(24, 24), queue: nil) { [weak self] (time) in
            self?.delegate?.playerObserver()
        }
    }
    
    func removeTimeObserver() {
        guard let timeObserver = self.timeObserver else {
            return
        }
        self.player?.removeTimeObserver(timeObserver)
        self.timeObserver = nil
    }
    
    func availableDuration() -> TimeInterval {
        let loadedTimeRanges = player?.currentItem?.loadedTimeRanges
        let timeRange = loadedTimeRanges?.first?.timeRangeValue
        
        let startSeconds = CMTimeGetSeconds((timeRange?.start)!)
        let durationSeconds = CMTimeGetSeconds((timeRange?.duration)!)
        
        return startSeconds + durationSeconds
    }
    
    func setInterfaceOrientation(_ orientation: UIInterfaceOrientation) {
        UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
    }
}

//MARK:- 视频通知

extension PlayerView {
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard object as! AVPlayerItem? === player?.currentItem, let keyPathString = keyPath else {
            return
        }
        
        if keyPathString == "status" {
    
            if player?.currentItem?.status == .readyToPlay {
                delegate?.playerReadPlay()
            } else if player?.currentItem?.status == .failed {
                delegate?.playerLoadFailed()
            } else if player?.currentItem?.status == .unknown {
                delegate?.playerLoadFailed()
            }
        } else if keyPathString == "playbackBufferEmpty" {
            if (player?.currentItem?.isPlaybackBufferEmpty)! {
                delegate?.playerBufferEmpty()
            }
        } else if keyPathString == "playbackLikelyToKeepUp" {
            if (player?.currentItem?.isPlaybackLikelyToKeepUp)! {
                delegate?.playerKeepToPlay()
            }
        } else if keyPathString == "airPlayVideoActive" {
            
        } else if keyPathString == "currentItem" {
            print("player.item change")
        } 
        
    }
    
    func didPlayToEndNotification(notification: NSNotification) -> Void {
        delegate?.playerPlayEnd(reason: .finish)
    }
    
    func failedPlayToEndNotification(notification: NSNotification) -> Void {
        delegate?.playerPlayEnd(reason: .error)
    }
}

//MARK:- 视频信息接口

extension PlayerView: PlayerItemInfo {
    var currentTime: TimeInterval {
        get {
            if let playerItem = player?.currentItem {
                return CMTimeGetSeconds(playerItem.currentTime())
            }else {
                return CMTimeGetSeconds(kCMTimeIndefinite)
            }
        }
    }
    
    var duration: TimeInterval {
        get {
            if let playerItem = player?.currentItem {
                return CMTimeGetSeconds(playerItem.duration)
            }else {
                return CMTimeGetSeconds(kCMTimeIndefinite)
            }
        }
    }
    
    var loadedDuration: TimeInterval {
        get {
            return 0
        }
    }
}

//MARK:- 播放控制接口
extension PlayerView: PlayerControllable {
    
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
    
    func stop() {
        pause()
        removePlayerObserver()
        removeTimeObserver()
    }
    
    func switchFullScreen() {
        
        let orientation = UIDevice.current.orientation

        switch (orientation) {
            
        case .portraitUpsideDown, .faceUp :
            setInterfaceOrientation(.landscapeRight)
            
        case .portrait:
            setInterfaceOrientation(.landscapeRight)
            
        case .landscapeLeft:
            setInterfaceOrientation(.portrait)
            
        case .landscapeRight:
            setInterfaceOrientation(.portrait)
        default:
            break
        }
    }
    
    func seekTo(progress: Float) {
        if let player = player, player.status == AVPlayerStatus.readyToPlay {
            let total = (player.currentItem?.duration.value)! / Int64((player.currentItem?.duration.timescale)!)
            let dragedSecond = Int64(floorf(Float(total) * progress))
            let dragedCMTime = CMTimeMake(dragedSecond, 1)
            
            player.pause()
            player.seek(to: dragedCMTime, completionHandler: { (finish) -> Void in
                player.play()
            })
        }
    }
}
