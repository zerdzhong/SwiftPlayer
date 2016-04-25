//
//  PlayerGLView.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 4/25/16.
//  Copyright © 2016 zhongzhendong. All rights reserved.
//

import UIKit
import OpenGLES

class PlayerGLView: UIView {
    private var eaglLayer = CAEAGLLayer()
    private var eaglContenxt = EAGLContext(API: EAGLRenderingAPI.OpenGLES2)
    
    private var frameBuffer: GLuint = 0
    private var colorRenderBuffer: GLuint = 0
    
    private var backingWidth: GLint = 0
    private var backingHeight: GLint = 0
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        setupGLLayer()
        setupRenderBuffer()
        setupFrameBuffer()
        
        if glCheckFramebufferStatus(UInt32(GL_FRAMEBUFFER)) != UInt32(GL_FRAMEBUFFER_COMPLETE) {
            print("failed to make complete framebuffer object")
        }
        
        if glGetError() != UInt32(GL_NO_ERROR) {
            print("failed to setup GL")
        }
        
        
    }
    
    private func setupGLLayer() -> Void {
        self.layer.insertSublayer(eaglLayer, atIndex: 0)
        eaglLayer.opaque = true
        eaglLayer.drawableProperties = [kEAGLDrawablePropertyRetainedBacking:NSNumber(bool: false),
                                        kEAGLDrawablePropertyColorFormat:kEAGLColorFormatRGBA8]
        
        if eaglContenxt != nil || EAGLContext.setCurrentContext(eaglContenxt) {
            print("failed to setup EAGLContext")
        }
    }
    
    private func setupFrameBuffer() -> Void {
        glGenRenderbuffers(1, &frameBuffer)
        glBindRenderbuffer(UInt32(GL_FRAMEBUFFER), frameBuffer)
        glFramebufferRenderbuffer(UInt32(GL_FRAMEBUFFER), UInt32(GL_COLOR_ATTACHMENT0), UInt32(GL_RENDERBUFFER), colorRenderBuffer)
    }
    
    private func setupRenderBuffer() -> Void {
        glGenRenderbuffers(1, &colorRenderBuffer)
        glBindRenderbuffer(UInt32(GL_RENDERBUFFER), colorRenderBuffer)
        eaglContenxt.renderbufferStorage(Int(GL_RENDERBUFFER), fromDrawable: eaglLayer)
        
        glGetRenderbufferParameteriv(UInt32(GL_RENDERBUFFER), UInt32(GL_RENDERBUFFER_WIDTH), &backingWidth);
        glGetRenderbufferParameteriv(UInt32(GL_RENDERBUFFER), UInt32(GL_RENDERBUFFER_HEIGHT), &backingHeight);
    }
}
