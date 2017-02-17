//
//  PlayerEngine.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 2017/2/16.
//  Copyright © 2017年 zhongzhendong. All rights reserved.
//

import Foundation

class PlayerEngine: PlayerControllable, PlayerItemInfo {
    var delegate: PlayerCallback?
    
    //MARK:- PlayerItemInfo
    var duration : TimeInterval = 0
    var loadedDuration : TimeInterval = 0
    var currentTime : TimeInterval = 0
    
    //MARK:- public func
    func startPlayer(url: String, decodeType: PlayerDecodeType) -> Void {
        
    }
    
    //MARK:- PlayerControllable
    func play() {
        
    }
    func pause() {
        
    }
    func stop() {
        
    }
    func seekTo(time: TimeInterval) {
        
    }
}
