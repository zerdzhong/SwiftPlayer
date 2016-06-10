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
    
    var outputCallback: AudioManagerOutputCallback?
    
    var samplingRate: Float64 = 0
    var isPlaying: Bool = false
    
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
    
    func play() -> Bool {
        if !isPlaying {
            if self.activeAudioSession() {
                let result = AudioOutputUnitStart(audioUint)
                isPlaying = (result == noErr)
            }
        }
        
        return isPlaying
    }
    
    func pause() -> Void {
        if isPlaying {
            AudioOutputUnitStop(audioUint)
        }
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
    
    private let renderCallback: AURenderCallback = { (inRefCon:UnsafeMutablePointer<Void>, ioActionFlags:UnsafeMutablePointer<AudioUnitRenderActionFlags>, inTimeStamp:UnsafePointer<AudioTimeStamp>, inBusNumber:UInt32, inNumberFrames:UInt32, ioData:UnsafeMutablePointer<AudioBufferList>) -> OSStatus in

        let mySelf = Unmanaged<AudioManager>.fromOpaque(COpaquePointer(inRefCon)).takeRetainedValue()
        mySelf.renderFrames(inNumberFrames, ioData: ioData)
        
        return noErr
    }
    
    private func renderFrames(frameCount: UInt32, ioData: UnsafeMutablePointer<AudioBufferList>) {
        for iBuffer in 0..<ioData.memory.mNumberBuffers {
            let bufferPointer = unsafeBitCast(ioData.memory.mBuffers, UnsafeMutablePointer<AudioBuffer>.self)
            
            memset(bufferPointer.advancedBy(Int(iBuffer)), 0, Int(bufferPointer.advancedBy(Int(iBuffer)).memory.mDataByteSize))
        }
        
        if let callback = outputCallback where isPlaying {
            
        }
    }
}
