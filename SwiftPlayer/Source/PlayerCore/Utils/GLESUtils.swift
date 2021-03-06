//
//  GLESUtils.swift
//  OpenGLESTutorial
//
//  Created by zhongzhendong on 4/27/16.
//  Copyright © 2016 zhongzhendong. All rights reserved.
//

import Foundation
import OpenGLES

func loadShader(_ type: GLenum, shaderString: String) -> GLuint {
    
    if let cShtringPoint = shaderString.cString(using: String.Encoding.utf8) {
        
        let shader = glCreateShader(type)
        if shader == 0 || shader == UInt32(GL_INVALID_ENUM) {
            print("Failed to create shader \(type)")
            return 0
        }
        
        var source: UnsafePointer<GLchar>? = unsafeBitCast(cShtringPoint, to: UnsafePointer<GLchar>.self)
        glShaderSource(shader, 1, &source, nil)
        glCompileShader(shader)
		
		var logLength: GLint = 0
		glGetShaderiv(shader, UInt32(GL_INFO_LOG_LENGTH), &logLength)
		if logLength > 0 {
			let log = UnsafeMutableRawPointer.allocate(byteCount: Int(logLength), alignment: 1)
			glGetShaderInfoLog(shader, logLength, &logLength, log.assumingMemoryBound(to: GLchar.self))
			print("Shader compile log:\(String(cString: log.assumingMemoryBound(to: CChar.self))))")
			log.deallocate()
		}
        
        var status: GLint = 0
        glGetShaderiv(shader, UInt32(GL_COMPILE_STATUS), &status)
        
        if status == GL_FALSE {
            glDeleteShader(shader)
            print("Failed to create shader")
            return 0
        }
        
        return shader
    }
    
    return 0
}

func loadShader(_ type: GLenum, shaderPath: String) -> GLuint {
    
    do {
        let shaderString = try NSString(contentsOfFile: shaderPath, encoding: String.Encoding.utf8.rawValue)
        return loadShader(type, shaderString: shaderString as String)
    } catch {
        print("rend file error")
    }
    
    return 0
}
