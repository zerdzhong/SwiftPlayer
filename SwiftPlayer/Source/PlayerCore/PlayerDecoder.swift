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
}

class PlayerDecoder: NSObject {
    
    var fps: Double = 0
    
    private var formatContext: UnsafeMutablePointer<AVFormatContext>?
    private var videoTimeBase: Double = 0
    
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
            try openAudioStream()
            try openVideoStream()
        } catch {
            
        }
    }
    
    func openVideoStream() throws {
        if let context = formatContext {
            let videoStreams = collectStreams(context, codecType: AVMEDIA_TYPE_VIDEO)
            
            let streamArray = unsafeBitCast(context.memory.streams, Array<UnsafeMutablePointer<AVStream>>.self)
            for videoStreamIndex in videoStreams {
                let stream = streamArray[videoStreamIndex]
                if (stream.memory.disposition & AV_DISPOSITION_ATTACHED_PIC) == 0 {
                    do {
                        try openVideoStreamAtIndex(stream)
                        break
                    }catch {
                        continue
                    }
                }
            }
        }
    }
    
    func openVideoStreamAtIndex(stream: UnsafePointer<AVStream>) throws {
        
        let codecContex = stream.memory.codec
        let codec = avcodec_find_decoder(codecContex.memory.codec_id)
        
        if codec == nil {
            throw DecodeError.CodecNotFound
        }
        
        if avcodec_open2(codecContex, codec, nil) < 0 {
            throw DecodeError.OpenCodecFailed
        }
        
        let videoFrame = av_frame_alloc()
        
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
    }
    
    func openAudioStream() throws {
        
    }
    
}

func collectStreams(formatContext: UnsafePointer<AVFormatContext>, codecType: AVMediaType) -> Array<Int>{

    var mutableArray = Array<Int>()
    
    let stramArray = unsafeBitCast(formatContext.memory.streams, Array<UnsafeMutablePointer<AVStream>>.self)
    
    for i in 0..<stramArray.count{
        if codecType == stramArray[i].memory.codec.memory.codec_type {
            mutableArray.append(i)
        }
    }
    
    return mutableArray
}
