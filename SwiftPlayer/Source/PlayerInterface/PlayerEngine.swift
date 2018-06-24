//
//  PlayerEngine.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 2017/2/16.
//  Copyright © 2017年 zhongzhendong. All rights reserved.
//

import Foundation
import UIKit

class PlayerEngine {
    weak var delegate: PlayerCallbackDelegate?
    
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
            
            if url.isValidHTTPURL() {
                playerView.videoURL = URL(string: url)
            } else {
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
        print("PlayerEngine deinit")
    }
}


//MARK:- PlayerItemInfo
extension PlayerEngine: PlayerItemInfo {
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
}

//MARK:- PlayerControllable
extension PlayerEngine: PlayerControllable {
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

//MARK:- PlayerCallbackDelegate
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
