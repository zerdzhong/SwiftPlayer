//
//  PlayerDecoder.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 4/21/16.
//  Copyright © 2016 zhongzhendong. All rights reserved.
//

import Foundation

enum DecodeError: ErrorType {
    case OpenFileFailed, StreamInfoNotFound
    case CodecNotFound, OpenCodecFailed, AllocateFrameFailed
    case EmptyStreams
}

enum VideoFrameFormat {
    case RGB
    case YUV
}

class VideoFrame {
    var format: VideoFrameFormat?
    var width: UInt = 0
    var height: UInt = 0
}

class VideoFrameYUV: VideoFrame {
    var luma: NSData?
    var chromaB: NSData?
    var chromaR: NSData?
}

class VideoFrameRGB: VideoFrame {
    var lineSize: UInt = 0
    var rgb: NSData?
}

typealias SwsContext = COpaquePointer

class PlayerDecoder: NSObject {
    
    var fps: Double = 0
    var isEOF: Bool = false
    var disableDeinterlacing: Bool = true
    
    private var formatContext: UnsafeMutablePointer<AVFormatContext>?
    private var videoCodecContext: UnsafeMutablePointer<AVCodecContext>?
    
    private var videoStream: UnsafeMutablePointer<AVStream>?
    private var videoStreamIndex: Int32 = 0
    private var videoFrame: UnsafeMutablePointer<AVFrame>?
    
    private var audioStream: UnsafeMutablePointer<AVStream>?
    
    private var frameFormat: VideoFrameFormat?
    
    private var videoTimeBase: Double = 0
    
    private var picture: AVPicture?
    private var pictureValid: Bool = false
    
    private var swsContext = SwsContext()
    
    
    func openFile(path: NSString) throws {
        av_register_all()
        
        var formatContext = avformat_alloc_context()
        
        if avformat_open_input(&formatContext, path.cStringUsingEncoding(NSUTF8StringEncoding), nil, nil) != 0{
            if formatContext != nil {
                avformat_free_context(formatContext)
            }
            
            throw DecodeError.OpenFileFailed
        }
        
        if avformat_find_stream_info(formatContext, nil) < 0{
            avformat_close_input(&formatContext)
            
            throw DecodeError.StreamInfoNotFound
        }
        
        av_dump_format(formatContext, 0, path.cStringUsingEncoding(NSUTF8StringEncoding), 0)
        
        self.formatContext = formatContext
        
        do {
            try openAudioStreams()
            try openVideoStreams()
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
    
    func decodeFrames(minDuration: Double) -> Array<VideoFrame>? {
        if videoStream == nil &&  audioStream == nil{
            return nil
        }
        
        if let formatCtx = formatContext, let videoCodecCtx = videoCodecContext, let videoFrame = videoFrame {
            var result = Array<VideoFrame>()
            var decodedDuration = 0
            var finished = false
            
            var packet = AVPacket()
            
            while !finished {
                if av_read_frame(formatCtx, &packet) < 0 {
                    isEOF = true
                    break
                }
                
                if packet.stream_index == videoStreamIndex {
                    var packetSize = packet.size
                    
                    while packetSize > 0 {
                        var gotFrame:Int32 = 0
                        let length = avcodec_decode_video2(videoCodecCtx, videoFrame, &gotFrame, &packet)
                        
                        if length < 0 {
                            print("decode video error, skip packet")
                            break;
                        }
                        
                        if gotFrame != 0 {
//                            if !disableDeinterlacing && videoFrame.memory.interlaced_frame != 0{
//                                avpicture_deinterlace((AVPicture*)_videoFrame,
//                                                      (AVPicture*)_videoFrame,
//                                                      _videoCodecCtx->pix_fmt,
//                                    _videoCodecCtx->width,
//                                    _videoCodecCtx->height);
//                            }
                            
                            
                            
                            if videoFrame.memory.data.0 == nil {
                                break;
                            }
                            
                            if frameFormat == .Some(.YUV)  {
                                let yuvFrame = VideoFrameYUV()
                                yuvFrame.luma = copyFrameData(videoFrame.memory.data.0,
                                                              lineSize: videoFrame.memory.linesize.0,
                                                              width: videoCodecCtx.memory.width,
                                                              height: videoCodecCtx.memory.height)
                                
                                yuvFrame.chromaB = copyFrameData(videoFrame.memory.data.1,
                                                                 lineSize: videoFrame.memory.linesize.1,
                                                                 width: videoCodecCtx.memory.width / 2,
                                                                 height: videoCodecCtx.memory.height / 2)
                                
                                yuvFrame.chromaR = copyFrameData(videoFrame.memory.data.2,
                                                                 lineSize: videoFrame.memory.linesize.1,
                                                                 width: videoCodecCtx.memory.width / 2,
                                                                 height: videoCodecCtx.memory.height / 2)
                                
                                
                                
                            }else if frameFormat == .Some(.RGB) {
                                if swsContext != nil && !setupScaler() {
                                    print("fail setup video scaler")
                                    return nil
                                }
                                
//                                sws_scale(swsContext, unsafeBitCast(videoFrame.memory.data, UnsafePointer<UnsafePointer<UInt8>>.self), unsafeBitCast(videoFrame.memory.linesize, UnsafePointer<Int32>.self), 0, videoCodecCtx.memory.height, picture!.data, picture!.linesize)
                            }
                            
                        }
                    }
                }
            }
        }
        
        
        return nil
    }
    
    private func handleVideoFrame() {
        
    }
    
    private func setupScaler() -> Bool{
        closeScaler()
        
        if var picture = self.picture, let videoCodecCtx = self.videoCodecContext {
            pictureValid = (avpicture_alloc(&picture, AV_PIX_FMT_RGB24, videoCodecCtx.memory.width, videoCodecCtx.memory.height) == 0)
            
            if !pictureValid {
                return false
            }
            
            swsContext = sws_getCachedContext(swsContext, videoCodecCtx.memory.width, videoCodecCtx.memory.height, videoCodecCtx.memory.pix_fmt, videoCodecCtx.memory.width, videoCodecCtx.memory.height, AV_PIX_FMT_RGB24, SWS_FAST_BILINEAR, nil, nil, nil)
            
            return (swsContext != nil)
            
        }
        
        return false
    }
    
    private func closeScaler() {
        if swsContext != nil {
            sws_freeContext(swsContext)
            swsContext = nil
        }
        
        if var picture = self.picture where pictureValid {
            avpicture_free(&picture)
            pictureValid = false
        }
    }
    
    //MARK:- VideoStream
    
    private func openVideoStreams() throws {
        if let context = formatContext {
            let videoStreams = collectStreams(context, codecType: AVMEDIA_TYPE_VIDEO)
            
            if videoStreams.count == 0 {
                throw DecodeError.EmptyStreams
            }
            
            for videoStreamIndex in videoStreams {
                let stream = context.memory.streams[videoStreamIndex]
                if (stream.memory.disposition & AV_DISPOSITION_ATTACHED_PIC) == 0 {
                    do {
                        try openVideoStream(stream)
                        self.videoStreamIndex = Int32(videoStreamIndex)
                        break
                    } catch {
                        
                    }
                }
            }
        }
    }
    
    private func openVideoStream(stream: UnsafeMutablePointer<AVStream>) throws {
        
        let codecContex = stream.memory.codec
        let codec = avcodec_find_decoder(codecContex.memory.codec_id)
        
        if codec == nil {
            throw DecodeError.CodecNotFound
        }
        
        if avcodec_open2(codecContex, codec, nil) < 0 {
            throw DecodeError.OpenCodecFailed
        }
        
        videoFrame = av_frame_alloc()
        
        if videoFrame == nil {
            throw DecodeError.AllocateFrameFailed
        }
        
        var timeBase, fps: CDouble
        if (stream.memory.time_base.den != 0) && (stream.memory.time_base.num != 0) {
            timeBase = av_q2d(stream.memory.time_base)
        }else if (stream.memory.codec.memory.time_base.den != 0) && (stream.memory.codec.memory.time_base.num != 0) {
            timeBase = av_q2d(stream.memory.codec.memory.time_base)
        }else {
            timeBase = 0.4
        }
        
        if stream.memory.codec.memory.ticks_per_frame != 1{
            print("WARNING: st.codec.ticks_per_frame=\(stream.memory.codec.memory.ticks_per_frame)")
        }
        
        if (stream.memory.avg_frame_rate.den != 0) && (stream.memory.avg_frame_rate.num != 0) {
            fps = av_q2d(stream.memory.avg_frame_rate)
        }else if (stream.memory.r_frame_rate.den != 0) && (stream.memory.r_frame_rate.num != 0) {
            fps = av_q2d(stream.memory.r_frame_rate)
        }else {
            fps = 1.0 / timeBase
        }
        
        self.videoTimeBase = timeBase
        self.fps = fps
        self.videoStream = stream
        self.videoCodecContext = codecContex
    }
    
    //MARK:- AudioStream
    private func openAudioStreams() throws {
        if let context = formatContext {
            let videoStreams = collectStreams(context, codecType: AVMEDIA_TYPE_AUDIO)
            
            if videoStreams.count == 0 {
                throw DecodeError.EmptyStreams
            }
            
            for videoStreamIndex in videoStreams {
                let stream = context.memory.streams[videoStreamIndex]

                do {
                    try openAudioStream(stream)
                    break
                } catch {
                    
                }
            }
        }
    }
    
    private func openAudioStream(stream: UnsafeMutablePointer<AVStream>) throws {
        let codecContex = stream.memory.codec
        let codec = avcodec_find_decoder(codecContex.memory.codec_id)
        
        if codec == nil {
            throw DecodeError.CodecNotFound
        }
        
        if avcodec_open2(codecContex, codec, nil) < 0 {
            throw DecodeError.OpenCodecFailed
        }
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

private func collectStreams(formatContext: UnsafePointer<AVFormatContext>, codecType: AVMediaType) -> Array<Int>{

    var mutableArray = Array<Int>()

    for i in 0..<Int(formatContext.memory.nb_streams) {
        if codecType == formatContext.memory.streams[i].memory.codec.memory.codec_type {
            mutableArray.append(i)
        }
    }
    
    return mutableArray
}

private func copyFrameData(source: UnsafeMutablePointer<UInt8>, lineSize: Int32, width: Int32, height: Int32) -> NSMutableData?{
    let width = Int(min(width, lineSize))
    let height = Int(height)
    var offset = 0
    
    let data = NSMutableData(length: width * height)
    let dataPointer = data?.mutableBytes
    
    if  var dst = dataPointer {
        for _ in 0..<height {
            source.assignFrom(source, count: offset)
            memcpy(dst, source, width)
            dst += width
            offset += Int(lineSize)
        }
    }
    
    return data
}


