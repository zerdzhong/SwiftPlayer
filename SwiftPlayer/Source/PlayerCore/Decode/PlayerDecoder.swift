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
	case formatContextFailed
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
typealias DecodeCallback = (CVPixelBuffer, Double) -> Void

let AV_NOPTS_VALUE = Double(0xFFFFFFFF80000000)

class PlayerDecoder: NSObject {
	
	fileprivate var pFormatCtx: UnsafeMutablePointer<AVFormatContext>?
	
	fileprivate var videoCodecContext: UnsafeMutablePointer<AVCodecContext>?
	fileprivate var videoStreamIndex: Int32 = -1
	fileprivate var videoStream: UnsafeMutablePointer<AVStream>?
	fileprivate var videoFrame: UnsafeMutablePointer<AVFrame>?
	fileprivate var videoPacketQueue = PacketQueue(maxSize: 5 * 16 * 1024)
	
	fileprivate var audioCodecContext: UnsafeMutablePointer<AVCodecContext>?
	fileprivate var audioStreamIndex: Int32 = -1
	fileprivate var audioStream: UnsafeMutablePointer<AVStream>?
	fileprivate var audioFrame: UnsafeMutablePointer<AVFrame>?
	fileprivate var swrContext: UnsafeMutablePointer<SwrContext>?
	fileprivate var audioQueue = PacketQueue(maxSize: 5 * 256 * 1024)
	
	fileprivate var subtitleIndex: Int32 = -1
	
	fileprivate var frameFormat: VideoFrameFormat?
	
	fileprivate let readerQueue = DispatchQueue(label: "reader", attributes: .concurrent)
	fileprivate let decoderQueue = DispatchQueue(label: "decoder", attributes: .concurrent)
	fileprivate var running = false
	
	public var decodeCallback : DecodeCallback?
	
	public func openFile(_ path: NSString) throws {
		var formatCtx = avformat_alloc_context()
		
		if (formatCtx == nil) {
			throw DecodeError.formatContextFailed
		}
		
		if avformat_open_input(&formatCtx, path.cString(using: String.Encoding.utf8.rawValue), nil, nil) != 0{
			if formatCtx != nil {
				avformat_free_context(formatCtx)
			}
			
			throw DecodeError.openFileFailed
		}
		
		if avformat_find_stream_info(formatCtx, nil) < 0 {
			avformat_close_input(&formatCtx)
			throw DecodeError.streamInfoNotFound
		}
		
		print("decoder open input file success.")
		
		try openVideoStreams(formatCtx!)
		try openAudioStreams(formatCtx!)
		
		subtitleIndex = av_find_best_stream(formatCtx!, AVMEDIA_TYPE_SUBTITLE, -1, -1, nil, 0)
		
		self.pFormatCtx = formatCtx
	}
	
	public func startDecode() {
		readerQueue.async {
			self.running = true
			self.readLoop()
		}
		decoderQueue.async {
			self.decodeLoop()
		}
	}
	
	public func stopDecode() {
		running = false
	}
	
	public func getCurrentFps() -> Double {
		guard let videoStream = videoStream, let videoCodecContext = videoCodecContext else {
			return 0
		}
		
		var fps :Double = 0
		var timebase: Double = 0
		
		if videoStream.pointee.time_base.den > 0 && videoStream.pointee.time_base.num > 0 {
			timebase = av_q2d(videoStream.pointee.time_base)
		} else if videoCodecContext.pointee.time_base.den > 0 && videoCodecContext.pointee.time_base.num > 0 {
			timebase = av_q2d(videoCodecContext.pointee.time_base)
		}
		
		if videoStream.pointee.avg_frame_rate.den > 0 && videoStream.pointee.avg_frame_rate.num > 0 {
			fps = av_q2d(videoStream.pointee.avg_frame_rate)
		} else if videoStream.pointee.r_frame_rate.den > 0 && videoStream.pointee.r_frame_rate.num > 0 {
			fps = av_q2d(videoStream.pointee.r_frame_rate);
		}else {
			fps = 1.0 / timebase;
		}
			
		return fps;
	}
	
	public func wrapToPixelBuffer(frame: UnsafeMutablePointer<AVFrame>) -> Unmanaged<CVPixelBuffer>? {
		guard let videoCodecCtx = videoCodecContext else {
			return nil
		}
		
		let pixelBuffer = WrapAVFrameToCVPixelBuffer(videoCodecCtx, frame)
		
		return pixelBuffer
	}

}

extension PlayerDecoder {
	func readLoop() {
		guard var packet = av_packet_alloc(), let formatContext = pFormatCtx else {
			return
		}
		 
		defer {
			var free_packet : UnsafeMutablePointer<AVPacket>? = packet
			av_packet_free(&free_packet)
		}
		
		while running {
			if av_read_frame(formatContext, packet) < 0 {
				if formatContext.pointee.pb.pointee.error == 0 {
					//no error wait for input
					continue
				} else {
					break
				}
			}
			
			if packet.pointee.stream_index == videoStreamIndex {
				videoPacketQueue.put(packet: packet)
			} else if packet.pointee.stream_index == audioStreamIndex {
				audioQueue.put(packet: packet)
			} else {
				av_packet_unref(packet)
			}
		}
	}
	
	func decodeLoop() {
		guard var frame = av_frame_alloc(),
			let videoCodecContext = videoCodecContext,
			let videoStream = videoStream else {
			return
		}
		
		defer {
			var free_frame : UnsafeMutablePointer<AVFrame>? = frame
			av_frame_free(&free_frame)
		}
		
		while running {
			guard let node =  videoPacketQueue.syncGet() else {
				break
			}
			
			avcodec_send_packet(videoCodecContext, node.packet)
		    let got_frame = avcodec_receive_frame(videoCodecContext, frame)
			
			var pts = Double(node.packet.pointee.pts)
			
			if pts == AV_NOPTS_VALUE {
				pts = 0
			}
			
			pts *= av_q2d(videoStream.pointee.time_base)
			
			if got_frame == 0 {
				print("got decoded frame pts: \(pts)")
				if let decodeCallback = decodeCallback {
					if let buffer = wrapToPixelBuffer(frame: frame) {
						decodeCallback(buffer.takeRetainedValue(), pts)
					}
				}
 			}
		}
	}
}

extension PlayerDecoder {
	//MARK:- VideoStream
	fileprivate func openVideoStreams(_ formartCtx: UnsafeMutablePointer<AVFormatContext>) throws {
		videoStreamIndex = -1
		
		let index = av_find_best_stream(formartCtx, AVMEDIA_TYPE_VIDEO, -1, -1, nil, 0)
		
		if index == -1 {
			throw DecodeError.emptyStreams
		}
		
		try openStream(at: index, of: formartCtx)
	}
	
	
	//MARK:- AudioStream
	fileprivate func openAudioStreams(_ formartCtx: UnsafeMutablePointer<AVFormatContext>) throws {
		audioStreamIndex = -1
		let index = av_find_best_stream(formartCtx, AVMEDIA_TYPE_AUDIO, -1, -1, nil, 0)
		
		if index == -1 {
			throw DecodeError.emptyStreams
		}
		
		try openStream(at: index, of: formartCtx)
	}
	
	fileprivate func openStream(at index: Int32, of formatCtx: UnsafeMutablePointer<AVFormatContext>) throws {
		if (index < 0 || index >= formatCtx.pointee.nb_streams) {
			throw DecodeError.streamInfoNotFound
		}
		
		guard let codecParam = formatCtx.pointee.streams?[Int(index)]?.pointee.codecpar else {
			throw DecodeError.streamInfoNotFound
		}
		
		guard let codec = avcodec_find_decoder(codecParam.pointee.codec_id) else {
			throw DecodeError.codecNotFound
		}
		
		guard let codecContext = avcodec_alloc_context3(codec) else {
			throw DecodeError.codecNotFound
		}
		
		if avcodec_parameters_to_context(codecContext, codecParam) < 0{
			throw DecodeError.codecNotFound
		}
		
		if codecContext.pointee.codec_type == AVMEDIA_TYPE_AUDIO {
			// set audio wanted fram codec
		}
		
		if avcodec_open2(codecContext, codec, nil) < 0 {
			throw DecodeError.openCodecFailed
		}
		
		if codecContext.pointee.codec_type == AVMEDIA_TYPE_AUDIO {
			audioStreamIndex = index
			audioCodecContext = codecContext
			audioStream = formatCtx.pointee.streams?[Int(index)]
			
			//start audio queue
			audioQueue.start()
		} else if codecContext.pointee.codec_type == AVMEDIA_TYPE_VIDEO {
			
			let deviceType = av_hwdevice_find_type_by_name(av_hwdevice_get_type_name(AV_HWDEVICE_TYPE_VIDEOTOOLBOX))
			var hardwareDecoder : UnsafeMutablePointer<AVBufferRef>? = nil
			av_hwdevice_ctx_create(&hardwareDecoder, deviceType, nil, nil, 0)
			
			if let hardwareDecoderCtx = hardwareDecoder {
				codecContext.pointee.hw_device_ctx = av_buffer_ref(hardwareDecoderCtx)
			}
			
			videoStreamIndex = index
			videoCodecContext = codecContext
			videoStream = formatCtx.pointee.streams?[Int(index)]
			
			videoPacketQueue.start()
		}
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


