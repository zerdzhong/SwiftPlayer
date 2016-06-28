//
//  AudioManager.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 5/28/16.
//  Copyright © 2016 zhongzhendong. All rights reserved.
//

import Foundation
import AVFoundation

class AudioManager: NSObject {
    
    static let sharedInstance = AudioManager()
    
    private var isAudioSessionInited = false
    
    func setupAudioSession() -> Void {
        if !isAudioSessionInited {
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(handleInterruption), name: AVAudioSessionInterruptionNotification, object: nil)
            isAudioSessionInited = true
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        }catch let error as NSError {
            print("error:\(error)")
        }
    }
    
    func setActive(active : Bool) {
        do {
            try AVAudioSession.sharedInstance().setActive(active)
        } catch {
            
        }
    }
    
    func handleInterruption(notifacation: NSNotification) -> Void {
        let reason = notifacation.userInfo![AVAudioSessionInterruptionTypeKey]?.unsignedIntegerValue
        
        if reason ==  AVAudioSessionInterruptionType.Began.rawValue {
            print("AVAudioSessionInterruptionTypeBegan")
            setActive(false)
        }else if reason == AVAudioSessionInterruptionType.Ended.rawValue {
            print("AVAudioSessionInterruptionTypeEnded")
            setActive(true)
        }
    }
}
