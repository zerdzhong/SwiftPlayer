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

enum MovieFrameType {
    case Audio
    case Video
    case Subtitle
    case Artwork
}

enum VideoFrameFormat {
    case RGB
    case YUV
}

protocol MovieFrame {
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

class VideoFrame: MovieFrame {
    var format: VideoFrameFormat?
    var width: UInt = 0
    var height: UInt = 0
    
    var position: Double = 0.0
    var duration: Double = 0.0
    
    var type: MovieFrameType {
        return .Video
    }
}

class VideoFrameYUV: VideoFrame {
    var luma = NSData()
    var chromaB = NSData()
    var chromaR = NSData()
}

class VideoFrameRGB: VideoFrame {
    var lineSize: UInt = 0
    var rgb = NSData()
}

typealias SwsContext = COpaquePointer

class PlayerDecoder: NSObject {
    
    var fps: Double = 0
    var isEOF: Bool = false
    var disableDeinterlacing: Bool = true
    
    private var pFormatCtx: UnsafeMutablePointer<AVFormatContext>?
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
        
        do {
            try openVideoStreams(formatContext)
        } catch let error as DecodeError{
            throw error
        }
        
        self.pFormatCtx = formatContext
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
        let dispatchQueue = dispatch_queue_create("SwiftPlayerDecoder", DISPATCH_QUEUE_SERIAL)
        
        dispatch_async(dispatchQueue) {
            completeBlock(frames: self.decodeFrames(minDuration))
        }
    }
    
    func decodeFrames(minDuration: Double) -> Array<VideoFrame>? {
        
        if videoStream == nil &&  audioStream == nil{
            return nil
        }
        
        if let formatCtx = self.pFormatCtx,
            let videoCodecCtx = self.videoCodecContext,
            let videoFrame = self.videoFrame
        {
            var result = Array<VideoFrame>()
            var decodedDuration = Double(0)
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
                        var gotFrame:Int32 = 1
                        let length = avcodec_decode_video2(videoCodecCtx, videoFrame, &gotFrame, &packet)
                        
                        if length < 0 || gotFrame == 0{
                            print("decode video error, skip packet")
                            break;
                        }
                        
                        let decodedFrame = handleVideoFrame(videoFrame, codecContext: videoCodecCtx)
                        
                        if let frame = decodedFrame {
                            result.append(frame)
                            
                            decodedDuration += frame.duration
                            if (decodedDuration > minDuration) {
                                finished = true
                            }
                        }
                        
                        if 0 != length {
                            packetSize -= length
                        }
                    }
                }
                
                av_packet_unref(&packet)
            }
            
            return result
        }
        
        
        return nil
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
    
//    private func setupScaler() -> Bool{
//        closeScaler()
//
//        if var picture = self.picture, let videoCodecCtx = self.videoCodecContext {
//            pictureValid = (avpicture_alloc(&picture, AV_PIX_FMT_RGB24, videoCodecCtx.memory.width, videoCodecCtx.memory.height) == 0)
//
//            if !pictureValid {
//                return false
//            }
//            
//            swsContext = sws_getCachedContext(swsContext, videoCodecCtx.memory.width, videoCodecCtx.memory.height, videoCodecCtx.memory.pix_fmt, videoCodecCtx.memory.width, videoCodecCtx.memory.height, AV_PIX_FMT_RGB24, SWS_FAST_BILINEAR, nil, nil, nil)
//            
//            return (swsContext != nil)
//            
//        }
//        
//        return false
//    }
//    
//    private func closeScaler() {
//        if swsContext != nil {
//            sws_freeContext(swsContext)
//            swsContext = nil
//        }
//        
//        if var picture = self.picture where pictureValid {
//            avpicture_free(&picture)
//            pictureValid = false
//        }
//    }
//    
    //MARK:- VideoStream
    
    private func openVideoStreams(formartCtx: UnsafeMutablePointer<AVFormatContext>) throws {
        videoStreamIndex = -1
        let videoStreams = collectStreamIndexs(formartCtx, codecType: AVMEDIA_TYPE_VIDEO)
        
        if videoStreams.count == 0 {
            throw DecodeError.EmptyStreams
        }
        
        for videoStreamIndex in videoStreams {
            let stream = formartCtx.memory.streams[videoStreamIndex]
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
        if let context = self.pFormatCtx {
            let videoStreams = collectStreamIndexs(context, codecType: AVMEDIA_TYPE_AUDIO)
            
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

private func collectStreamIndexs(formatContext: UnsafePointer<AVFormatContext>, codecType: AVMediaType) -> Array<Int>{

    var streamIndexs = Array<Int>()

    for i in 0..<Int(formatContext.memory.nb_streams) {
        if codecType == formatContext.memory.streams[i].memory.codec.memory.codec_type {
            streamIndexs.append(i)
        }
    }
    
    return streamIndexs
}

private func copyFrameData(source: UnsafeMutablePointer<UInt8>, lineSize: Int32, width: Int32, height: Int32) -> NSMutableData{
    let width = Int(min(width, lineSize))
    let height = Int(height)
    var src = source
    
    let data: NSMutableData! = NSMutableData(length: width * height)
    let dataPointer = data?.mutableBytes
    
    if  var dst = dataPointer {
        for _ in 0..<height {
            
            memcpy(dst, source, width)
            dst += width
            src = src.advancedBy(Int(lineSize))
        }
    }
    
    return data
}


