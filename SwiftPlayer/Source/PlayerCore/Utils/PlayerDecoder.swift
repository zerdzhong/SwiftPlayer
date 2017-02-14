//
//  PlayerDecoder.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 4/21/16.
//  Copyright © 2016 zhongzhendong. All rights reserved.
//

import Foundation
import Accelerate

enum DecodeError: Error {
    case openFileFailed
    case streamInfoNotFound
    case codecNotFound
    case openCodecFailed
    case reSamplerFailed
    case allocateFrameFailed
    case emptyStreams
}

enum MovieFrameType {
    case audio
    case video
    case subtitle
    case artwork
}

enum VideoFrameFormat {
    case rgb
    case yuv
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
        return .video
    }
}

class VideoFrameYUV: VideoFrame {
    var luma = Data()
    var chromaB = Data()
    var chromaR = Data()
}

class VideoFrameRGB: VideoFrame {
    var lineSize: UInt = 0
    var rgb = Data()
}

class AudioFrame: MovieFrame {
    
    var samples = Data()
    
    var position: Double = 0.0
    var duration: Double = 0.0
    
    var type: MovieFrameType {
        return .audio
    }
}

typealias SwsContext = OpaquePointer
typealias SwrContext = OpaquePointer

class PlayerDecoder: NSObject {
    
    var fps: Double = 0
    var isEOF: Bool = false
    var disableDeinterlacing: Bool = true
    var decoding: Bool = false;
    
    fileprivate var pFormatCtx: UnsafeMutablePointer<AVFormatContext>?
    
    fileprivate var videoCodecContext: UnsafeMutablePointer<AVCodecContext>?
    fileprivate var videoStreamIndex: Int32 = -1
    fileprivate var videoStream: UnsafeMutablePointer<AVStream>?
    fileprivate var videoFrame: UnsafeMutablePointer<AVFrame>?

    fileprivate var audioCodecContext: UnsafeMutablePointer<AVCodecContext>?
    fileprivate var audioStreamIndex: Int32 = -1
    fileprivate var audioStream: UnsafeMutablePointer<AVStream>?
    fileprivate var audioFrame: UnsafeMutablePointer<AVFrame>?
    fileprivate var swrContext: UnsafeMutablePointer<SwrContext>?
    
    fileprivate var subtitleIndexs = Array<Int>()
    
    fileprivate var audioTimeBase: Float = -1
    
    fileprivate var frameFormat: VideoFrameFormat?
    
    fileprivate var videoTimeBase: Double = 0
    
    fileprivate var picture: AVPicture?
    fileprivate var pictureValid: Bool = false
    
    fileprivate let dispatchQueue = DispatchQueue(label: "SwiftPlayerDecoder", attributes: [])
    
    //    private var swsContext = SwsContext()
    
    func openFile(_ path: NSString) throws {
        av_register_all()
        
        var formatContext = avformat_alloc_context()
        
        if avformat_open_input(&formatContext, path.cString(using: String.Encoding.utf8.rawValue), nil, nil) != 0{
            if formatContext != nil {
                avformat_free_context(formatContext)
            }
            
            throw DecodeError.openFileFailed
        }
        
        if avformat_find_stream_info(formatContext, nil) < 0{
            avformat_close_input(&formatContext)
            
            throw DecodeError.streamInfoNotFound
        }
        
        av_dump_format(formatContext, 0, path.cString(using: String.Encoding.utf8.rawValue), 0)
        
        do {
            try openVideoStreams(formatContext!)
        } catch let error as DecodeError{
            throw error
        }
        
        do {
            try openAudioStreams(formatContext!)
        }catch let error as DecodeError{
            throw error
        }
        
        subtitleIndexs = collectStreamIndexs(formatContext!, codecType: AVMEDIA_TYPE_SUBTITLE)
        
        self.pFormatCtx = formatContext
    }
    
    func setupVideoFrameFormat(_ format: VideoFrameFormat) -> Bool {
        if (format == .yuv) && (videoCodecContext != nil) && (videoCodecContext?.pointee.pix_fmt == AV_PIX_FMT_YUV420P || videoCodecContext?.pointee.pix_fmt == AV_PIX_FMT_YUVJ420P) {
            frameFormat = VideoFrameFormat.yuv
            return true
        }
        frameFormat = VideoFrameFormat.rgb
        
        return frameFormat == format
    }
    
    func asyncDecodeFrames(_ minDuration: Double, completeBlock:@escaping (_ frames:Array<MovieFrame>?)->()) -> Void {
        
        if decoding {
            return
        }
        
        decoding = true
        
        dispatchQueue.async {
            completeBlock(self.decodeFrames(minDuration))
            
            self.decoding = false;
        }
    }
    
    func decodeFrames(_ minDuration: Double) -> Array<MovieFrame>? {
        
        if videoStream == nil &&  audioStream == nil{
            return nil
        }
        
        if let formatCtx = self.pFormatCtx,
            let videoCodecCtx = self.videoCodecContext,
            let audioCodecCtx = self.audioCodecContext
        {
            var result = Array<MovieFrame>()
            var decodedDuration = Double(0)
            var finished = false
            
            var packet = AVPacket()
            
            while !finished {
                if av_read_frame(formatCtx, &packet) < 0 {
                    isEOF = true
                    break
                }
                
                if let videoFrame = self.videoFrame, packet.stream_index == videoStreamIndex {
                    var packetSize = packet.size
                    
                    while packetSize > 0 {
                        var gotFrame:Int32 = 0
                        let length = avcodec_decode_video2(videoCodecCtx, videoFrame, &gotFrame, &packet)
                        
                        if length < 0 {
                            print("decode video error, skip packet")
                            break;
                        }
                        
                        if gotFrame > 0 {
                            let decodedFrame = handleVideoFrame(videoFrame, codecContext: videoCodecCtx)
                            
                            if let frame = decodedFrame {
                                result.append(frame)
                                
                                decodedDuration += frame.duration
                                if (decodedDuration > minDuration) {
                                    finished = true
                                }
                            }
                        }
                        
                        if 0 != length {
                            packetSize -= length
                        }
                    }
                }else if let audioFrame = self.audioFrame, packet.stream_index == audioStreamIndex {
                    var packetSize = packet.size
                    
                    while packetSize > 0 {
                        var gotFrame:Int32 = 0
                        let length = avcodec_decode_audio4(audioCodecCtx, audioFrame, &gotFrame, &packet)
                        
                        if  length < 0 {
                            print("decode audio error, skip packet")
                            break;
                        }
                        
                        if gotFrame > 0 {
                            let decodedFrame = handleAudioFrame(audioFrame, codecContext: audioCodecCtx)
                            
                            if let frame = decodedFrame {
                                result.append(frame)
                                
                                decodedDuration += frame.duration
                                if (decodedDuration > minDuration) {
                                    finished = true
                                }
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
    
    fileprivate func handleVideoFrame(_ frame: UnsafeMutablePointer<AVFrame>,
                                  codecContext: UnsafeMutablePointer<AVCodecContext>)
        -> VideoFrame?{
            if frame.pointee.data.0 == nil {
                return nil
            }
            
            var decodedFrame: VideoFrame?
            
            if frameFormat == .some(.yuv)  {
                let yuvFrame = VideoFrameYUV()
                yuvFrame.luma = copyFrameData(frame.pointee.data.0!,
                                              lineSize: frame.pointee.linesize.0,
                                              width: codecContext.pointee.width,
                                              height: codecContext.pointee.height) as Data
                
                yuvFrame.chromaB = copyFrameData(frame.pointee.data.1!,
                                                 lineSize: frame.pointee.linesize.1,
                                                 width: codecContext.pointee.width / 2,
                                                 height: codecContext.pointee.height / 2) as Data
                
                yuvFrame.chromaR = copyFrameData(frame.pointee.data.2!,
                                                 lineSize: frame.pointee.linesize.1,
                                                 width: codecContext.pointee.width / 2,
                                                 height: codecContext.pointee.height / 2) as Data
                
                decodedFrame = yuvFrame
                
            }else if frameFormat == .some(.rgb) {
                //                if swsContext != nil && !setupScaler() {
                //                    print("fail setup video scaler")
                //                    return nil
                //                }
                //
                //                sws_scale(swsContext, unsafeBitCast(videoFrame.pointee.data, UnsafePointer<UnsafePointer<UInt8>>.self), unsafeBitCast(videoFrame.pointee.linesize, UnsafePointer<Int32>.self), 0, videoCodecCtx.pointee.height, picture!.data, picture!.linesize)
                
                //                let rgbFrame = VideoFrameRGB()
                //                rgbFrame.rgb = picture?.data.0
            }
            
            decodedFrame?.width = UInt(codecContext.pointee.width)
            decodedFrame?.height = UInt(codecContext.pointee.height)
            decodedFrame?.position = Double(av_frame_get_best_effort_timestamp(frame)) * videoTimeBase
            
            let frameDuration = Double(av_frame_get_pkt_duration(frame))
            if (frameDuration > 0) {
                
                decodedFrame?.duration = frameDuration * videoTimeBase;
                decodedFrame?.duration += Double(frame.pointee.repeat_pict) * videoTimeBase * 0.5;
                
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
    //            pictureValid = (avpicture_alloc(&picture, AV_PIX_FMT_RGB24, videoCodecCtx.pointee.width, videoCodecCtx.pointee.height) == 0)
    //
    //            if !pictureValid {
    //                return false
    //            }
    //
    //            swsContext = sws_getCachedContext(swsContext, videoCodecCtx.pointee.width, videoCodecCtx.pointee.height, videoCodecCtx.pointee.pix_fmt, videoCodecCtx.pointee.width, videoCodecCtx.pointee.height, AV_PIX_FMT_RGB24, SWS_FAST_BILINEAR, nil, nil, nil)
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
    
    fileprivate func handleAudioFrame(_ frame: UnsafeMutablePointer<AVFrame>,
                                  codecContext: UnsafeMutablePointer<AVCodecContext>)
        -> AudioFrame? {
            if audioFrame?.pointee.data.0  == nil {
                return nil
            }
            
            var numFrames: Int32 = 0
            var audioData: UnsafeMutablePointer<Int16>? = nil
            let numChannels: UInt8 = 1
 
            if swrContext != nil {
//                let bufferSize = av_samples_get_buffer_size(nil, codecContext.pointee.channels, 1, AV_SAMPLE_FMT_S16, 1)
//                
//                swr_convert(context.memory, <#T##out: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>>##UnsafeMutablePointer<UnsafeMutablePointer<UInt8>>#>, audioFrame.pointee.nb_samples * , <#T##in: UnsafeMutablePointer<UnsafePointer<UInt8>>##UnsafeMutablePointer<UnsafePointer<UInt8>>#>, <#T##in_count: Int32##Int32#>)
            } else {
                
                if (codecContext.pointee.sample_fmt != AV_SAMPLE_FMT_S16) {
                    print("bucheck, audio format is invalid")
                    return nil
                }
                
                audioData = unsafeBitCast(audioFrame?.pointee.data.0, to: UnsafeMutablePointer<Int16>.self)
//                audioData = UnsafeMutablePointer<Int16>((audioFrame?.pointee.data.0)!)
                numFrames = (audioFrame?.pointee.nb_samples)!
            }
            
            
            let numElements = Int(numFrames) * Int(numChannels)
            let data = NSMutableData(capacity:numElements * MemoryLayout<Float>.size)
            
            var scale = 1.0 / Float(INT16_MAX)
            vDSP_vflt16(audioData!, 1, unsafeBitCast(data!.mutableBytes, to: UnsafeMutablePointer<Float>.self), 1, UInt(numElements))
            vDSP_vsmul(unsafeBitCast(data!.mutableBytes, to: UnsafeMutablePointer<Float>.self), 1, &scale, unsafeBitCast(data!.mutableBytes, to: UnsafeMutablePointer<Float>.self), 1, UInt(numElements))
            
            let frame = AudioFrame()
            frame.position = Double(av_frame_get_best_effort_timestamp(audioFrame!)) * Double(audioTimeBase)
            frame.duration = Double(av_frame_get_pkt_duration(audioFrame!)) * Double(audioTimeBase)
            frame.samples = data! as Data
            
            if frame.duration == 0 {
                // sometimes ffmpeg can't determine the duration of audio frame
                // especially of wma/wmv format
                // so in this case must compute duration
                frame.duration = Double(frame.samples.count / (MemoryLayout<Float>.size * Int(numChannels) * 2))
            }
            
            
            return frame
    }
    
    //MARK:- VideoStream
    
    fileprivate func openVideoStreams(_ formartCtx: UnsafeMutablePointer<AVFormatContext>) throws {
        videoStreamIndex = -1
        let videoStreams = collectStreamIndexs(formartCtx, codecType: AVMEDIA_TYPE_VIDEO)
        
        if videoStreams.count == 0 {
            throw DecodeError.emptyStreams
        }
        
        for videoStreamIndex in videoStreams {
            let stream = formartCtx.pointee.streams[videoStreamIndex]
            if ((stream?.pointee.disposition)! & AV_DISPOSITION_ATTACHED_PIC) == 0 {
                do {
                    try openVideoStream(stream!)
                    self.videoStreamIndex = Int32(videoStreamIndex)
                    break
                } catch {
                    
                }
            }
        }
    }
    
    fileprivate func openVideoStream(_ stream: UnsafeMutablePointer<AVStream>) throws {
        
        let codecContex = stream.pointee.codec
        let codec = avcodec_find_decoder((codecContex?.pointee.codec_id)!)
        
        if codec == nil {
            throw DecodeError.codecNotFound
        }
        
        if avcodec_open2(codecContex, codec, nil) < 0 {
            throw DecodeError.openCodecFailed
        }
        
        videoFrame = av_frame_alloc()
        
        if videoFrame == nil {
            throw DecodeError.allocateFrameFailed
        }
        
        var timeBase, fps: CDouble
        if (stream.pointee.time_base.den != 0) && (stream.pointee.time_base.num != 0) {
            timeBase = av_q2d(stream.pointee.time_base)
        }else if (stream.pointee.codec.pointee.time_base.den != 0) && (stream.pointee.codec.pointee.time_base.num != 0) {
            timeBase = av_q2d(stream.pointee.codec.pointee.time_base)
        }else {
            timeBase = 0.4
        }
        
        if stream.pointee.codec.pointee.ticks_per_frame != 1{
            print("WARNING: st.codec.ticks_per_frame=\(stream.pointee.codec.pointee.ticks_per_frame)")
        }
        
        if (stream.pointee.avg_frame_rate.den != 0) && (stream.pointee.avg_frame_rate.num != 0) {
            fps = av_q2d(stream.pointee.avg_frame_rate)
        }else if (stream.pointee.r_frame_rate.den != 0) && (stream.pointee.r_frame_rate.num != 0) {
            fps = av_q2d(stream.pointee.r_frame_rate)
        }else {
            fps = 1.0 / timeBase
        }
        
        self.videoTimeBase = timeBase
        self.fps = fps
        self.videoStream = stream
        self.videoCodecContext = codecContex
    }
    
    //MARK:- AudioStream
    fileprivate func openAudioStreams(_ formartCtx: UnsafeMutablePointer<AVFormatContext>) throws {
        audioStreamIndex = -1
        let audioStreams = collectStreamIndexs(formartCtx, codecType: AVMEDIA_TYPE_AUDIO)
        
        if audioStreams.count == 0 {
            throw DecodeError.emptyStreams
        }
        
        for audioStreamIndex in audioStreams {
            let stream = formartCtx.pointee.streams[audioStreamIndex]
            
            do {
                try openAudioStream(stream!)
                self.audioStreamIndex = Int32(audioStreamIndex)
                break
            } catch {
                
            }
        }
    }
    
    fileprivate func openAudioStream(_ stream: UnsafeMutablePointer<AVStream>) throws {
        let codecContex = stream.pointee.codec
        let codec = avcodec_find_decoder((codecContex?.pointee.codec_id)!)
        var swrContext: SwrContext? = nil
        
        if codec == nil {
            throw DecodeError.codecNotFound
        }
        
        if avcodec_open2(codecContex, codec, nil) < 0 {
            throw DecodeError.openCodecFailed
        }
        
        if !audioCodecIsSupported(codecContex!) {
            swrContext = swr_alloc_set_opts(nil,
                                                av_get_default_channel_layout(4),
                                                AV_SAMPLE_FMT_S16,
                                                16,
                                                av_get_default_channel_layout((codecContex?.pointee.channels)!),
                                                (codecContex?.pointee.sample_fmt)!,
                                                (codecContex?.pointee.sample_rate)!,
                                                0, nil)
            
            if swrContext == nil || swr_init(swrContext!) != 0 {
                if swrContext != nil {
                    swr_free(&swrContext)
                }
                
                avcodec_close(codecContex)
                
                throw DecodeError.reSamplerFailed
            }
        }
        
        audioFrame = av_frame_alloc()
        
        if audioFrame == nil {
//            if var context = swrContext {
                swr_free(&swrContext)
//            }
            
            avcodec_close(codecContex)
            throw DecodeError.allocateFrameFailed
        }
        
        audioStream = stream
        audioCodecContext = codecContex
        
        audioTimeBase = avStreamFPSTimeBase(stream, defaultTimeBase: 0.025).pTimeBase
    
    }
    
    fileprivate func audioCodecIsSupported(_ audioCodeCtx:UnsafeMutablePointer<AVCodecContext>) -> Bool{
        if (audioCodeCtx.pointee.sample_fmt == AV_SAMPLE_FMT_S16) {
            
            print("\(audioCodeCtx.pointee.sample_rate),\(audioCodeCtx.pointee.channels)")
        
            return true
        }
        return false;
    }

    
}

extension PlayerDecoder {
    func frameWidth() -> UInt {
        if let codecCtx = videoCodecContext {
            return UInt(codecCtx.pointee.width)
        }
        
        return 0
    }
    
    func frameHeight() -> UInt {
        if let codecCtx = videoCodecContext {
            return UInt(codecCtx.pointee.height)
        }
        
        return 0
    }
    
    func validVideo() -> Bool {
        return videoStreamIndex != -1
    }
    
    func validAudio() -> Bool {
        return audioStreamIndex != -1
    }
}

private func audioCodecIsSupported(_ audio: UnsafePointer<AVCodecContext>) -> Bool
{
    if (audio.pointee.sample_fmt == AV_SAMPLE_FMT_S16) {

        return true
//        let audioManager = AudioManager()
//        return  (Int32(audioManager.samplingRate) == audio.pointee.sample_rate) &&
//        (Int32(audioManager.numOutputChannels) == audio.pointee.channels)
    }
    return false
}

private func collectStreamIndexs(_ formatContext: UnsafePointer<AVFormatContext>, codecType: AVMediaType) -> Array<Int>{
    
    var streamIndexs = Array<Int>()
    
    for i in 0..<Int(formatContext.pointee.nb_streams) {
        if codecType == formatContext.pointee.streams[i]?.pointee.codec.pointee.codec_type {
            streamIndexs.append(i)
        }
    }
    
    return streamIndexs
}

private func copyFrameData(_ source: UnsafeMutablePointer<UInt8>, lineSize: Int32, width: Int32, height: Int32) -> NSMutableData{
    let width = Int(min(width, lineSize))
    let height = Int(height)
    var src = source
    
    let data: NSMutableData! = NSMutableData(length: width * height)
    let dataPointer = data?.mutableBytes
    
    if  var dst = dataPointer {
        for _ in 0..<height {
            
            memcpy(dst, src, width)
            dst += width
            src = src.advanced(by: Int(lineSize))
        }
    }
    
    return data
}

private func avStreamFPSTimeBase(_ st:UnsafeMutablePointer<AVStream> , defaultTimeBase: Float) -> (pFPS:Float, pTimeBase:Float) {
    
    var fps: Float = 0
    var timebase: Float = 0
    
    if (st.pointee.time_base.den >= 1) && (st.pointee.time_base.num >= 1) {
        timebase = Float(av_q2d(st.pointee.time_base))
    } else if (st.pointee.codec.pointee.time_base.den >= 1) && (st.pointee.codec.pointee.time_base.num >= 1) {
        timebase = Float(av_q2d(st.pointee.codec.pointee.time_base))
    } else {
        timebase = defaultTimeBase;
    }
    
    if (st.pointee.codec.pointee.ticks_per_frame != 1) {
        print("WARNING: st.codec.ticks_per_frame=\(st.pointee.codec.pointee.ticks_per_frame)")
        //timebase *= st->codec->ticks_per_frame;
    }
    
    if (st.pointee.avg_frame_rate.den >= 1) && (st.pointee.avg_frame_rate.num >= 1) {
        fps = Float(av_q2d(st.pointee.avg_frame_rate))
    } else if (st.pointee.r_frame_rate.den >= 1) && (st.pointee.r_frame_rate.num >= 1) {
        fps = Float(av_q2d(st.pointee.r_frame_rate))
    } else {
        fps = 1.0 / timebase
    }
    
    return (fps, timebase)
}


