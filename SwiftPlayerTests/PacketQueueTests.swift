//
//  PacketQueueTests.swift
//  SwiftPlayerTests
//
//  Created by zhongzhendong on 2020/6/8.
//  Copyright © 2020 zhongzhendong. All rights reserved.
//

import XCTest

class PacketQueueTests: XCTestCase {
	
	fileprivate var queue = PacketQueue(maxSize: 100)

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
		queue.start()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
		queue.abort()
    }

    func testPutAndGet() {
		var packet = AVPacket()
		
		let putPacket = {(packetPointer: UnsafeMutablePointer<AVPacket>)->UnsafeMutablePointer<AVPacket> in packetPointer }(&packet)
		putPacket.pointee.stream_index = 1024
		
		queue.put(packet: putPacket)
		
		let node = queue.syncGet()
		
		XCTAssertNotNil(node)
		XCTAssert(1024 == node?.packet.pointee.stream_index)
		
		queue.flush()
    }
	
	func testConcurrentPutAndGet() {
		let putQueue = DispatchQueue(label: "put", attributes: .concurrent)
		let getQueue = DispatchQueue(label: "get", attributes: .concurrent)
		let group = DispatchGroup()
		
		var packetArray = [UnsafeMutablePointer<AVPacket>]()
		
		
		for index in 1...5 {
			let packet = av_packet_alloc()
			av_new_packet(packet!, 100)
			packet?.pointee.dts = Int64(index)
			packetArray.append(packet!)
			putQueue.async {
				self.queue.put(packet: packet!)
				print("put \(String(describing: packet?.pointee.dts))")
			}
		}
		
		for _ in 1...5 {
			group.enter()
			getQueue.async {
				let node = self.queue.syncGet()
				print("get \(String(describing: node?.packet.pointee.dts))")
				group.leave()
			}
		}
		
		group.wait()
	}
}
