//
//  PlayerUIProtocol.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 2017/2/16.
//  Copyright © 2017年 zhongzhendong. All rights reserved.
//

import Foundation

protocol PlayerControllable {
    func play()
    func pause()
    func stop()
    func seekTo(progress: Float)
    func switchFullScreen()
}

protocol PlayerItemInfo {
    var duration : TimeInterval {get}
    var loadedDuration : TimeInterval {get}
    var currentTime : TimeInterval {get}
}

protocol PlayerCallback {
    func player_playStart()
    func player_playFinish()
    func player_playFailed()
    
    func player_play()
    func player_pause()
    func player_stop()
    func player_seekTo(time: TimeInterval)
    func player_seek(fromTime: TimeInterval, loadedTime: TimeInterval, toTime: TimeInterval)
}
