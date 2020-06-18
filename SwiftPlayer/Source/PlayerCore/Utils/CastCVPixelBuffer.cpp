//
//  CastCVPixcelBuffer.c
//  SwiftPlayer
//
//  Created by zhongzhendong on 2020/6/16.
//  Copyright © 2020 zhongzhendong. All rights reserved.
//

#include "CastCVPixelBuffer.h"
#ifdef __cplusplus
extern "C" {
#endif

#include "libavutil/imgutils.h"

#ifdef __cplusplus
};
#endif

const int kMaxPlanes = 3;

CVPixelBufferRef CastToCVPixelBuffer(void *p) {
	return (CVPixelBufferRef)p;
}

static int get_cv_pixel_format(AVCodecContext* avctx,
                               enum AVPixelFormat fmt,
                               enum AVColorRange range,
                               int* av_pixel_format)
{
    //MPEG range is used when no range is set
    if (fmt == AV_PIX_FMT_NV12) {
        *av_pixel_format = range == AVCOL_RANGE_JPEG ?
                                        kCVPixelFormatType_420YpCbCr8BiPlanarFullRange :
                                        kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
    } else if (fmt == AV_PIX_FMT_YUV420P) {
        *av_pixel_format = range == AVCOL_RANGE_JPEG ?
                                        kCVPixelFormatType_420YpCbCr8PlanarFullRange :
                                        kCVPixelFormatType_420YpCbCr8Planar;
    } else if (fmt == AV_PIX_FMT_P010LE) {
        *av_pixel_format = range == AVCOL_RANGE_JPEG ?
                                        kCVPixelFormatType_420YpCbCr10BiPlanarFullRange :
                                        kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange;
        *av_pixel_format = kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange;
    } else {
        return AVERROR(EINVAL);
    }

    return 0;
}

static int get_cv_pixel_info(
    AVCodecContext *avctx,
    const AVFrame  *frame,
    int            *color,
    int            *plane_count,
    size_t         *widths,
    size_t         *heights,
    size_t         *strides,
    size_t         *contiguous_buf_size)
{
//    VTEncContext *vtctx = avctx->priv_data;
    auto av_format       = frame->format;
    auto av_color_range  = frame->color_range;
    int i;
    
    if (get_cv_pixel_format(avctx,
							(enum AVPixelFormat)av_format,
							(enum AVColorRange) av_color_range,
							color)) {
        return AVERROR(EINVAL);
    }

    switch (av_format) {
    case AV_PIX_FMT_NV12:
        *plane_count = 2;

        widths [0] = avctx->width;
        heights[0] = avctx->height;
        strides[0] = frame ? frame->linesize[0] : avctx->width;

        widths [1] = (avctx->width  + 1) / 2;
        heights[1] = (avctx->height + 1) / 2;
        strides[1] = frame ? frame->linesize[1] : (avctx->width + 1) & -2;
        break;

    case AV_PIX_FMT_YUV420P:
        *plane_count = 3;

        widths [0] = avctx->width;
        heights[0] = avctx->height;
        strides[0] = frame ? frame->linesize[0] : avctx->width;

        widths [1] = (avctx->width  + 1) / 2;
        heights[1] = (avctx->height + 1) / 2;
        strides[1] = frame ? frame->linesize[1] : (avctx->width + 1) / 2;

        widths [2] = (avctx->width  + 1) / 2;
        heights[2] = (avctx->height + 1) / 2;
        strides[2] = frame ? frame->linesize[2] : (avctx->width + 1) / 2;
        break;

    case AV_PIX_FMT_P010LE:
        *plane_count = 2;
        widths[0] = avctx->width;
        heights[0] = avctx->height;
        strides[0] = frame ? frame->linesize[0] : (avctx->width * 2 + 63) & -64;

        widths[1] = (avctx->width + 1) / 2;
        heights[1] = (avctx->height + 1) / 2;
        strides[1] = frame ? frame->linesize[1] : ((avctx->width + 1) / 2 + 63) & -64;
        break;

    default:
        av_log(
               avctx,
               AV_LOG_ERROR,
               "Could not get frame format info for color %d range %d.\n",
               av_format,
               av_color_range);

        return AVERROR(EINVAL);
    }

    *contiguous_buf_size = 0;
    for (i = 0; i < *plane_count; i++) {
        if (i < *plane_count - 1 &&
            frame->data[i] + strides[i] * heights[i] != frame->data[i + 1]) {
            *contiguous_buf_size = 0;
            break;
        }

        *contiguous_buf_size += strides[i] * heights[i];
    }

    return 0;
}

static int copy_avframe_to_pixel_buffer(AVCodecContext   *avctx,
                                        const AVFrame    *frame,
                                        CVPixelBufferRef cv_img,
                                        const size_t     *plane_strides,
                                        const size_t     *plane_rows)
{
    int i, j;
    size_t plane_count;
    int status;
    int rows;
    int src_stride;
    int dst_stride;
    uint8_t *src_addr;
    uint8_t *dst_addr;
    size_t copy_bytes;

    status = CVPixelBufferLockBaseAddress(cv_img, 0);
    if (status) {
        av_log(
            avctx,
            AV_LOG_ERROR,
            "Error: Could not lock base address of CVPixelBuffer: %d.\n",
            status
        );
    }

    if (CVPixelBufferIsPlanar(cv_img)) {
        plane_count = CVPixelBufferGetPlaneCount(cv_img);
        for (i = 0; frame->data[i]; i++) {
            if (i == plane_count) {
                CVPixelBufferUnlockBaseAddress(cv_img, 0);
                av_log(avctx,
                    AV_LOG_ERROR,
                    "Error: different number of planes in AVFrame and CVPixelBuffer.\n"
                );

                return AVERROR_EXTERNAL;
            }

            dst_addr = (uint8_t*)CVPixelBufferGetBaseAddressOfPlane(cv_img, i);
            src_addr = (uint8_t*)frame->data[i];
            dst_stride = CVPixelBufferGetBytesPerRowOfPlane(cv_img, i);
            src_stride = plane_strides[i];
            rows = plane_rows[i];

            if (dst_stride == src_stride) {
                memcpy(dst_addr, src_addr, src_stride * rows);
            } else {
                copy_bytes = dst_stride < src_stride ? dst_stride : src_stride;

                for (j = 0; j < rows; j++) {
                    memcpy(dst_addr + j * dst_stride, src_addr + j * src_stride, copy_bytes);
                }
            }
        }
    } else {
        if (frame->data[1]) {
            CVPixelBufferUnlockBaseAddress(cv_img, 0);
            av_log(avctx,
                AV_LOG_ERROR,
                "Error: different number of planes in AVFrame and non-planar CVPixelBuffer.\n"
            );

            return AVERROR_EXTERNAL;
        }

        dst_addr = (uint8_t*)CVPixelBufferGetBaseAddress(cv_img);
        src_addr = (uint8_t*)frame->data[0];
        dst_stride = CVPixelBufferGetBytesPerRow(cv_img);
        src_stride = plane_strides[0];
        rows = plane_rows[0];

        if (dst_stride == src_stride) {
            memcpy(dst_addr, src_addr, src_stride * rows);
        } else {
            copy_bytes = dst_stride < src_stride ? dst_stride : src_stride;

            for (j = 0; j < rows; j++) {
                memcpy(dst_addr + j * dst_stride, src_addr + j * src_stride, copy_bytes);
            }
        }
    }

    status = CVPixelBufferUnlockBaseAddress(cv_img, 0);
    if (status) {
        av_log(avctx, AV_LOG_ERROR, "Error: Could not unlock CVPixelBuffer base address: %d.\n", status);
        return AVERROR_EXTERNAL;
    }

    return 0;
}

CVPixelBufferRef WrapAVFrameToCVPixelBuffer(AVCodecContext* codec_context ,const AVFrame* frame) {
	
	CVPixelBufferRef result = nullptr;
	
	CFMutableDictionaryRef pix_buf_attachments = CFDictionaryCreateMutable(
																		   kCFAllocatorDefault,
																		   10,
																		   &kCFCopyStringDictionaryKeyCallBacks,
																		   &kCFTypeDictionaryValueCallBacks);
	
	if (!pix_buf_attachments) {
		return nullptr;
	}
	
	if (codec_context->pix_fmt == AV_PIX_FMT_VIDEOTOOLBOX) {
		assert(frame->format == AV_PIX_FMT_VIDEOTOOLBOX);
		result = (CVPixelBufferRef)frame->data[3];
		
		return result;
	}
	
	size_t widths [AV_NUM_DATA_POINTERS];
	size_t heights[AV_NUM_DATA_POINTERS];
	size_t strides[AV_NUM_DATA_POINTERS];
	
	memset(widths, 0, sizeof(widths));
	memset(widths, 0, sizeof(heights));
	memset(widths, 0, sizeof(strides));
	
	int color;
	int plane_count;
	size_t contiguous_buf_size;
	
	auto status = get_cv_pixel_info(codec_context,
									frame,
									&color,
									&plane_count,
									widths,
									heights,
									strides,
									&contiguous_buf_size);

	if (status) {
		printf("get_cv_pixel_info error!");
		return nullptr;
	}
	
	
	CVPixelBufferCreate(kCFAllocatorDefault,
						frame->width,
						frame->height,
						color,
						nullptr,
						&result);
	
	status = copy_avframe_to_pixel_buffer(codec_context, frame, result, strides, heights);
	
	return result;
}
