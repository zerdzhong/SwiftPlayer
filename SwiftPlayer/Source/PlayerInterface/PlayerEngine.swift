//
//  PlayerEngine.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 2017/2/16.
//  Copyright © 2017年 zhongzhendong. All rights reserved.
//

import Foundation
import UIKit

class PlayerEngine: PlayerControllable, PlayerItemInfo {
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
            let player = PlayerView()
            player.videoURL = URL(string: url)
            playerView = player
            playerControl = player
            playerItemInfo = player
            break
        }
        
    }
    
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
