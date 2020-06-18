//
//  CastCVPixcelBuffer.h
//  SwiftPlayer
//
//  Created by zhongzhendong on 2020/6/16.
//  Copyright © 2020 zhongzhendong. All rights reserved.
//

#ifndef CastCVPixcelBuffer_h
#define CastCVPixcelBuffer_h

#include <CoreMedia/CoreMedia.h>

#ifdef __cplusplus
extern "C" {
#endif

#include "libavcodec/avcodec.h"

CVPixelBufferRef CastToCVPixelBuffer(void *p);
CVPixelBufferRef WrapAVFrameToCVPixelBuffer(AVCodecContext* codec_context ,const AVFrame* frame);

#ifdef __cplusplus
};
#endif

#endif /* CastCVPixcelBuffer_h */
