//
//  SwiftPlayerTests.swift
//  SwiftPlayerTests
//
//  Created by zhongzhendong on 2017/1/18.
//  Copyright © 2017年 zhongzhendong. All rights reserved.
//

import XCTest
@testable import SwiftPlayer

class PlayerDecoderTests: XCTestCase {
	
	let decoder = PlayerDecoder()
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
	
	func testOpenFile() {
		XCTAssertThrowsError(try decoder.openFile("")) { error in
			XCTAssertEqual(error as! DecodeError, DecodeError.openFileFailed)
		}
		
		if let path = Bundle.main.path(forResource: "snsd", ofType: "mp4") {
			XCTAssertNoThrow(try decoder.openFile(path as NSString))
		}
	}
	
	func testDecodeFile() {
		if let path = Bundle.main.path(forResource: "snsd", ofType: "mp4") {
			XCTAssertNoThrow(try decoder.openFile(path as NSString))
		}
		
		let waitGroup = DispatchGroup()
		print("wait start")
		
		decoder.startDecode()
		waitGroup.enter()
		let _ = waitGroup.wait()
		
		print("wait end")
	}
}
