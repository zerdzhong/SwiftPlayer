//
//  PlayerDisplayView.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 2020/6/16.
//  Copyright © 2020 zhongzhendong. All rights reserved.
//

import UIKit
import AVFoundation

class PlayerDisplayView: UIView {
    
    var videoURL: URL? {
        didSet {
            if videoURL != nil {
                startPlayer()
            }
        }
    }
    
    internal lazy var playerLayer: AVSampleBufferDisplayLayer = {
		let playerLayer = AVSampleBufferDisplayLayer()
		return playerLayer
    }()
	
	internal lazy var decoder : PlayerDecoder = {
		return PlayerDecoder()
	}()
    
    weak var delegate: PlayerCallbackDelegate?
    var timeObserver: Any?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
	
		playerLayer.frame = self.bounds
    }
    
    deinit {
        print("PlayerView deinit")
    }
    
    //MARK:- private func
    
    func startPlayer() {
		
		guard let url = videoURL else {
			return
		}
		
        layer.insertSublayer(playerLayer, at: 0)
		do {
			try decoder.openFile(url.absoluteString as NSString)
		} catch let err as DecodeError {
			print("open file error \(err)")
		} catch {
			print("open file unkonw error")
		}
	
    }
    
}
//MARK:- 视频信息接口

extension PlayerDisplayView: PlayerItemInfo {
    var currentTime: TimeInterval {
        get {
            return 0
        }
    }
    
    var duration: TimeInterval {
        get {
           return 0
        }
    }
    
    var loadedDuration: TimeInterval {
        get {
            return 0
        }
    }
}

//MARK:- 播放控制接口
extension PlayerDisplayView: PlayerControllable {
    
    func play() {
		decoder.decodeCallback = { (pixelBuffer: CVPixelBuffer, pts: Double) in
			
			let currentTime = CMTimeGetSeconds(CMClockGetTime(CMClockGetHostTimeClock()))
			let presentTime = CMTimeMakeWithSeconds(currentTime + pts, preferredTimescale: Int32(self.decoder.getCurrentFps()))
			
			CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
			
			var timeInfo = CMSampleTimingInfo(duration: CMTime.invalid, presentationTimeStamp: presentTime, decodeTimeStamp: presentTime)
			var videoInfo : CMVideoFormatDescription? = nil
			
			let res = CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescriptionOut: &videoInfo)
			
			if res != 0 {
				print("CMVideoFormatDescriptionCreateForImageBuffer error")
				return
			}
			
			var sampleBuffer: CMSampleBuffer? = nil
			
			CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault,
											   imageBuffer: pixelBuffer,
											   dataReady: true,
											   makeDataReadyCallback: nil,
											   refcon: nil,
											   formatDescription: videoInfo!,
											   sampleTiming: &timeInfo,
											   sampleBufferOut: &sampleBuffer)
			
			CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
			
			guard let sample = sampleBuffer else {
				print("Create sample buffer failed!")
				return
			}
			
			self.playerLayer.enqueue(sample)
		}
		decoder.startDecode()
    }
    
    func pause() {
    }
    
    func stop() {
    }
    
    func switchFullScreen() {
    }
    
    func seekTo(progress: Float) {
    }
}
