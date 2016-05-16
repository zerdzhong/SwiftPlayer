//
//  PlayerDecoder.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 4/21/16.
//  Copyright © 2016 zhongzhendong. All rights reserved.
//

import Foundation

enum DecodeError: ErrorType {
    case OpenFileFailed
    case StreamInfoNotFound
    case CodecNotFound
    case OpenCodecFailed
    case AllocateFrameFailed
    case EmptyStreams
}

@objc enum MovieFrameType: Int {
    case Audio
    case Video
    case Subtitle
    case Artwork
}

@objc enum VideoFrameFormat: Int {
    case RGB
    case YUV
}

@objc protocol MovieFrame {
    var type:MovieFrameType { get }
    var position: Double { get set }
    var duration: Double { get set }
}

extension MovieFrame {
    var position: Double {
        return 0
    }
    
    var duration: Double {
        return 0
    }
}

@objc class VideoFrame: NSObject, MovieFrame {
    var format: VideoFrameFormat?
    var width: UInt = 0
    var height: UInt = 0
    
    @objc var position: Double = 0.0
    @objc var duration: Double = 0.0
    
    @objc var type: MovieFrameType {
        return .Video
    }
}

@objc class VideoFrameYUV: VideoFrame {
    var luma = NSData()
    var chromaB = NSData()
    var chromaR = NSData()
}

@objc class VideoFrameRGB: VideoFrame {
    var lineSize: UInt = 0
    var rgb = NSData()
}

typealias SwsContext = COpaquePointer

class PlayerDecoder: NSObject {
    
    var fps: Double = 0
    var isEOF: Bool = false
    var disableDeinterlacing: Bool = true
    
    private var reader = PlayerFileReader()
    
    private var videoCodecContext: UnsafeMutablePointer<AVCodecContext>?
    
    private var videoStream: UnsafeMutablePointer<AVStream>?
    private var videoStreamIndex: Int32 = -1
    private var videoFrame: UnsafeMutablePointer<AVFrame>?
    
    private var audioStream: UnsafeMutablePointer<AVStream>?
    
    private var frameFormat: VideoFrameFormat?
    
    private var videoTimeBase: Double = 0
    
    private var picture: AVPicture?
    private var pictureValid: Bool = false
    
//    private var swsContext = SwsContext()
    
    
    func openFile(path: NSString) throws {
        do {
            try reader.openInputFile(path)
            
            if reader.videoCodecContext == nil {
                throw DecodeError.CodecNotFound
            }
            
            self.videoCodecContext = reader.videoCodecContext
            self.videoStreamIndex = reader.videoStreamIndex
            
            videoFrame = av_frame_alloc()
            
        } catch let error as DecodeError{
            throw error
        }
    }
    
    func setupVideoFrameFormat(format: VideoFrameFormat) -> Bool {
        if (format == .YUV) && (videoCodecContext != nil) && (videoCodecContext?.memory.pix_fmt == AV_PIX_FMT_YUV420P || videoCodecContext?.memory.pix_fmt == AV_PIX_FMT_YUVJ420P) {
            frameFormat = VideoFrameFormat.YUV
            return true
        }
        frameFormat = VideoFrameFormat.RGB
        
        return frameFormat == format
    }
    
    func asyncDecodeFrames(minDuration: Double, completeBlock:(frames:Array<VideoFrame>?)->()) -> Void {
        reader.asyncReadFrame { (packet) in
            completeBlock(frames: self.decodeFrames(&packet))
        }
    }
    
    func decodeFrames(inout packet: AVPacket) -> Array<VideoFrame>? {
        
//        if videoStream == nil && audioStream == nil{
//            return nil
//        }
        
        if videoCodecContext == nil || videoFrame == nil {
            return nil
        }
        
        var result = Array<VideoFrame>()
        
        if packet.stream_index == videoStreamIndex {
            var packetSize = packet.size
            
            while packetSize > 0 {
                var gotFrame:Int32 = 0
                let length = avcodec_decode_video2(videoCodecContext!, videoFrame!, &gotFrame, &packet)
                
                if length < 0 {
                    print("decode video error, skip packet")
                    break;
                }
                
                if gotFrame > 0 {
                    let decodedFrame = handleVideoFrame(videoFrame!, codecContext: videoCodecContext!)
                    
                    if let frame = decodedFrame {
                        result.append(frame)
                    }
                }
                
                if 0 != length {
                    packetSize -= length
                }
            }
        }
        
        return result
    }
    
    private func handleVideoFrame(frame: UnsafeMutablePointer<AVFrame>,
                                  codecContext: UnsafeMutablePointer<AVCodecContext>)
        -> VideoFrame?{
            if frame.memory.data.0 == nil {
                return nil
            }
            
            var decodedFrame: VideoFrame?
            
            if frameFormat == .Some(.YUV)  {
                let yuvFrame = VideoFrameYUV()
                yuvFrame.luma = copyFrameData(frame.memory.data.0,
                                              lineSize: frame.memory.linesize.0,
                                              width: codecContext.memory.width,
                                              height: codecContext.memory.height)
                
                yuvFrame.chromaB = copyFrameData(frame.memory.data.1,
                                                 lineSize: frame.memory.linesize.1,
                                                 width: codecContext.memory.width / 2,
                                                 height: codecContext.memory.height / 2)
                
                yuvFrame.chromaR = copyFrameData(frame.memory.data.2,
                                                 lineSize: frame.memory.linesize.1,
                                                 width: codecContext.memory.width / 2,
                                                 height: codecContext.memory.height / 2)
                
                decodedFrame = yuvFrame
                
            }else if frameFormat == .Some(.RGB) {
//                if swsContext != nil && !setupScaler() {
//                    print("fail setup video scaler")
//                    return nil
//                }
//                
//                sws_scale(swsContext, unsafeBitCast(videoFrame.memory.data, UnsafePointer<UnsafePointer<UInt8>>.self), unsafeBitCast(videoFrame.memory.linesize, UnsafePointer<Int32>.self), 0, videoCodecCtx.memory.height, picture!.data, picture!.linesize)
                
//                let rgbFrame = VideoFrameRGB()
//                rgbFrame.rgb = picture?.data.0
            }
            
            decodedFrame?.width = UInt(codecContext.memory.width)
            decodedFrame?.height = UInt(codecContext.memory.height)
            decodedFrame?.position = Double(av_frame_get_best_effort_timestamp(frame)) * videoTimeBase
            
            let frameDuration = Double(av_frame_get_pkt_duration(frame))
            if (frameDuration > 0) {
                
                decodedFrame?.duration = frameDuration * videoTimeBase;
                decodedFrame?.duration += Double(frame.memory.repeat_pict) * videoTimeBase * 0.5;
                
                //if (_videoFrame->repeat_pict > 0) {
                //    LoggerVideo(0, @"_videoFrame.repeat_pict %d", _videoFrame->repeat_pict);
                //}
                
            } else {
                
                // sometimes, ffmpeg unable to determine a frame duration
                // as example yuvj420p stream from web camera
                decodedFrame?.duration = 1.0 / fps;
            }
            
            return decodedFrame
    }
    
}

extension PlayerDecoder {
    func frameWidth() -> UInt {
        if let codecCtx = videoCodecContext {
            return UInt(codecCtx.memory.width)
        }
        
        return 0
    }
    
    func frameHeight() -> UInt {
        if let codecCtx = videoCodecContext {
            return UInt(codecCtx.memory.height)
        }
        
        return 0
    }
    
    func vaildVideo() -> Bool {
        return videoStreamIndex != -1
    }
}

private func audioCodecIsSupported(audio: UnsafePointer<AVCodecContext>) -> Bool
{
    if (audio.memory.sample_fmt == AV_SAMPLE_FMT_S16) {
        
//        let audioManager = AudioManager()
//        return  (int)audioManager.samplingRate == audio->sample_rate &&
//        audioManager.numOutputChannels == audio->channels;
    }
    return false;
}



private func copyFrameData(source: UnsafeMutablePointer<UInt8>, lineSize: Int32, width: Int32, height: Int32) -> NSMutableData{
    
    let width = Int(min(width, lineSize))
    let height = Int(height)
    var src = source
    
    let data: NSMutableData! = NSMutableData(length: width * height)
    let dataPointer = data?.mutableBytes
    
    if  var dst = dataPointer {
        for _ in 0..<height {
            
            memcpy(dst, src, width)
            dst += width
            src = src.advancedBy(Int(lineSize))
        }
    }
    
    return data
}


