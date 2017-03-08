//
//  PlayerEngine.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 2017/2/16.
//  Copyright © 2017年 zhongzhendong. All rights reserved.
//

import Foundation
import UIKit

class PlayerEngine: PlayerItemInfo {
    weak var delegate: PlayerCallbackDelegate?
    
    //MARK:- PlayerItemInfo
    var duration : TimeInterval {
        get {
            if let playerItemInfo = self.playerItemInfo {
                return playerItemInfo.duration
            }
            
            return 0
        }
    }
    var loadedDuration : TimeInterval {
        get {
            if let playerItemInfo = self.playerItemInfo {
                return playerItemInfo.loadedDuration
            }
            
            return 0
        }
    }
    var currentTime : TimeInterval {
        get {
            if let playerItemInfo = self.playerItemInfo {
                return playerItemInfo.currentTime
            }
            
            return 0
        }
    }
    
    var playerView: UIView?
    var playerControl: PlayerControllable?
    var playerItemInfo: PlayerItemInfo?
    
    //MARK:- public func
    func startPlayer(url: String, decodeType: PlayerDecodeType) {
        switch decodeType {
        case .software: break
        case .hardware:
            let playerView = PlayerView()
            playerView.delegate = self
            
            if url.contains("http") {
                playerView.videoURL = URL(string: url)
            }else {
                playerView.videoURL = URL(fileURLWithPath: url)
            }
            
            self.playerView = playerView
            playerControl = playerView
            playerItemInfo = playerView
            break
        }
        
    }
    
    func destoryPlayer() {
        playerControl?.stop()
    }
    
    deinit {
        print("deinit")
    }
}

extension PlayerEngine: PlayerControllable {
    //MARK:- PlayerControllable
    func play() {
        guard let playerControl = self.playerControl else {
            return
        }
        
        playerControl.play()
    }
    func pause() {
        guard let playerControl = self.playerControl else {
            return
        }
        
        playerControl.pause()
    }
    func stop() {
        guard let playerControl = self.playerControl else {
            return
        }
        
        playerControl.stop()
    }
    func seekTo(progress: Float) {
        guard let playerControl = self.playerControl else {
            return
        }
        
        playerControl.seekTo(progress: progress)
    }
    func switchFullScreen() {
        guard let playerControl = self.playerControl else {
            return
        }
        
        playerControl.switchFullScreen()
    }
}

extension PlayerEngine: PlayerCallbackDelegate {
    func playerReadPlay() {
        delegate?.playerKeepToPlay()
    }
    func playerLoadFailed() {
        delegate?.playerLoadFailed()
    }
    func playerBufferEmpty() {
        delegate?.playerBufferEmpty()
    }
    func playerKeepToPlay() {
        delegate?.playerKeepToPlay()
    }
    func playerPlayEnd(reason: PlayerEndReason) {
        delegate?.playerPlayEnd(reason: reason)
    }
    func playerObserver() {
        delegate?.playerObserver()
    }
}
