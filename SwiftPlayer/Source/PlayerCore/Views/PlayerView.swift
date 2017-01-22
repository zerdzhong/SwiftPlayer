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

enum PlayerState {
    case playing
    case pause
    case buffering
    case seeking
}

protocol PlayerControlProtocol: class {
    func seekToProgress(_ progress: Float)
    func play()
    func pause()
    func switchFullScreen()
}

protocol PlayerItemInfoProtocol: class {
    func currentTime() -> TimeInterval!
    func totalTime() -> TimeInterval!
}

class PlayerView: UIView{
    
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
    
    var playerControlView = PlayerControlView()
    var timer: Timer?
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
    
    fileprivate func commonInit() {
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
        print("deinit")
        NotificationCenter.default.removeObserver(self)
        player?.currentItem?.removeObserver(self, forKeyPath: "status")
        player?.currentItem?.removeObserver(self, forKeyPath: "loadedTimeRanges")
        player?.currentItem?.removeObserver(self, forKeyPath: "playbackBufferEmpty")
        player?.currentItem?.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
    }
    
    //MARK:- player kvo 监听
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if object !== player?.currentItem {
            return
        }
        
        if let keyPathString = keyPath {
            
            if keyPathString == "status" {
                if player?.status == .readyToPlay {
                    //添加手势
                    playerControlView.addPanGesture()
                }
            }else if keyPathString == "loadedTimeRanges" {
                let timeInterval = availableDuration()
                let duration = player?.currentItem?.duration
                let totalDuration = CMTimeGetSeconds(duration!)
                
                let progress = timeInterval / totalDuration
                
                playerControlView.progressView.setProgress(Float(progress), animated: false)
            }
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
            let currentSec = CMTimeGetSeconds(playerItem.currentTime()).truncatingRemainder(dividingBy: 60)
            
            playerControlView.currentTimeLabel.text = String(format: "%02ld:%02ld", Int(currentMin), Int(currentSec))
            
            let totalMin = Float(playerItem.duration.value) / Float(playerItem.duration.timescale) / 60
            let totalSec = (Float(playerItem.duration.value) / Float(playerItem.duration.timescale)).truncatingRemainder(dividingBy: 60)
            
            playerControlView.totalTimeLabel.text = String(format: "%02ld:%02ld", Int(totalMin), Int(totalSec))
        }
        
    }
    
    //MARK:- private func
    
    func startPlayer() {
        if let playerLayer = playerLayer, let player = player {
            
            layer.insertSublayer(playerLayer, at: 0)
            player.play()
            
            playerControlView.playerControl = self
            playerControlView.playerItemInfo = self
            
//            NSNotificationCenter.defaultCenter().addObserver(self, selector: "videoDidPlayEnd:", name: AVPlayerItemDidPlayToEndTimeNotification, object: nil)
            
            player.currentItem?.addObserver(self, forKeyPath: "status", options: .new, context: nil)
            player.currentItem?.addObserver(self, forKeyPath: "loadedTimeRanges", options: .new, context: nil)
            player.currentItem?.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .new, context: nil)
            player.currentItem?.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .new, context: nil)
            
            timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(PlayerView.playerTimerAction), userInfo: nil, repeats: true)
        }
    }
    
    func destoryPlayer() {
        timer?.invalidate()
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

//MARK:- 视频信息接口

extension PlayerView: PlayerItemInfoProtocol {
    func currentTime() -> TimeInterval! {
        if let playerItem = player?.currentItem {
            return CMTimeGetSeconds(playerItem.currentTime())
        }else {
            return CMTimeGetSeconds(kCMTimeIndefinite)
        }
    }
    
    func totalTime() -> TimeInterval! {
        if let playerItem = player?.currentItem {
            return CMTimeGetSeconds(playerItem.duration)
        }else {
            return CMTimeGetSeconds(kCMTimeIndefinite)
        }
    }
}

//MARK:- 播放控制接口
extension PlayerView: PlayerControlProtocol {
    
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
    
    func seekToProgress(_ progress: Float) {
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
