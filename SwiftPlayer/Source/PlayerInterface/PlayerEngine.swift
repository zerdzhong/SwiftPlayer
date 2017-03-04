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
    var delegate: PlayerCallback?
    
    //MARK:- PlayerItemInfo
    var duration : TimeInterval = 0
    var loadedDuration : TimeInterval = 0
    var currentTime : TimeInterval = 0
    
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

extension PlayerEngine: PlayerCallback {
    func player_playStart() {
        
    }
    
    func player_playFinish() {
        
    }
    
    func player_playFailed() {
        
    }
    
    func player_play() {
        
    }
    
    func player_pause() {
        
    }
    
    func player_stop() {
        
    }
    
    func player_seekTo(time: TimeInterval) {
        
    }
    
    func player_seek(fromTime: TimeInterval, loadedTime: TimeInterval, toTime: TimeInterval) {
        
    }
}
