//
//  PlayerProtocol.swift
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

protocol PlayerCallbackDelegate: class {
    func playerReadPlay()
    func playerLoadFailed()
    func playerBufferEmpty()
    func playerKeepToPlay()
    func playerPlayEnd(reason: PlayerEndReason)
    func playerObserver()
}
