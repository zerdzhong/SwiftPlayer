//
//  AudioManager.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 5/28/16.
//  Copyright © 2016 zhongzhendong. All rights reserved.
//

import Foundation
import AVFoundation

enum AudioManagerError: ErrorType {
    case CategorySetError
}

typealias AudioManagerOutputCallback = (data :Array<Float>, frameCount:Int, channelCount: Int) -> ()

class AudioManager: NSObject {
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume")
    }

    func activeAudioSession() -> Bool {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            try setupAudio()
        }catch {
            return false
        }
        
        return false
    }
    
    private func setupAudio() throws {
        do {
           try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        }catch {
            throw AudioManagerError.CategorySetError
        }
         
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(handleAudioRouteChange), name: AVAudioSessionRouteChangeNotification, object: nil)
        
        AVAudioSession.sharedInstance().addObserver(self, forKeyPath: "outputVolume", options: [.Initial, .New], context: nil);
    }
    
    func handleAudioRouteChange() -> Void {
        
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath == "outputVolume", let volume = (change?[NSKeyValueChangeNewKey] as? NSNumber)?.floatValue {
            print("Volume: \(volume)")
        }
    }
}
