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
    case vertex = 0
    case texcoord = 1
}

class PlayerGLView: UIView {
    
    fileprivate var eaglLayer = CAEAGLLayer()
    fileprivate var eaglContenxt = EAGLContext(api: EAGLRenderingAPI.openGLES2)
    
    fileprivate var frameBuffer: GLuint = 0
    fileprivate var renderBuffer: GLuint = 0
    
    fileprivate var program: GLuint = 0
    
    fileprivate var backingWidth: GLint = 0
    fileprivate var backingHeight: GLint = 0
    
    fileprivate var vertices:Array<GLfloat> = [-1.0 ,   -1.0,
                                           1.0  ,   -1.0,
                                           -1.0 ,   1.0,
                                           1.0  ,   1.0]
    fileprivate var uniformMatrix: Int32 = 0
    fileprivate var render : MovieGLRender!
    fileprivate var decoder = PlayerDecoder()
    
    var videoFrames = Array<VideoFrame>()
    var audioFrames = Array<AudioFrame>()
    var bufferedDuration: Double = 0
    var minBufferedDuration: Double = 0.2
    
    let videoLockQueue = DispatchQueue(label: "com.zerdzhong.SwiftPlayer.videoLockQueue", attributes: [])
    let audioLockQueue = DispatchQueue(label: "com.zerdzhong.SwiftPlayer.audioLockQueue", attributes: [])
    
    fileprivate var tickCorrectionTime: TimeInterval = 0
    fileprivate var moviePosition: TimeInterval = 0
    fileprivate var tickCorrectionPosition: TimeInterval = 0
    
    override class var layerClass : AnyClass {
        return CAEAGLLayer.self
    }
    
    required init?(coder aDecoder: NSCoder) {
        render = MovieGLYUVRender()
        super.init(coder: aDecoder)
    }
    
    init(frame: CGRect, fileURL: String) {
        
        super.init(frame: frame)
        
        do {
            try decoder.openFile(fileURL as NSString)
			render = MovieGLYUVRender()
            
        } catch {
            print("error")
        }
        
        commonInit()
    }
    
	func playInternal() -> Void{
        
//        decoder.asyncDecodeFrames(0.4, completeBlock: { (frames) in
//            self.addFrames(frames)
//        })
//
//        let popTime = DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
//        DispatchQueue.main.asyncAfter(deadline: popTime) {
//            self.tick(self.decoder)
//        }
    }
    
    fileprivate func tick(_ decoder: PlayerDecoder) {
//        let leftFrame = (decoder.validVideo() ? videoFrames.count : 0) + (decoder.validAudio() ? audioFrames.count : 0)
//        
//        let interval = presentFrame()
//        
//        if 0 == leftFrame {
//            if decoder.isEOF {
//                return
//            }
//        }
//        
//        if (leftFrame == 0 || bufferedDuration < minBufferedDuration) {
//            decoder.asyncDecodeFrames(0.1, completeBlock: { (frames) in
//                self.addFrames(frames)
//            })
//        }
//        
//        let correction = tickCorrection()
//        let time = max(interval + correction, 0.01)
//        
//        let popTime = DispatchTime.now() + Double(Int64(time * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
//        DispatchQueue.main.asyncAfter(deadline: popTime) {
//            self.tick(decoder)
//        }
    }
    
    func tickCorrection() -> TimeInterval {
        let now = Date.timeIntervalSinceReferenceDate
        
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
    
    fileprivate func presentFrame() -> TimeInterval {
        if videoFrames.count <= 0 {
            return 0
        }
        
        let frame = videoFrames[0]
        videoLockQueue.sync {
            self.videoFrames.remove(at: 0)
            self.bufferedDuration -= frame.duration
        }
        
        moviePosition = frame.position
        renderFrame(frame)
        
        return frame.duration
    }
    
    fileprivate func addFrames(_ frames: Array<MovieFrame>?) -> Void {
        
        if frames == nil {
            return
        }
        
        if decoder.validVideo() {
            videoLockQueue.sync {
                for frame in frames! {
                    if frame is VideoFrame && frame.type == .video {
                        self.videoFrames.append(frame as! VideoFrame)
                        self.bufferedDuration += frame.duration
                    }
                }
            }
        }else if decoder.validAudio() {
            audioLockQueue.sync {
                for frame in frames! {
                    if frame is AudioFrame && frame.type == .audio {
                        self.audioFrames.append(frame as! AudioFrame)
                        if !self.decoder.validVideo() {
                            self.bufferedDuration += frame.duration
                        }
                    }
                }
            }
            
            if !decoder.validVideo() {
                
            }
        }
    }
    
    fileprivate func renderFrame(_ frame: VideoFrame?) -> Void {
        let texCoords:[GLfloat] = [0.0, 1.0,
                                   1.0, 1.0,
                                   0.0, 0.0,
                                   1.0, 0.0]
        
        EAGLContext.setCurrent(eaglContenxt)
        
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
            
            glVertexAttribPointer(ATTRBUTEIndex.vertex.rawValue, 2, UInt32(GL_FLOAT), 0, 0, vertices);
            glEnableVertexAttribArray(ATTRBUTEIndex.vertex.rawValue);
            glVertexAttribPointer(ATTRBUTEIndex.texcoord.rawValue, 2, UInt32(GL_FLOAT), 0, 0, texCoords);
            glEnableVertexAttribArray(ATTRBUTEIndex.texcoord.rawValue);
            
            glDrawArrays(UInt32(GL_TRIANGLE_STRIP), 0, 4);
        }
        
        glBindRenderbuffer(UInt32(GL_RENDERBUFFER), renderBuffer);
        eaglContenxt?.presentRenderbuffer(Int(GL_RENDERBUFFER))
    }
    
    override func layoutSubviews() {
        glBindRenderbuffer(UInt32(GL_RENDERBUFFER), renderBuffer)
        eaglContenxt?.renderbufferStorage(Int(GL_RENDERBUFFER), from: eaglLayer)
        
        glGetRenderbufferParameteriv(UInt32(GL_RENDERBUFFER), UInt32(GL_RENDERBUFFER_WIDTH), &backingWidth)
        glGetRenderbufferParameteriv(UInt32(GL_RENDERBUFFER), UInt32(GL_RENDERBUFFER_HEIGHT), &backingHeight)
        
        let status = glCheckFramebufferStatus(UInt32(GL_FRAMEBUFFER))
        if status != UInt32(GL_FRAMEBUFFER_COMPLETE) {
            print("failed to make complete framebuffer object \(status)")
        } else {
            print("OK setup GL framebuffer \(backingWidth), \(backingHeight)")
        }
        
        updateVertices()
//        renderFrame(nil)
    }
    
    fileprivate func commonInit() {
        setupGLLayer()
        setupRenderBuffer()
        setupFrameBuffer()
        
        if glCheckFramebufferStatus(UInt32(GL_FRAMEBUFFER)) != UInt32(GL_FRAMEBUFFER_COMPLETE) {
            print("failed to make complete framebuffer object")
        }
        
        if glGetError() != UInt32(GL_NO_ERROR) {
            print("failed to setup GL")
        }
        
        _ = setupShaders()
    }
    
    fileprivate func setupGLLayer() -> Void {
        eaglLayer = self.layer as! CAEAGLLayer
        eaglLayer.isOpaque = true
        eaglLayer.drawableProperties = [kEAGLDrawablePropertyRetainedBacking:NSNumber(value: false as Bool),
                                        kEAGLDrawablePropertyColorFormat:kEAGLColorFormatRGBA8]
        
        if eaglContenxt == nil || !EAGLContext.setCurrent(eaglContenxt) {
            print("failed to setup EAGLContext")
        }
    }
    
    fileprivate func setupRenderBuffer() -> Void {
        glGenRenderbuffers(1, &renderBuffer)
        glBindRenderbuffer(UInt32(GL_RENDERBUFFER), renderBuffer)
        eaglContenxt?.renderbufferStorage(Int(GL_RENDERBUFFER), from: eaglLayer)
        
        glGetRenderbufferParameteriv(UInt32(GL_RENDERBUFFER), UInt32(GL_RENDERBUFFER_WIDTH), &backingWidth);
        glGetRenderbufferParameteriv(UInt32(GL_RENDERBUFFER), UInt32(GL_RENDERBUFFER_HEIGHT), &backingHeight);
    }
    
    fileprivate func setupFrameBuffer() -> Void {
        glGenFramebuffers(1, &frameBuffer)
        glBindFramebuffer(UInt32(GL_FRAMEBUFFER), frameBuffer)
        glFramebufferRenderbuffer(UInt32(GL_FRAMEBUFFER), UInt32(GL_COLOR_ATTACHMENT0), UInt32(GL_RENDERBUFFER), renderBuffer)
    }
    
    
    fileprivate func setupShaders() -> Bool{
        
        var result = false
        
        if let render = self.render {
            program = glCreateProgram()
            
            let vertShader = loadShader(UInt32(GL_VERTEX_SHADER), shaderPath: Bundle.main.path(forResource: "VertexShader", ofType: "glsl")!)
            let fragShader = render.loadFragmentShader()
        
            if vertShader != 0 && fragShader != 0 {
                glAttachShader(program, vertShader)
                glAttachShader(program, fragShader)
                
                glBindAttribLocation(program, ATTRBUTEIndex.vertex.rawValue, "posotion")
                glBindAttribLocation(program, ATTRBUTEIndex.texcoord.rawValue, "texcoord")
                
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
    
    fileprivate func validateProgram(_ program: GLuint) -> Bool {
        
        glValidateProgram(program);
        
        #if DEBUG
            var logLength:GLint = 0
            glGetProgramiv(program, UInt32(GL_INFO_LOG_LENGTH), &logLength);
            if logLength > 0 {
                let log = malloc(Int(logLength))
                glGetProgramInfoLog(program, logLength, &logLength, unsafeBitCast(log, to: UnsafeMutablePointer<GLchar>.self));
                print("Program validate log:\(String(describing:log))")
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
    
    fileprivate func updateVertices() {
        
        let fit     = (self.contentMode == .scaleAspectFit)
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

private func mat4f_LoadOrtho(_ left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> Array<GLfloat> {
    
    var mout = Array<GLfloat>(repeating: 0, count: 16)
    
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

extension PlayerGLView: PlayerControllable {
	func play() {
		playInternal()
	}
	func pause() {
		
	}
	func stop() {
		
	}
	func seekTo(progress: Float) {
		
	}
	func switchFullScreen() {
		
	}
}
