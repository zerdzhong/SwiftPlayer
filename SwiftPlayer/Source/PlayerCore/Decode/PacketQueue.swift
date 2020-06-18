//
//  PacketQueue.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 2020/6/8.
//  Copyright © 2020 zhongzhendong. All rights reserved.
//

import Foundation

class PacketQueue {
	class Node {
		var packet : UnsafeMutablePointer<AVPacket>
		var next : Node?
		
		init(packet: UnsafePointer<AVPacket>) {
			self.packet = av_packet_alloc()
			av_packet_ref(self.packet, packet)
			next = nil
		}
		
		deinit {
			var packet :UnsafeMutablePointer<AVPacket>? = self.packet
			av_packet_free(&packet)
		}
	}
	
	fileprivate var head : Node? = nil
	fileprivate var tail : Node? = nil
	fileprivate var packets_num : Int = 0
	fileprivate var size : Int32 = 0
	fileprivate var maxSize : Int32
	fileprivate var duration : Int64 = 0
	fileprivate var abort_request = true
	fileprivate var abortMutex = DispatchSemaphore(value: 1)
	fileprivate var sema = DispatchSemaphore(value: 0)
	fileprivate var queue = DispatchQueue(label: "com.zdzhong.swiftplay.packetqueue", attributes: .concurrent)
	
	init(maxSize: Int) {
		self.maxSize = Int32(maxSize)
	}
	
	deinit {
		flush()
	}
	
	func start() {
		abortMutex.wait()
		abort_request = false
		abortMutex.signal()
	}
	
	func abort() {
		abortMutex.wait()
		abort_request = true
		abortMutex.signal()
		sema.signal()
	}
	
	func flush() {
		abort()
		
		queue.sync {
			while let node = head {
				head = head?.next
				node.next = nil
			}
		}
	}
	
	func isAbort() -> Bool {
		abortMutex.wait()
		let abort = abort_request
		abortMutex.signal()
		
		return abort
	}
	
	func put(packet: UnsafePointer<AVPacket>) {
		if isAbort() {
			return
		}
		
		internalPut(packet: packet)
	}
	
	func syncPut(packet: UnsafePointer<AVPacket>) {
		while true {
			if isAbort() {
				return
			}
			
			if size < maxSize {
				return internalPut(packet: packet)
			} else {
				_ = sema.wait(timeout: DispatchTime.distantFuture)
			}
		}
	}
	
	func syncGet() -> Node? {
		while true {
			if isAbort() {
				return nil
			}
			
			if let validNode = internalGet() {
				return validNode
			} else {
				print("syncGet empty wait")
				_ = sema.wait(timeout: DispatchTime.distantFuture)
			}
		}
	}
}

extension PacketQueue {
	fileprivate func internalPut(packet: UnsafePointer<AVPacket>) {
		queue.sync(flags: .barrier) {
			let node = Node(packet: packet)
			
			if self.tail == nil {
				self.head = node
			} else {
				self.tail?.next = node
			}
			
			self.tail = node
			self.packets_num += 1
			self.size += (node.packet.pointee.size + Int32(MemoryLayout.size(ofValue: node)))
			self.duration += node.packet.pointee.duration
			
			self.sema.signal()
		}
	}
	
	fileprivate func internalGet() -> Node? {
		var result : Node? = nil
		
		queue.sync(flags: .barrier)  {
			if let node = head {
				head = node.next
				
				if head == nil {
					tail = nil
				}
				
				packets_num -= 1
				size -= (node.packet.pointee.size + Int32(MemoryLayout.size(ofValue: node)))
				duration -= node.packet.pointee.duration

				self.sema.signal()
				
				result = node
			}
		}
		
		return result
	}
}
