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
    
    fileprivate var isAudioSessionInited = false
    
    func setupAudioSession() -> Void {
        if !isAudioSessionInited {
            NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
            isAudioSessionInited = true
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playback)), mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        }catch let error as NSError {
            print("error:\(error)")
        }
    }
    
    func setActive(_ active : Bool) {
        do {
            try AVAudioSession.sharedInstance().setActive(active)
        } catch {
            
        }
    }
    
    @objc func handleInterruption(_ notifacation: Notification) -> Void {
        let reason = (notifacation.userInfo![AVAudioSessionInterruptionTypeKey] as AnyObject).uintValue
        
        if reason ==  AVAudioSession.InterruptionType.began.rawValue {
            print("AVAudioSessionInterruptionTypeBegan")
            setActive(false)
        }else if reason == AVAudioSession.InterruptionType.ended.rawValue {
            print("AVAudioSessionInterruptionTypeEnded")
            setActive(true)
        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
	return input.rawValue
}
