//
//  PlayerGLRender.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 5/16/16.
//  Copyright © 2016 zhongzhendong. All rights reserved.
//

import Foundation
import OpenGLES

protocol MovieGLRender {
    func isValid() -> Bool
    func loadFragmentShader() -> GLuint
    func prepareRender() -> Bool
    func setFrame(_ frame: VideoFrame) -> Void
    func resolveUniforms(_ program: GLuint) -> Void
}

class MovieGLRGBRender: MovieGLRender {
    
    var texture: GLuint = 0
    var uniformSampler: GLint = 0
    
    func isValid() -> Bool {
        return (texture != 0)
    }
    
    func loadFragmentShader() -> GLuint {
        return loadShader(UInt32(GL_FRAGMENT_SHADER), shaderPath:  Bundle.main.path(forResource: "RGBFragmentShader", ofType: "glsl")!)
    }
    
    func resolveUniforms(_ program: GLuint) -> Void {
        uniformSampler = glGetUniformLocation(program, "s_texture")
    }
    
    func prepareRender() -> Bool {
        if texture == 0 {
            return false
        }
        
        glActiveTexture(UInt32(GL_TEXTURE0));
        glBindTexture(UInt32(GL_TEXTURE_2D), texture);
        glUniform1i(uniformSampler, 0);
        
        return true;
    }
    
    func setFrame(_ frame: VideoFrame) -> Void {
        
    }
}

class MovieGLYUVRender: MovieGLRender {
    
    fileprivate var uniformSamplers = [GLint](repeating: 0, count: 3)
    fileprivate var textures = [GLuint](repeating: 0, count: 3)
    
    func isValid() -> Bool {
        return (textures[0] != 0)
    }
    
    func loadFragmentShader() -> GLuint {
        let shaderPath = Bundle.main.path(forResource: "YUVFragmentShader", ofType: "glsl")!
        return loadShader(UInt32(GL_FRAGMENT_SHADER), shaderPath:  shaderPath)
    }
    
    func resolveUniforms(_ program: GLuint) -> Void {
        uniformSamplers[0] = glGetUniformLocation(program, "s_texture_y");
        uniformSamplers[1] = glGetUniformLocation(program, "s_texture_u");
        uniformSamplers[2] = glGetUniformLocation(program, "s_texture_v");
    }
    
    func prepareRender() -> Bool {
        if textures[0] == 0 {
            return false
        }
        
        for i in 0..<3 {
            glActiveTexture(GLenum(GL_TEXTURE0 + Int32(i)));
            glBindTexture(UInt32(GL_TEXTURE_2D), textures[i]);
            glUniform1i(uniformSamplers[i], GLint(i));
        }
        
        return true
    }
    
    func setFrame(_ frame: VideoFrame) -> Void {
        if let yuvFrame = frame as? VideoFrameYUV {
            
            let frameWidth = yuvFrame.width
            let frameHeight = yuvFrame.height
            
            assert(yuvFrame.luma.count == Int(frameWidth * frameHeight))
            assert(yuvFrame.chromaB.count == Int(frameWidth * frameHeight) / 4)
            assert(yuvFrame.chromaR.count == Int(frameWidth * frameHeight) / 4)
            
            glPixelStorei(GLuint(GL_UNPACK_ALIGNMENT), 1)
            
            if 0 == textures[0] {
                glGenTextures(3, &textures)
            }
            
            let pixels = [(yuvFrame.luma as NSData).bytes, (yuvFrame.chromaB as NSData).bytes, (yuvFrame.chromaR as NSData).bytes]
            let widths = [frameWidth, frameWidth / 2, frameWidth / 2]
            let heights = [frameHeight, frameHeight / 2, frameHeight / 2]
            
            for i in 0..<3 {
                glBindTexture(GLuint(GL_TEXTURE_2D), textures[i])
                glTexImage2D(GLuint(GL_TEXTURE_2D), 0,
                             GLint(GL_LUMINANCE),
                             GLsizei(widths[i]),
                             GLsizei(heights[i]), 0,
                             GLuint(GL_LUMINANCE),
                             GLuint(GL_UNSIGNED_BYTE), pixels[i])
                
                glTexParameteri(GLuint(GL_TEXTURE_2D), GLuint(GL_TEXTURE_MAG_FILTER), GLint(GL_LINEAR))
                glTexParameteri(GLuint(GL_TEXTURE_2D), GLuint(GL_TEXTURE_MIN_FILTER), GLint(GL_LINEAR))
                glTexParameterf(GLuint(GL_TEXTURE_2D), GLuint(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
                glTexParameterf(GLuint(GL_TEXTURE_2D), GLuint(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))
            }
        }
    }
}
