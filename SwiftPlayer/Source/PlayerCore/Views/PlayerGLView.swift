//
//  PlayerGLView.swift
//  SwiftPlayer
//
//  Created by zhongzhendong on 4/25/16.
//  Copyright © 2016 zhongzhendong. All rights reserved.
//

import UIKit
import OpenGLES

enum ATTRBUTEIndex: UInt32 {
    case VERTEX = 0
    case TEXCOORD = 1
}

class PlayerGLView: UIView {
    
    private var eaglLayer = CAEAGLLayer()
    private var eaglContenxt = EAGLContext(API: EAGLRenderingAPI.OpenGLES2)
    
    private var frameBuffer: GLuint = 0
    private var renderBuffer: GLuint = 0
    
    private var program: GLuint = 0
    
    private var backingWidth: GLint = 0
    private var backingHeight: GLint = 0
    
    private var vertices:Array<GLfloat> = [-1.0 ,   -1.0,
                                           1.0  ,   -1.0,
                                           -1.0 ,   1.0,
                                           1.0  ,   1.0]
    private var uniformMatrix: Int32 = 0
    private var render : MovieGLRender!
    private var decoder = PlayerDecoder()
    
    var videoFrames = Array<VideoFrame>()
    var bufferedDuration: Double = 0
    var minBufferedDuration: Double = 0.2
    
    let lockQueue = dispatch_queue_create("com.zerdzhong.SwiftPlayer.LockQueue", nil)
    
    private var tickCorrectionTime: NSTimeInterval = 0
    private var moviePosition: NSTimeInterval = 0
    private var tickCorrectionPosition: NSTimeInterval = 0
    
    override class func layerClass() -> AnyClass {
        return CAEAGLLayer.self
    }
    
    required init?(coder aDecoder: NSCoder) {
        render = MovieGLYUVRender()
        super.init(coder: aDecoder)
    }
    
    init(frame: CGRect, fileURL: String) {
        
        super.init(frame: frame)
        
        do {
            try decoder.openFile(fileURL)
            
            if decoder.setupVideoFrameFormat(VideoFrameFormat.YUV) {
                render = MovieGLYUVRender()
            }else {
                render = MovieGLRGBRender()
            }
            
            decoder.setupVideoFrameFormat(VideoFrameFormat.YUV)
            
        } catch {
            print("error")
        }
        
        commonInit()
    }
    
    func play() -> Void{
        
        decoder.asyncDecodeFrames(0.4, completeBlock: { (frames) in
            self.addFrames(frames)
        })
        
        let popTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC)))
        dispatch_after(popTime, dispatch_get_main_queue()) {
            self.tick(self.decoder)
        }
    }
    
    private func tick(decoder: PlayerDecoder) {
        let leftFrame = videoFrames.count
        
        let interval = presentFrame()
        
        if 0 == leftFrame {
            if decoder.isEOF {
                return
            }
        }
        
        if (leftFrame == 0 || bufferedDuration < minBufferedDuration) {
            decoder.asyncDecodeFrames(0.1, completeBlock: { (frames) in
                self.addFrames(frames)
            })
        }
        
        let correction = tickCorrection()
        let time = max(interval + correction, 0.01)
        
        let popTime = dispatch_time(DISPATCH_TIME_NOW, Int64(time * Double(NSEC_PER_SEC)))
        dispatch_after(popTime, dispatch_get_main_queue()) {
            self.tick(decoder)
        }
    }
    
    func tickCorrection() -> NSTimeInterval {
        let now = NSDate.timeIntervalSinceReferenceDate()
        
        if tickCorrectionTime == 0 {
            tickCorrectionTime = now
            tickCorrectionPosition = moviePosition
            return 0
        }
        
        let dPosition = moviePosition - tickCorrectionPosition
        let dTime = now - tickCorrectionTime
        var correction = dPosition - dTime;
        
        if correction > 1 || correction < -1 {
            print("tick correction reset \(correction)")
            correction = 0
            tickCorrectionTime = 0
        }
        
        return correction
    }
    
    private func presentFrame() -> NSTimeInterval {
        if videoFrames.count <= 0 {
            return 0
        }
        
        let frame = videoFrames[0]
        dispatch_sync(lockQueue) {
            self.videoFrames.removeAtIndex(0)
            self.bufferedDuration -= frame.duration
        }
        
        moviePosition = frame.position
        renderFrame(frame)
        
        return frame.duration
    }
    
    private func addFrames(frames: Array<VideoFrame>?) -> Void {
        
        if frames == nil {
            return
        }
        
        if decoder.vaildVideo() {
            dispatch_sync(lockQueue) {
                for frame: VideoFrame in frames! {
                    if frame.type == .Video {
                        self.videoFrames.append(frame)
                        self.bufferedDuration += frame.duration
                    }
                }
            }
        }
    }
    
    private func renderFrame(frame: VideoFrame?) -> Void {
        let texCoords:[GLfloat] = [0.0, 1.0,
                                   1.0, 1.0,
                                   0.0, 0.0,
                                   1.0, 0.0]
        
        EAGLContext.setCurrentContext(eaglContenxt)
        
        glBindFramebuffer(UInt32(GL_FRAMEBUFFER), frameBuffer)
        glViewport(0, 0, backingWidth, backingHeight)
        
        glClearColor(0, 0, 0, 1.0)
        glClear(UInt32(GL_COLOR_BUFFER_BIT))
        
        glUseProgram(program)
        
        if let frame = frame as? VideoFrameYUV {
            render.setFrame(frame)
        }
        
        if render.prepareRender() {
            
            let modelviewProj = mat4f_LoadOrtho(-1.0, right: 1.0, bottom: -1.0, top: 1.0, near: -1.0, far: 1.0)
            
            glUniformMatrix4fv(uniformMatrix, 1, GLboolean(GL_FALSE), modelviewProj);
            
            glVertexAttribPointer(ATTRBUTEIndex.VERTEX.rawValue, 2, UInt32(GL_FLOAT), 0, 0, vertices);
            glEnableVertexAttribArray(ATTRBUTEIndex.VERTEX.rawValue);
            glVertexAttribPointer(ATTRBUTEIndex.TEXCOORD.rawValue, 2, UInt32(GL_FLOAT), 0, 0, texCoords);
            glEnableVertexAttribArray(ATTRBUTEIndex.TEXCOORD.rawValue);
            
            glDrawArrays(UInt32(GL_TRIANGLE_STRIP), 0, 4);
        }
        
        glBindRenderbuffer(UInt32(GL_RENDERBUFFER), renderBuffer);
        eaglContenxt.presentRenderbuffer(Int(GL_RENDERBUFFER))
    }
    
    override func layoutSubviews() {
        glBindRenderbuffer(UInt32(GL_RENDERBUFFER), renderBuffer)
        eaglContenxt.renderbufferStorage(Int(GL_RENDERBUFFER), fromDrawable: eaglLayer)
        
        glGetRenderbufferParameteriv(UInt32(GL_RENDERBUFFER), UInt32(GL_RENDERBUFFER_WIDTH), &backingWidth)
        glGetRenderbufferParameteriv(UInt32(GL_RENDERBUFFER), UInt32(GL_RENDERBUFFER_HEIGHT), &backingHeight)
        
        let status = glCheckFramebufferStatus(UInt32(GL_FRAMEBUFFER))
        if status != UInt32(GL_FRAMEBUFFER_COMPLETE) {
            print("failed to make complete framebuffer object \(status)")
        }else {
            print("OK setup GL framebuffer \(backingWidth), \(backingHeight)")
        }
        
        updateVertices()
//        renderFrame(nil)
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
        
        setupShaders()
    }
    
    private func setupGLLayer() -> Void {
        eaglLayer = self.layer as! CAEAGLLayer
        eaglLayer.opaque = true
        eaglLayer.drawableProperties = [kEAGLDrawablePropertyRetainedBacking:NSNumber(bool: false),
                                        kEAGLDrawablePropertyColorFormat:kEAGLColorFormatRGBA8]
        
        if eaglContenxt == nil || !EAGLContext.setCurrentContext(eaglContenxt) {
            print("failed to setup EAGLContext")
        }
    }
    
    private func setupRenderBuffer() -> Void {
        glGenRenderbuffers(1, &renderBuffer)
        glBindRenderbuffer(UInt32(GL_RENDERBUFFER), renderBuffer)
        eaglContenxt.renderbufferStorage(Int(GL_RENDERBUFFER), fromDrawable: eaglLayer)
        
        glGetRenderbufferParameteriv(UInt32(GL_RENDERBUFFER), UInt32(GL_RENDERBUFFER_WIDTH), &backingWidth);
        glGetRenderbufferParameteriv(UInt32(GL_RENDERBUFFER), UInt32(GL_RENDERBUFFER_HEIGHT), &backingHeight);
    }
    
    private func setupFrameBuffer() -> Void {
        glGenFramebuffers(1, &frameBuffer)
        glBindFramebuffer(UInt32(GL_FRAMEBUFFER), frameBuffer)
        glFramebufferRenderbuffer(UInt32(GL_FRAMEBUFFER), UInt32(GL_COLOR_ATTACHMENT0), UInt32(GL_RENDERBUFFER), renderBuffer)
    }
    
    
    private func setupShaders() -> Bool{
        
        var result = false
        
        if let render = self.render {
            program = glCreateProgram()
            
            let vertShader = loadShader(UInt32(GL_VERTEX_SHADER), shaderPath: NSBundle.mainBundle().pathForResource("VertexShader", ofType: "glsl")!)
            let fragShader = render.loadFragmentShader()
        
            if vertShader != 0 && fragShader != 0 {
                glAttachShader(program, vertShader)
                glAttachShader(program, fragShader)
                
                glBindAttribLocation(program, ATTRBUTEIndex.VERTEX.rawValue, "posotion")
                glBindAttribLocation(program, ATTRBUTEIndex.TEXCOORD.rawValue, "texcoord")
                
                glLinkProgram(program)
                
                var status: GLint = 0
                
                glGetProgramiv(program, UInt32(GL_LINK_STATUS), &status)
                
                if status != GL_FALSE {
                    result = validateProgram(program)
                    uniformMatrix = glGetUniformLocation(program, "modelViewProjectionMatrix");
                    render.resolveUniforms(program)
                }
            }
            
            if vertShader != 0 {
                glDeleteShader(vertShader)
            }
            if fragShader != 0 {
                glDeleteShader(fragShader)
            }
            
            if result {
                print("OK setup GL programm")
            } else {
                glDeleteProgram(program);
                program = 0;
            }
        }
        
        return result;
    }
    
    private func validateProgram(program: GLuint) -> Bool {
        
        glValidateProgram(program);
        
        #if DEBUG
            var logLength:GLint = 0
            glGetProgramiv(program, UInt32(GL_INFO_LOG_LENGTH), &logLength);
            if logLength > 0 {
                let log = malloc(Int(logLength))
                glGetProgramInfoLog(program, logLength, &logLength, unsafeBitCast(log, UnsafeMutablePointer<GLchar>.self));
                print("Program validate log:\(log)")
                free(log);
            }
        #endif
        
        var status: GLint = 0
        glGetProgramiv(program, UInt32(GL_VALIDATE_STATUS), &status)
        if (status == GL_FALSE) {
            print("Failed to validate program \(program)")
            return false;
        }
        
        return true
    }
    
    private func updateVertices() {
        
        let fit     = (self.contentMode == .ScaleAspectFit)
        var width:UInt   = 0
        var height:UInt  = 0
        

        width   = decoder.frameWidth()
        height  = decoder.frameHeight()
        
        let dH      = Float(backingHeight) / Float(height)
        let dW      = Float(backingWidth)  / Float(width)
        let dd      = fit ? min(dH, dW) : max(dH, dW);
        let h       = (Float(height) * dd / Float(backingHeight))
        let w       = (Float(width)  * dd / Float(backingWidth ))
        
        vertices[0] = -w;
        vertices[1] = -h;
        vertices[2] =  w;
        vertices[3] = -h;
        vertices[4] = -w;
        vertices[5] =  h;
        vertices[6] =  w;
        vertices[7] =  h;

    }
}

private func mat4f_LoadOrtho(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> Array<GLfloat> {
    
    var mout = Array<GLfloat>(count: 16, repeatedValue: 0)
    
    let r_l = right - left
    let t_b = top - bottom
    let f_n = far - near
    let tx = -(right + left) / (right - left)
    let ty = -(top + bottom) / (top - bottom)
    let tz = -(far + near) / (far - near)
    
    mout[0] = 2.0 / r_l
    mout[1] = 0.0
    mout[2] = 0.0
    mout[3] = 0.0
    
    mout[4] = 0.0
    mout[5] = 2.0 / t_b
    mout[6] = 0.0
    mout[7] = 0.0
    
    mout[8] = 0.0
    mout[9] = 0.0
    mout[10] = -2.0 / f_n
    mout[11] = 0.0
    
    mout[12] = tx;
    mout[13] = ty
    mout[14] = tz
    mout[15] = 1.0
    
    return mout
}
