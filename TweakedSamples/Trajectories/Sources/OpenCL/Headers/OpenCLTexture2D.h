//---------------------------------------------------------------------------
//
//	File: OpenCLTexture2D.h
//
//  Abstract: A utility class to manage OpenGL textures updates using
//            an OpenCL image buffer memory.
// 			 
//  Disclaimer: IMPORTANT:  This Apple software is supplied to you by
//  Inc. ("Apple") in consideration of your agreement to the following terms, 
//  and your use, installation, modification or redistribution of this Apple 
//  software constitutes acceptance of these terms.  If you do not agree with 
//  these terms, please do not use, install, modify or redistribute this 
//  Apple software.
//  
//  In consideration of your agreement to abide by the following terms, and
//  subject to these terms, Apple grants you a personal, non-exclusive
//  license, under Apple's copyrights in this original Apple software (the
//  "Apple Software"), to use, reproduce, modify and redistribute the Apple
//  Software, with or without modifications, in source and/or binary forms;
//  provided that if you redistribute the Apple Software in its entirety and
//  without modifications, you must retain this notice and the following
//  text and disclaimers in all such redistributions of the Apple Software. 
//  Neither the name, trademarks, service marks or logos of Apple Inc. may
//  be used to endorse or promote products derived from the Apple Software 
//  without specific prior written permission from Apple.  Except as 
//  expressly stated in this notice, no other rights or licenses, express
//  or implied, are granted by Apple herein, including but not limited to
//  any patent rights that may be infringed by your derivative works or by
//  other works in which the Apple Software may be incorporated.
//  
//  The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
//  MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
//  THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
//  FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
//  OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
//  
//  IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
//  OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
//  MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
//  AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
//  STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
// 
//  Copyright (c) 2009 Apple Inc., All rights reserved.
//
//---------------------------------------------------------------------------

#ifndef _OPENCL_TEXTURE_2D_H_
#define _OPENCL_TEXTURE_2D_H_

#ifdef __cplusplus

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#import "OpenCLProgram.h"
#import "OpenCLBuffer.h"

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

namespace OpenCL
{
	class Texture2DStruct;
	
	class Texture2D
	{
		public:
			Texture2D(const Program &rProgram);
			Texture2D(const Program *pProgram);
			
			Texture2D(const Texture2D &rTexture2D);
			Texture2D(const Texture2D *pTexture2D);
			
			Texture2D &operator=(const Texture2D &rTexture2D);
			
			virtual ~Texture2D();
			
			void SetReadWrite();
		
			void SetUseHostPointer();
			void SetAllocHostPointer();
			void SetCopyHostPointer();
		
			void SetIsBlocking();
			void SetIsNonBlocking();
		
			void SetName(const GLuint nName);
			void SetMipLevel(const GLuint nMipLevel);
			void SetTarget(const GLenum nTarget);
			void SetOrigin(const size_t nOriginX, const size_t nOriginY);
			void SetRegion(const size_t nWidth, const size_t nHeight);
		
			const cl_mem GetImage() const;

			bool Generate();
			
			bool Read(const size_t *pOrigin, const size_t *pRegion, void *pHost, size_t *pRowPitch);
			bool Write(const size_t *pOrigin, const size_t *pRegion, const void * const pHost, size_t *pRowPitch);
		
			bool Copy(const Buffer &rBuffer);
			bool Copy(const Buffer *pBuffer);
		
			bool Copy(const Texture2D &rSrcTexture2D);
			bool Copy(const size_t *pRegion, const Texture2D &rSrcTexture2D);
			bool Copy(const size_t *pOrigin, const size_t *pRegion, const Texture2D &rSrcTexture2D);
		
			void *ImagePointer();
			bool  ImageMap(const size_t *pOrigin, const size_t *pRegion, size_t *pImageRowPitch);
			bool  ImageUnmap();
		
		private:
			Texture2DStruct  *mpSTexture2D;
	}; // Texture2D
} // OpenCL

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#endif

#endif

