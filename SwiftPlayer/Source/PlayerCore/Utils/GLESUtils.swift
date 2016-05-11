//
//  GLESUtils.swift
//  OpenGLESTutorial
//
//  Created by zhongzhendong on 4/27/16.
//  Copyright © 2016 zhongzhendong. All rights reserved.
//

import Foundation
import OpenGLES

func loadShader(type: GLenum, shaderString: String) -> GLuint {
    
    if let cShtringPoint = shaderString.cStringUsingEncoding(NSUTF8StringEncoding) {
        
        let shader = glCreateShader(type)
        if shader == 0 || shader == UInt32(GL_INVALID_ENUM) {
            print("Failed to create shader \(type)")
            return 0
        }
        
        var source = UnsafePointer<GLchar>(cShtringPoint)
        glShaderSource(shader, 1, &source, nil)
        glCompileShader(shader)
        
//        #if DEBUG
            var logLength: GLint = 0
            glGetShaderiv(shader, UInt32(GL_INFO_LOG_LENGTH), &logLength)
            if logLength > 0 {
                let log = malloc(Int(logLength))
                glGetShaderInfoLog(shader, logLength, &logLength, unsafeBitCast(log, UnsafeMutablePointer<GLchar>.self))
                print("Shader compile log:\(log)")
                free(log)
            }
//        #endif
        
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

func loadShader(type: GLenum, shaderPath: String) -> GLuint {
    
    do {
        let shaderString = try NSString(contentsOfFile: shaderPath, encoding: NSUTF8StringEncoding)
        return loadShader(type, shaderString: shaderString as String)
    } catch {
        print("rend file error")
    }
    
    return 0
}
