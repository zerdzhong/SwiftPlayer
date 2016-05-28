//
//  AudioManager.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 5/28/16.
//  Copyright © 2016 zhongzhendong. All rights reserved.
//

import Foundation
import AVFoundation

typealias AudioManagerOutputCallback = (data :Array<Float>, frameCount:Int, channelCount: Int) -> ()

class AudioManager: NSObject {

    func activeAudioSession() -> Bool {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            
        }catch {
            return false
        }
        
        return false
    }
    
    private func setupAudio() throws {
        AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
    }
}
