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
    case AudioUintCreateError
    case StreamFormatGetError
    case StreamFormatSetError
    case RenderCallbackSetError
    case AudioUintInitError
}

typealias AudioManagerOutputCallback = (data :Array<Float>, frameCount:Int, channelCount: Int) -> ()

class AudioManager: NSObject {
    
    private var audioUint =  AudioUnit()
    
    private var outputFormat = AudioStreamBasicDescription()
    private var numBytesPerSample: UInt32 = 0
    private var numOutputChannels: UInt32 = 0
    
    var samplingRate: Float64 = 0
    
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
        
        var status = OSStatus()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(handleAudioRouteChange), name: AVAudioSessionRouteChangeNotification, object: nil)
        
        AVAudioSession.sharedInstance().addObserver(self, forKeyPath: "outputVolume", options: [.Initial, .New], context: nil);
        
        var description = AudioComponentDescription()
        description.componentType = OSType(kAudioUnitType_Output)
        description.componentSubType = OSType(kAudioUnitSubType_RemoteIO)
        description.componentManufacturer = OSType(kAudioUnitManufacturer_Apple)
        
        let component = AudioComponentFindNext(nil, &description)
        status = AudioComponentInstanceNew(component, &audioUint)
        
        if status != noErr {
            throw AudioManagerError.AudioUintCreateError
        }
        
        var size = UInt32(sizeof(AudioStreamBasicDescription))
        
        status = AudioUnitGetProperty(audioUint, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &outputFormat, &size)
        
        if status != noErr {
            throw AudioManagerError.StreamFormatGetError
        }
        
        outputFormat.mSampleRate = samplingRate;
        
        status = AudioUnitSetProperty(audioUint, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &outputFormat, size)
        
        if status != noErr {
            throw AudioManagerError.StreamFormatSetError
        }
        
        numBytesPerSample = outputFormat.mBitsPerChannel / 8;
        numOutputChannels = outputFormat.mChannelsPerFrame;
        
        var callbackStruct = AURenderCallbackStruct(inputProc: renderCallback, inputProcRefCon:  UnsafeMutablePointer(unsafeAddressOf(self)))
        
        status = AudioUnitSetProperty(audioUint, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callbackStruct, UInt32(sizeof(AURenderCallbackStruct)))
        
        if status != noErr {
            throw AudioManagerError.RenderCallbackSetError
        }
        
        status = AudioUnitInitialize(audioUint)
        
        if status != noErr {
            throw AudioManagerError.RenderCallbackSetError
        }
    }
    
    func handleAudioRouteChange() -> Void {
        
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath == "outputVolume", let volume = (change?[NSKeyValueChangeNewKey] as? NSNumber)?.floatValue {
            print("Volume: \(volume)")
        }
    }
    
    private let renderCallback: AURenderCallback = { (inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in

        
        return noErr
    }
}
