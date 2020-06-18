//
//  MemoryAddress.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 2020/6/9.
//  Copyright © 2020 zhongzhendong. All rights reserved.
//

import Foundation

struct MemoryAddress<T>: CustomStringConvertible {
	let intValue: Int
	
	var description: String {
		let length = 2 + 2 * MemoryLayout<UnsafeRawPointer>.size
		return String(format: "%0\(length)p", intValue)
	}
	
	init(of structPointer: UnsafePointer<T>) {
		intValue = Int(bitPattern: structPointer)
	}
}

extension MemoryAddress where T: AnyObject {
	init(of classsInstance: T) {
		intValue = unsafeBitCast(classsInstance, to: Int.self)
	}
}
