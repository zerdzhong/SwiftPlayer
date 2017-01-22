//
//  PlayerFileReader.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 5/11/16.
//  Copyright © 2016 zhongzhendong. All rights reserved.
//

import Foundation

typealias ReadFrameCompletion = ( _ packet: inout AVPacket) -> ()

enum FileReaderError: Error {
    case pathInvaild
    case openFileFailed
    case streamInfoNotFound
    case emptyStreams
    case codecNotFound
    case openCodecFailed
}

class PlayerFileReader: NSObject {
    
    var filePath: NSString?
    var videoStreamIndex: Int32 = -1
    var videoCodecContext: UnsafeMutablePointer<AVCodecContext>?
    
    private var pFormatCtx: UnsafeMutablePointer<AVFormatContext>?
    private var cancelRead: Bool = false
    
    deinit {
        if let codecCtx = videoCodecContext, var formatCtx = pFormatCtx {
            avcodec_close(codecCtx)
            videoCodecContext = nil
            avformat_close_input(&formatCtx)
            pFormatCtx = nil
        }
    }
    
    //MARK:- public func
    func openInputFile(filePath: NSString) throws {
        
        self.filePath = filePath
        
        av_register_all()
        
        var formatContext = avformat_alloc_context()
        
        if avformat_open_input(&formatContext, filePath.cString(using: String.Encoding.utf8.rawValue), nil, nil) != 0{
            if formatContext != nil {
                avformat_free_context(formatContext)
            }
            
            throw FileReaderError.openFileFailed
        }
        
        if avformat_find_stream_info(formatContext, nil) < 0{
            avformat_close_input(&formatContext)
            
            throw FileReaderError.streamInfoNotFound
        }
        
        av_dump_format(formatContext, 0, filePath.cString(using: String.Encoding.utf8.rawValue), 0)
        
        do {
            try openVideoStreams(formartCtx: formatContext!)
        } catch let error as FileReaderError{
            throw error
        }
        
        self.pFormatCtx = formatContext
    }
    
    func asyncReadFrame(completion: @escaping ReadFrameCompletion) {
        
        DispatchQueue.global().async {
            self.readFrame(completion: completion)
        }

    }
    
    func readFrame(completion: ReadFrameCompletion) {
        if cancelRead {
            print("Frame read canceled.")
            return
        }
        
        if pFormatCtx == nil || videoCodecContext == nil{
            print("format context or codec context is nil")
            return
        }
        
        var packet = AVPacket()
        
        while av_read_frame(pFormatCtx!, &packet) >= 0 {
            if packet.stream_index == videoStreamIndex{
                completion(&packet)
                av_packet_unref(&packet)
            }
            
            if cancelRead {
                break
            }
        }
        
        avcodec_close(videoCodecContext!)
        videoCodecContext = nil
        avformat_close_input(&pFormatCtx!)
        pFormatCtx = nil
    }
    
    func cancelReadFrame() {
        cancelRead = true
    }
    
    //MARK:- private func
    private func openVideoStreams(formartCtx: UnsafeMutablePointer<AVFormatContext>) throws {
        videoStreamIndex = -1
        let videoStreams = collectStreamIndexs(formatContext: formartCtx, codecType: AVMEDIA_TYPE_VIDEO)
        
        if videoStreams.count == 0 {
            throw FileReaderError.emptyStreams
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
            throw FileReaderError.codecNotFound
        }
        
        if avcodec_open2(codecContex, codec, nil) < 0 {
            throw FileReaderError.openCodecFailed
        }
        
//        let videoFrame = av_frame_alloc()
//        
//        if videoFrame == nil {
//            throw FileReaderError.AllocateFrameFailed
//        }
        
//        var timeBase, fps: CDouble
//        if (stream.memory.time_base.den != 0) && (stream.memory.time_base.num != 0) {
//            timeBase = av_q2d(stream.memory.time_base)
//        }else if (stream.memory.codec.memory.time_base.den != 0) && (stream.memory.codec.memory.time_base.num != 0) {
//            timeBase = av_q2d(stream.memory.codec.memory.time_base)
//        }else {
//            timeBase = 0.4
//        }
//        
//        if stream.memory.codec.memory.ticks_per_frame != 1{
//            print("WARNING: st.codec.ticks_per_frame=\(stream.memory.codec.memory.ticks_per_frame)")
//        }
//        
//        if (stream.memory.avg_frame_rate.den != 0) && (stream.memory.avg_frame_rate.num != 0) {
//            fps = av_q2d(stream.memory.avg_frame_rate)
//        }else if (stream.memory.r_frame_rate.den != 0) && (stream.memory.r_frame_rate.num != 0) {
//            fps = av_q2d(stream.memory.r_frame_rate)
//        }else {
//            fps = 1.0 / timeBase
//        }
        
//        self.videoTimeBase = timeBase
//        self.fps = fps
//        self.videoStream = stream
        self.videoCodecContext = codecContex
    }
    
    private func openAudioStreams() throws {
        if let context = self.pFormatCtx {
            let videoStreams = collectStreamIndexs(context, codecType: AVMEDIA_TYPE_AUDIO)
            
            if videoStreams.count == 0 {
                throw FileReaderError.emptyStreams
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
            throw FileReaderError.codecNotFound
        }
        
        if avcodec_open2(codecContex, codec, nil) < 0 {
            throw FileReaderError.openCodecFailed
        }
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
}
