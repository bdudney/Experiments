//---------------------------------------------------------------------------
//
//	File: OpenCLTexture2D.mm
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

//---------------------------------------------------------------------------

#import <iostream>

//---------------------------------------------------------------------------

#import <OpenCL/opencl.h>

//---------------------------------------------------------------------------

#import "OpenCLTexture2D.h"

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Data Structures

//---------------------------------------------------------------------------

class OpenCL::Texture2DStruct
{
public:
	GLint             mnMipLevel;
	GLuint            mnName;
	GLenum            mnTarget;
	cl_context        mpContext;
	cl_device_id      mnDeviceId;
	cl_command_queue  mpCommandQueue;
	cl_mem_flags      mnImageFlags;
	cl_mem            mpImageBuffer;
	cl_mem            mpMemBuffer;
	cl_int            mnError;
	size_t            maImageOrigin[3];
	size_t            maImageRegion[3];
	bool              mbIsBlocking;
	bool              mbIsAcquired;
	bool              mbIsSetHPtrInUse;
	bool              mbIsSetHPtrCopy;
	void             *mpMappedBuffer;
};

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
//
// For a complete discussion of OpenCL image buffer APIs refer to,
//
// http://www.khronos.org/registry/cl/specs/opencl-1.0.33.pdf
//
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Utilities - Wrappers

//---------------------------------------------------------------------------

static bool OpenCLTexture2DImageSupport(OpenCL::Texture2DStruct *pSTexture2D)
{
    cl_bool bImageSupport = CL_FALSE;
	
    pSTexture2D->mnError = clGetDeviceInfo(pSTexture2D->mnDeviceId, 
										   CL_DEVICE_IMAGE_SUPPORT,
										   sizeof(cl_bool), 
										   &bImageSupport, 
										   NULL);
	
    if( pSTexture2D->mnError != CL_SUCCESS ) 
	{
		std::cerr << ">> ERROR: OpenCL Texture 2D - Unable to query device for image support" << std::endl;
    } // if
	
	return( ( bImageSupport == CL_TRUE ) &&  ( pSTexture2D->mnError == CL_SUCCESS ) ); 
} // OpenCLTexture2DImageSupport

//---------------------------------------------------------------------------

static bool OpenCLTexture2DCreateBuffer(OpenCL::Texture2DStruct *pSTexture2D)
{
    pSTexture2D->mpImageBuffer = clCreateFromGLTexture2D(pSTexture2D->mpContext, 
														 pSTexture2D->mnImageFlags, 
														 pSTexture2D->mnTarget, 
														 pSTexture2D->mnMipLevel, 
														 pSTexture2D->mnName, 
														 &pSTexture2D->mnError);
	
	pSTexture2D->mbIsAcquired = ( pSTexture2D->mpImageBuffer != NULL ) && ( pSTexture2D->mnError == CL_SUCCESS );
	
    if( !pSTexture2D->mbIsAcquired )
    {
        std::cerr << ">> ERROR: OpenCL Texture 2D - Failed to create an image buffer!" << std::endl;
    } // if
	
	return( pSTexture2D->mbIsAcquired ); 
} // OpenCLTexture2DCreateBuffer

//---------------------------------------------------------------------------

static bool OpenCLTexture2DEnqueueCopy(const size_t *pSrcImageOrigin,
									   const size_t *pSrcImageRegion,
									   OpenCL::Texture2DStruct *pSTexture2DSrc,
									   OpenCL::Texture2DStruct *pSTexture2DDst)
{
	pSTexture2DDst->mnError = clEnqueueCopyImage(pSTexture2DDst->mpCommandQueue, 
												 pSTexture2DSrc->mpImageBuffer,
												 pSTexture2DDst->mpImageBuffer, 
												 pSrcImageOrigin,
												 pSTexture2DDst->maImageOrigin,
												 pSrcImageRegion,
												 0, 
												 NULL,
												 NULL);
	
	bool bCopiedSource = pSTexture2DDst->mnError == CL_SUCCESS;
	
	if( !bCopiedSource )
	{
		std::cerr << ">> ERROR: OpenCL Texture 2D - Failed to make a copy of the source image!" << std::endl;
	} // if
	
	return( bCopiedSource ); 
} // OpenCLTexture2DEnqueueCopy

//---------------------------------------------------------------------------

static bool OpenCLTexture2DEnqueueAcquireGLObjects(OpenCL::Texture2DStruct *pSTexture2D)
{
	pSTexture2D->mnError = clEnqueueAcquireGLObjects(pSTexture2D->mpCommandQueue, 
													 1,
													 &pSTexture2D->mpImageBuffer, 
													 0,
													 NULL,
													 NULL);
	
	bool bObjectAcquired = pSTexture2D->mnError == CL_SUCCESS;
	
	if( !bObjectAcquired )
	{
		std::cerr << ">> ERROR: OpenCL Texture 2D - Failed to acquire an OpenGL object!" << std::endl;
	} // if
	
	return( bObjectAcquired ); 
} // OpenCLTexture2DEnqueueAcquireGLObjects

//---------------------------------------------------------------------------

static bool OpenCLTexture2DEnqueueReleaseGLObjects(OpenCL::Texture2DStruct *pSTexture2D)
{
	pSTexture2D->mnError = clEnqueueReleaseGLObjects(pSTexture2D->mpCommandQueue, 
													 1,
													 &pSTexture2D->mpImageBuffer, 
													 0,
													 NULL,
													 NULL);
	
	bool bObjectReleased = pSTexture2D->mnError == CL_SUCCESS;
	
	if( !bObjectReleased )
	{
		std::cerr << ">> ERROR: OpenCL Texture 2D - Failed to release an OpenGL object!" << std::endl;
	} // if
	
	return( bObjectReleased ); 
} // OpenCLTexture2DEnqueueReleaseGLObjects

//---------------------------------------------------------------------------

static bool OpenCLTexture2DGetImageRowPitch(size_t *pRowPitch,
											OpenCL::Texture2DStruct *pSTexture2D)
{
	bool bGotRowPitch = false;
	
	if( ( pSTexture2D->mbIsAcquired ) && ( pRowPitch != NULL ) )
	{
		cl_int nRowPitch = 0;
		
		pSTexture2D->mnError = clGetMemObjectInfo(pSTexture2D->mpMemBuffer, 
												  CL_IMAGE_ROW_PITCH, 
												  sizeof(size_t), 
												  &nRowPitch,
												  NULL);
		
		bGotRowPitch = pSTexture2D->mnError == CL_SUCCESS;
		
		if( !bGotRowPitch )
		{
			std::cerr << ">> ERROR: OpenCL Texture 2D - Failed to get an image row pitch!" << std::endl;
		} // if
		else 
		{
			*pRowPitch = nRowPitch;
		} // else
	} // if
	
	return( bGotRowPitch );
} // OpenCLTexture2DGetImageRowPitch

//---------------------------------------------------------------------------

static bool OpenCLTexture2DEnqueueReadImage(const size_t *pOrigin,
											const size_t *pRegion,
											void *pHost,
											size_t *pRowPitch,
											OpenCL::Texture2DStruct *pSTexture2D)
{
	bool bReadSource = false;
	
	if( pSTexture2D->mbIsAcquired )
	{
		size_t nRowPitch = ( pRowPitch != NULL ) ? *pRowPitch : 0;
		
		pSTexture2D->mnError = clEnqueueReadImage(pSTexture2D->mpCommandQueue, 
												  pSTexture2D->mpImageBuffer, 
												  pSTexture2D->mbIsBlocking,
												  pOrigin,
												  pRegion,
												  nRowPitch,
												  0, 
												  pHost, 
												  0, 
												  NULL, 
												  NULL);
		
		bReadSource = pSTexture2D->mnError == CL_SUCCESS;
		
		if( !bReadSource )
		{
			std::cerr << ">> ERROR: OpenCL Texture 2D - Failed to Read from an image buffer!" << std::endl;
		} // if
		else 
		{
			OpenCLTexture2DGetImageRowPitch(pRowPitch, pSTexture2D);
		} // else
	} // if
	
	return( bReadSource ); 
} // OpenCLTexture2DEnqueueReadImage

//---------------------------------------------------------------------------

static bool OpenCLTexture2DEnqueueWriteImage(const size_t *pOrigin,
											 const size_t *pRegion,
											 const void * const pHost, 
											 size_t *pRowPitch,
											 OpenCL::Texture2DStruct *pSTexture2D)
{
	bool bWroteSource = false;
	
	if( pSTexture2D->mbIsAcquired )
	{
		size_t nRowPitch = ( pRowPitch != NULL ) ? *pRowPitch : 0;
		
		pSTexture2D->mnError = clEnqueueWriteImage(pSTexture2D->mpCommandQueue, 
												   pSTexture2D->mpMemBuffer, 
												   pSTexture2D->mbIsBlocking, 
												   pOrigin,
												   pRegion,
												   nRowPitch,
												   0, 
												   pHost, 
												   0, 
												   NULL, 
												   NULL);
		
		bWroteSource = pSTexture2D->mnError == CL_SUCCESS;
		
		if( !bWroteSource )
		{
			std::cerr << ">> ERROR: OpenCL Texture 2D - Failed to write to an image buffer!" << std::endl;
		} // if
		else 
		{
			OpenCLTexture2DGetImageRowPitch(pRowPitch, pSTexture2D);
		} // else
	} // if
	
	return( bWroteSource ); 
} // OpenCLTexture2DEnqueueWriteImage

//---------------------------------------------------------------------------

static bool OpenCLTexture2DEnqueueCopyBufferToImage(OpenCL::Texture2DStruct *pSTexture2D)
{
	pSTexture2D->mnError = clEnqueueCopyBufferToImage(pSTexture2D->mpCommandQueue, 
													  pSTexture2D->mpMemBuffer,
													  pSTexture2D->mpImageBuffer, 
													  0,
													  pSTexture2D->maImageOrigin,
													  pSTexture2D->maImageRegion,
													  0,
													  NULL,
													  NULL);
	
	bool bBufferCopied = pSTexture2D->mnError == CL_SUCCESS;
	
	if( !bBufferCopied )
	{
		std::cerr << ">> ERROR: OpenCL Texture 2D - Failed to copy a buffer to an image!" << std::endl;
	} // if
	
	return( bBufferCopied ); 
} // OpenCLTexture2DEnqueueCopyBufferToImage

//---------------------------------------------------------------------------

static bool OpenCLTexture2DEnqueueMapImage(const size_t *pOrigin, 
										   const size_t *pRegion, 
										   size_t *pImageRowPitch, 
										   OpenCL::Texture2DStruct *pSTexture2D)
{
	bool bMappedBuffer = false;
	
	if( pSTexture2D->mbIsAcquired )
	{
		size_t nImageSlicePitch = 0;
		
		pSTexture2D->mpMappedBuffer = clEnqueueMapImage(pSTexture2D->mpCommandQueue,
														pSTexture2D->mpMemBuffer,
														pSTexture2D->mbIsBlocking, 
														pSTexture2D->mnImageFlags,
														pOrigin,
														pRegion,
														pImageRowPitch,	
														&nImageSlicePitch,
														0,
														NULL,
														NULL,
														&pSTexture2D->mnError);
		
		bMappedBuffer = ( pSTexture2D->mnError == CL_SUCCESS ) && ( pSTexture2D->mpMappedBuffer != NULL );
		
		if( !bMappedBuffer )
		{
			std::cerr << ">> ERROR: OpenCL Texture 2D - Failed to map an image buffer!" << std::endl;
		} // if
	} // if
	
	return( bMappedBuffer ); 
} // OpenCLTexture2DEnqueueMapImage

//---------------------------------------------------------------------------

static bool OpenCLTexture2DEnqueueUnmapImage(OpenCL::Texture2DStruct *pSTexture2D)
{
	bool bUnmappedBuffer = false;
	
	if( pSTexture2D->mbIsAcquired )
	{
		pSTexture2D->mnError = clEnqueueUnmapMemObject(pSTexture2D->mpCommandQueue,
													   pSTexture2D->mpMemBuffer,
													   pSTexture2D->mpMappedBuffer, 
													   0,
													   NULL,
													   NULL);
		
		bUnmappedBuffer = pSTexture2D->mnError == CL_SUCCESS;
		
		if( !bUnmappedBuffer )
		{
			std::cerr << ">> ERROR: OpenCL Texture 2D - Failed to unmap an image buffer!" << std::endl;
		} // if
	} // if
	
	return( bUnmappedBuffer ); 
} // OpenCLTexture2DEnqueueUnmapImage

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Utilities - Generate

//---------------------------------------------------------------------------

static bool OpenCLTexture2DGenerate(OpenCL::Texture2DStruct *pSTexture2D)
{
	bool bImageGenerated = false;
	
	if( OpenCLTexture2DImageSupport(pSTexture2D) )
	{
		bImageGenerated = OpenCLTexture2DCreateBuffer(pSTexture2D);
	} // if
	
	return( bImageGenerated ); 
} // OpenCLTexture2DGenerate

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Utilities - Buffer Copy

//---------------------------------------------------------------------------

static bool OpenCLTexture2DCopyFromBufferAlias(const OpenCL::Buffer &rBuffer,
											   OpenCL::Texture2DStruct *pSTexture2D)
{
	bool bBufferCopied = false;
	
	pSTexture2D->mpMemBuffer = rBuffer.GetBuffer();
	
	if( pSTexture2D->mpMemBuffer != NULL )
	{
		if( OpenCLTexture2DEnqueueAcquireGLObjects(pSTexture2D) )
		{
			bBufferCopied = OpenCLTexture2DEnqueueCopyBufferToImage(pSTexture2D);
			
			OpenCLTexture2DEnqueueReleaseGLObjects(pSTexture2D);
		} // if
	} // if
	
	return( bBufferCopied );
} // OpenCLTexture2DCopyFromBufferAlias

//---------------------------------------------------------------------------

static bool OpenCLTexture2DCopyFromBufferRef(const OpenCL::Buffer *pBuffer,
											 OpenCL::Texture2DStruct *pSTexture2D)
{
	bool bBufferCopied = false;
	
	if( pBuffer != NULL )
	{
		bBufferCopied = OpenCLTexture2DCopyFromBufferAlias(*pBuffer, pSTexture2D);
	} // if
	
	return( bBufferCopied );
} // OpenCLTexture2DCopyFromBufferRef

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Utilities - Image Copy

//---------------------------------------------------------------------------

static bool OpenCLTexture2DPointCmpLT(const size_t *pPointA, 
									  const size_t *pPointB)
{
	size_t aPointA[2] = { 0, 0 };
	size_t aPointB[2] = { 0, 0 };
	
	if( pPointA != NULL )
	{
		aPointA[0] = pPointA[0];
		aPointA[1] = pPointA[1];
	} // if
	
	if( pPointB != NULL )
	{
		aPointB[0] = pPointB[0];
		aPointB[1] = pPointB[1];
	} // if
	
	return( ( aPointA[0] < aPointB[0] ) && ( aPointA[1] < aPointB[1] ) );
} // OpenCLTexture2DPointCmpLT

//---------------------------------------------------------------------------
//
// Copy the source origin into a destination origin.
//
//---------------------------------------------------------------------------

static void OpenCLTexture2DDoCopyOrigin(const OpenCL::Texture2DStruct *pSTexture2DDst,
										const size_t *pSrcImageOrigin,
										size_t *pDstImageOrigin)
{
	if( OpenCLTexture2DPointCmpLT(pSrcImageOrigin, pSTexture2DDst->maImageOrigin) )
	{
		pDstImageOrigin[0] = pSTexture2DDst->maImageOrigin[0];
		pDstImageOrigin[1] = pSTexture2DDst->maImageOrigin[1];
	} // if
	else
	{
		pDstImageOrigin[0] = pSrcImageOrigin[0];
		pDstImageOrigin[1] = pSrcImageOrigin[1];
	} // else
} // OpenCLTexture2DDoCopyOrigin

//---------------------------------------------------------------------------
//
// Check & validate the requested image origin.
//
//---------------------------------------------------------------------------

static void OpenCLTexture2DCopyOrigin(const OpenCL::Texture2DStruct *pSTexture2DSrc, 
									  const OpenCL::Texture2DStruct *pSTexture2DDst,
									  const size_t *pSrcImageOrigin,
									  size_t *pDstImageOrigin)
{
	if( pSrcImageOrigin != NULL )
	{
		OpenCLTexture2DDoCopyOrigin(pSTexture2DDst, 
									pSrcImageOrigin, 
									pDstImageOrigin);
	} // if
	else
	{
		OpenCLTexture2DDoCopyOrigin(pSTexture2DDst, 
									pSTexture2DSrc->maImageOrigin, 
									pDstImageOrigin);
	} // else
	
	pDstImageOrigin[2] = 0;
} // OpenCLTexture2DCopyOrigin

//---------------------------------------------------------------------------
//
// Copy the source region into a destination region.
//
//---------------------------------------------------------------------------

static void OpenCLTexture2DDoCopyRegion(const OpenCL::Texture2DStruct *pSTexture2DDst,
										const size_t *pSrcImageRegion,
										size_t *pDstImageRegion)
{
	if( OpenCLTexture2DPointCmpLT(pSrcImageRegion, pSTexture2DDst->maImageRegion) )
	{
		pDstImageRegion[0] = pSrcImageRegion[0];
		pDstImageRegion[1] = pSrcImageRegion[1];
	} // if
	else
	{
		pDstImageRegion[0] = pSTexture2DDst->maImageRegion[0];
		pDstImageRegion[1] = pSTexture2DDst->maImageRegion[1];
	} // else
} // OpenCLTexture2DDoCopyRegion

//---------------------------------------------------------------------------
//
// Check & validate the requested image region before copying.
//
//---------------------------------------------------------------------------

static void OpenCLTexture2DCopyRegion(const OpenCL::Texture2DStruct *pSTexture2DSrc, 
									  const OpenCL::Texture2DStruct *pSTexture2DDst,
									  const size_t *pSrcImageRegion,
									  size_t *pDstImageRegion)
{
	if( pSrcImageRegion != NULL )
	{
		OpenCLTexture2DDoCopyRegion(pSTexture2DDst, 
									pSrcImageRegion, 
									pDstImageRegion);
	} // if
	else 
	{
		OpenCLTexture2DDoCopyRegion(pSTexture2DDst, 
									pSTexture2DSrc->maImageRegion, 
									pDstImageRegion);
	} // else
	
	pDstImageRegion[2] = 1;
} // OpenCLTexture2DCopyRegion

//---------------------------------------------------------------------------
//
// Copy from the OpenCL image associated with the source texture into the 
// OpenCL image instance variable of the texture 2D structure.  If the image 
// copy dimension that are passed in, are 0, then make a full copy from source 
// to destination.
//
//---------------------------------------------------------------------------

static bool OpenCLTexture2DClone(const size_t *pSrcImageOrigin,
								 const size_t *pSrcImageRegion,
								 OpenCL::Texture2DStruct *pSTexture2DSrc, 
								 OpenCL::Texture2DStruct *pSTexture2DDst)
{
	bool bImageCopied = false;
	
	if( pSTexture2DDst->mbIsAcquired )
	{
		// Check & validate the requested image origin
		
		size_t aDstImageOrigin[3];
		
		OpenCLTexture2DCopyOrigin(pSTexture2DSrc, 
								  pSTexture2DDst,
								  pSrcImageOrigin,
								  aDstImageOrigin);
		
		// Check & validate the requested image region
		
		size_t aDstImageRegion[3];
		
		OpenCLTexture2DCopyRegion(pSTexture2DSrc, 
								  pSTexture2DDst,
								  pSrcImageRegion,
								  aDstImageRegion);
		
		// Copy from source image to destination image using 
		// the validated origin and region
		
		bImageCopied = OpenCLTexture2DEnqueueCopy(aDstImageOrigin,
												  aDstImageRegion,
												  pSTexture2DSrc,
												  pSTexture2DDst);
	} // if
	
	return( bImageCopied );
} // OpenCLTexture2DClone

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Destructor

//---------------------------------------------------------------------------

static void OpenCLTexture2DReleaseBuffer(OpenCL::Texture2DStruct *pSTexture2D)
{
	if( pSTexture2D->mbIsAcquired )
	{
		cl_int nBufferRefCount = 0;
		
		cl_int nError = clGetMemObjectInfo(pSTexture2D->mpImageBuffer, 
										   CL_MEM_REFERENCE_COUNT, 
										   sizeof(cl_int), 
										   &nBufferRefCount,
										   NULL);
		
		if( ( nBufferRefCount ) && ( nError == CL_SUCCESS ) )
		{
			clReleaseMemObject(pSTexture2D->mpImageBuffer);
		} // if
		else
		{
			std::cerr << ">> ERROR: OpenCL Texture 2D - Failed to validate a reference count!" << std::endl;
		} // if
	} // if
} // OpenCLTexture2DReleaseBuffer

//---------------------------------------------------------------------------

static void OpenCLTexture2DRelease(OpenCL::Texture2DStruct *pSTexture2D)
{
	if( pSTexture2D != NULL )
	{
		OpenCLTexture2DReleaseBuffer( pSTexture2D );
		
		delete pSTexture2D;
		
		pSTexture2D = NULL;
	} // if
} // OpenCLTexture2DRelease

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Constructor

//---------------------------------------------------------------------------
//
// Construct a texture 2D object from a program object alias.
//
//---------------------------------------------------------------------------

static OpenCL::Texture2DStruct *OpenCLTexture2DCreateWithProgramAlias( const OpenCL::Program &rProgram )
{
	OpenCL::Texture2DStruct *pSTexture2D = new OpenCL::Texture2DStruct;
	
	if( pSTexture2D != NULL )
	{
		pSTexture2D->mpContext        = rProgram.GetContext();
		pSTexture2D->mpCommandQueue   = rProgram.GetCommandQueue();
		pSTexture2D->mnDeviceId       = rProgram.GetDeviceId();
		pSTexture2D->mnImageFlags     = CL_MEM_WRITE_ONLY;
		pSTexture2D->mnError          = CL_SUCCESS;
		pSTexture2D->mbIsBlocking     = true;
		pSTexture2D->mbIsSetHPtrInUse = false;
		pSTexture2D->mbIsSetHPtrCopy  = false;
		pSTexture2D->mbIsAcquired     = false;
		pSTexture2D->mpImageBuffer    = NULL;
		pSTexture2D->mpMemBuffer      = NULL;
		pSTexture2D->mpMappedBuffer   = NULL;
		pSTexture2D->mnTarget         = GL_TEXTURE_RECTANGLE_ARB;
		pSTexture2D->mnName           = 1;
		pSTexture2D->mnMipLevel       = 0;
		pSTexture2D->maImageOrigin[0] = 0;
		pSTexture2D->maImageOrigin[1] = 0;
		pSTexture2D->maImageOrigin[2] = 0;
		pSTexture2D->maImageRegion[0] = 512;
		pSTexture2D->maImageRegion[1] = 512;
		pSTexture2D->maImageRegion[2] = 1;
	} // if
	
	return( pSTexture2D );
} // OpenCLTexture2DCreateWithProgramAlias

//---------------------------------------------------------------------------
//
// Construct a texture 2D object from a program object reference.
//
//---------------------------------------------------------------------------

static OpenCL::Texture2DStruct *OpenCLTexture2DCreateWithProgramRef( const OpenCL::Program *pProgram )
{
	OpenCL::Texture2DStruct *pSTexture2D = NULL;
	
	if( pProgram != NULL )
	{
		pSTexture2D = OpenCLTexture2DCreateWithProgramAlias(*pProgram);
	} // if
	
	return( pSTexture2D );
} // OpenCLTexture2DCreateWithProgramRef

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Copy Constructor

//---------------------------------------------------------------------------
//
// Clone all texture 2D attributes.
//
//---------------------------------------------------------------------------

static OpenCL::Texture2DStruct *OpenCLTexture2DCopy(OpenCL::Texture2DStruct *pSTexture2DSrc,
													const size_t nBufferCopySize)
{
	OpenCL::Texture2DStruct *pSTexture2DDst = NULL;
	
	if( pSTexture2DSrc != NULL )
	{
		pSTexture2DDst = new OpenCL::Texture2DStruct;
		
		if( pSTexture2DDst != NULL )
		{
			pSTexture2DDst->mbIsSetHPtrInUse = pSTexture2DSrc->mbIsSetHPtrInUse;
			pSTexture2DDst->mbIsSetHPtrCopy  = pSTexture2DSrc->mbIsSetHPtrCopy;
			pSTexture2DDst->mbIsBlocking     = pSTexture2DSrc->mbIsBlocking;
			pSTexture2DDst->maImageOrigin[0] = pSTexture2DSrc->maImageOrigin[0];
			pSTexture2DDst->maImageOrigin[1] = pSTexture2DSrc->maImageOrigin[1];
			pSTexture2DDst->maImageOrigin[2] = 0;
			pSTexture2DDst->maImageRegion[0] = pSTexture2DSrc->maImageRegion[0];
			pSTexture2DDst->maImageRegion[1] = pSTexture2DSrc->maImageRegion[1];
			pSTexture2DDst->maImageRegion[2] = 1;
			pSTexture2DDst->mnDeviceId       = pSTexture2DSrc->mnDeviceId;
			pSTexture2DDst->mpContext        = pSTexture2DSrc->mpContext;
			pSTexture2DDst->mpCommandQueue   = pSTexture2DSrc->mpCommandQueue;
			pSTexture2DDst->mnImageFlags     = pSTexture2DSrc->mnImageFlags;
			pSTexture2DDst->mnError          = pSTexture2DSrc->mnError;
			pSTexture2DDst->mpMemBuffer      = pSTexture2DSrc->mpMemBuffer;
			pSTexture2DDst->mpImageBuffer    = NULL;
			pSTexture2DDst->mbIsAcquired     = false;
			
			if( OpenCLTexture2DCreateBuffer(pSTexture2DDst) )
			{
				bool bImageCopied = OpenCLTexture2DEnqueueCopy(pSTexture2DSrc->maImageOrigin,
															   pSTexture2DSrc->maImageRegion,
															   pSTexture2DSrc,
															   pSTexture2DDst);
				
				if( !bImageCopied )
				{
					std::cerr << ">> ERROR: OpenCL Texture 2D - Failed to clone the source buffer!" << std::endl;
				} // if
			} // if
		} // if
	} // if	
	
	return( pSTexture2DDst );
} // OpenCLTexture2DCopy

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Setters

//---------------------------------------------------------------------------

static inline void OpenCLTexture2DSetName(const GLuint nName,
										  OpenCL::Texture2DStruct *pSTexture2D)
{
	if( !pSTexture2D->mbIsAcquired )
	{
		pSTexture2D->mnName = nName;
	} // if
} // OpenCLTexture2DSetName

//---------------------------------------------------------------------------

static inline void OpenCLTexture2DSetMipLevel(const GLuint nMipLevel,
											  OpenCL::Texture2DStruct *pSTexture2D)
{
	if( !pSTexture2D->mbIsAcquired )
	{
		pSTexture2D->mnMipLevel = nMipLevel;
	} // if
} // OpenCLTexture2DSetMipLevel

//---------------------------------------------------------------------------

static inline void OpenCLTexture2DSetTarget(const GLenum nTarget,
											OpenCL::Texture2DStruct *pSTexture2D)
{
	if( !pSTexture2D->mbIsAcquired )
	{
		pSTexture2D->mnTarget = nTarget;
	} // if
} // OpenCLTexture2DSetTarget

//---------------------------------------------------------------------------

static inline void OpenCLTexture2DSetOrigin(const size_t nOriginX, 
											const size_t nOriginY, 
											OpenCL::Texture2DStruct *pSTexture2D)
{
	if( !pSTexture2D->mbIsAcquired )
	{
		pSTexture2D->maImageOrigin[0] = nOriginX;
		pSTexture2D->maImageOrigin[1] = nOriginY;
		pSTexture2D->maImageOrigin[2] = 0;
	} // if
} // OpenCLTexture2DSetOrigin

//---------------------------------------------------------------------------

static inline void OpenCLTexture2DSetRegion(const size_t nWidth, 
											const size_t nHeight,
											OpenCL::Texture2DStruct *pSTexture2D)
{
	if( !pSTexture2D->mbIsAcquired )
	{
		pSTexture2D->maImageRegion[0] = nWidth;
		pSTexture2D->maImageRegion[1] = nHeight;
		pSTexture2D->maImageRegion[2] = 1;
	} // if
} // OpenCLTexture2DSetRegion

//---------------------------------------------------------------------------
//
// Set a texture 2D to be read/write.
//
//---------------------------------------------------------------------------

static inline void OpenCLTexture2DSetReadWrite(OpenCL::Texture2DStruct *pSTexture2D)
{
	if( !pSTexture2D->mbIsAcquired )
	{
		pSTexture2D->mnImageFlags = CL_MEM_READ_WRITE;
	} // if
} // OpenCLTexture2DSetReadWrite

//---------------------------------------------------------------------------
//
// Set a texture 2D to use a host pointer.
//
//---------------------------------------------------------------------------

static inline void OpenCLTexture2DSetUseHostPointer(OpenCL::Texture2DStruct *pSTexture2D)
{
	if( !pSTexture2D->mbIsSetHPtrInUse && !pSTexture2D->mbIsAcquired )
	{
		pSTexture2D->mnImageFlags |= CL_MEM_USE_HOST_PTR;
		
		pSTexture2D->mbIsSetHPtrInUse = true;
		pSTexture2D->mbIsSetHPtrCopy  = true;
	} // if
} // OpenCLTexture2DSetUseHostPointer

//---------------------------------------------------------------------------
//
// Set a texture 2D to allocate a host pointer.
//
//---------------------------------------------------------------------------

static inline void OpenCLTexture2DSetAllocHostPointer(OpenCL::Texture2DStruct *pSTexture2D)
{
	if( !pSTexture2D->mbIsSetHPtrInUse && !pSTexture2D->mbIsAcquired )
	{
		pSTexture2D->mnImageFlags |= CL_MEM_ALLOC_HOST_PTR;
		
		pSTexture2D->mbIsSetHPtrInUse = true;
		pSTexture2D->mbIsSetHPtrCopy  = false;
	} // if
} // OpenCLTexture2DSetAllocHostPointer

//---------------------------------------------------------------------------
//
// Set a texture 2D to copy a host pointer.
//
//---------------------------------------------------------------------------

static inline void OpenCLTexture2DSetCopyHostPointer(OpenCL::Texture2DStruct *pSTexture2D)
{
	if( !pSTexture2D->mbIsSetHPtrCopy && !pSTexture2D->mbIsAcquired )
	{
		pSTexture2D->mnImageFlags |= CL_MEM_COPY_HOST_PTR;
		
		pSTexture2D->mbIsSetHPtrInUse = true;
		pSTexture2D->mbIsSetHPtrCopy  = true;
	} // if
} // OpenCLTexture2DSetCopyHostPointer

//---------------------------------------------------------------------------
//
// Set a texture 2D to be blocking.
//
//---------------------------------------------------------------------------

static inline void OpenCLTexture2DSetIsBlocking(OpenCL::Texture2DStruct *pSTexture2D)
{
	if( !pSTexture2D->mbIsAcquired )
	{
		pSTexture2D->mbIsBlocking = true;
	} // if
} // OpenCLTexture2DSetIsBlocking

//---------------------------------------------------------------------------
//
// Set a texture 2D to be non-blocking.
//
//---------------------------------------------------------------------------

static inline void OpenCLTexture2DSetIsNonBlocking(OpenCL::Texture2DStruct *pSTexture2D)
{
	if( !pSTexture2D->mbIsAcquired )
	{
		pSTexture2D->mbIsBlocking = false;
	} // if
} // OpenCLTexture2DSetIsNonBlocking

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Constructors

//---------------------------------------------------------------------------
//
// Construct a texture 2D object from a program object alias.
//
//---------------------------------------------------------------------------

OpenCL::Texture2D::Texture2D( const OpenCL::Program &rProgram )
{
	mpSTexture2D = OpenCLTexture2DCreateWithProgramAlias(rProgram);
} // Constructor

//---------------------------------------------------------------------------
//
// Construct a texture 2D object from a program object reference.
//
//---------------------------------------------------------------------------

OpenCL::Texture2D::Texture2D( const OpenCL::Program *pProgram )
{
	mpSTexture2D = OpenCLTexture2DCreateWithProgramRef(pProgram);
} // Constructor

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Copy Constructor

//---------------------------------------------------------------------------
//
// Construct a deep copy of a texture 2D object from another. 
//
//---------------------------------------------------------------------------

OpenCL::Texture2D::Texture2D( const OpenCL::Texture2D &rTexture2D ) 
{
	mpSTexture2D = OpenCLTexture2DCopy(rTexture2D.mpSTexture2D, 0);
} // Copy Constructor

//---------------------------------------------------------------------------

OpenCL::Texture2D::Texture2D( const OpenCL::Texture2D *pSTexture2D ) 
{
	if( pSTexture2D != NULL )
	{
		mpSTexture2D = OpenCLTexture2DCopy(pSTexture2D->mpSTexture2D, 0);
	} // if
} // Copy Constructor

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Assignment Operator

//---------------------------------------------------------------------------
//
// Construct a deep copy of a texture 2D object from another using the 
// assignment operator.
//
//---------------------------------------------------------------------------

OpenCL::Texture2D &OpenCL::Texture2D::operator=(const OpenCL::Texture2D &rTexture2D)
{
	if( ( this != &rTexture2D ) && ( rTexture2D.mpSTexture2D != NULL ) )
	{
		OpenCLTexture2DRelease( mpSTexture2D );
		
		mpSTexture2D = OpenCLTexture2DCopy(rTexture2D.mpSTexture2D, 0);
	} // if
	
	return( *this );
} // Assignment Operator

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Destructor

//---------------------------------------------------------------------------
//
// Release the texture 2D object.
//
//---------------------------------------------------------------------------

OpenCL::Texture2D::~Texture2D()
{
	OpenCLTexture2DRelease(mpSTexture2D);
} // Destructor

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Setters

//---------------------------------------------------------------------------

void OpenCL::Texture2D::SetName(const GLuint nName)
{
	OpenCLTexture2DSetName(nName, mpSTexture2D);
} // SetName

//---------------------------------------------------------------------------

void OpenCL::Texture2D::SetMipLevel(const GLuint nMipLevel)
{
	OpenCLTexture2DSetMipLevel(nMipLevel, mpSTexture2D);
} // SetMipLevel

//---------------------------------------------------------------------------

void OpenCL::Texture2D::SetTarget(const GLenum nTarget)
{
	OpenCLTexture2DSetTarget(nTarget, mpSTexture2D);
} // SetTarget

//---------------------------------------------------------------------------

void OpenCL::Texture2D::SetOrigin(const size_t nOriginX, const size_t nOriginY)
{
	OpenCLTexture2DSetOrigin(nOriginX, nOriginY, mpSTexture2D);
} // SetOrigin

//---------------------------------------------------------------------------

void OpenCL::Texture2D::SetRegion(const size_t nWidth, const size_t nHeight)
{
	OpenCLTexture2DSetRegion(nWidth, nHeight, mpSTexture2D);
} // SetRegion

//---------------------------------------------------------------------------

void OpenCL::Texture2D::SetIsBlocking()
{
	OpenCLTexture2DSetIsBlocking(mpSTexture2D);
} // SetIsBlocking

//---------------------------------------------------------------------------

void OpenCL::Texture2D::SetIsNonBlocking()
{
	OpenCLTexture2DSetIsNonBlocking(mpSTexture2D);
} // SetIsNonBlocking

//---------------------------------------------------------------------------

void OpenCL::Texture2D::SetReadWrite()
{
	OpenCLTexture2DSetReadWrite(mpSTexture2D);
} // SetReadWrite

//---------------------------------------------------------------------------

void OpenCL::Texture2D::SetUseHostPointer()
{
	OpenCLTexture2DSetUseHostPointer(mpSTexture2D);
} // SetUseHostPointer

//---------------------------------------------------------------------------

void OpenCL::Texture2D::SetAllocHostPointer()
{
	OpenCLTexture2DSetAllocHostPointer(mpSTexture2D);
} // SetAllocHostPointer

//---------------------------------------------------------------------------

void OpenCL::Texture2D::SetCopyHostPointer()
{
	OpenCLTexture2DSetCopyHostPointer(mpSTexture2D);
} // SetCopyHostPointer

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Getters

//---------------------------------------------------------------------------
//
// Get the OpenCL memory buffer.
//
//---------------------------------------------------------------------------

const cl_mem OpenCL::Texture2D::GetImage() const
{
	return( mpSTexture2D->mpImageBuffer );
} // GetImage

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Utilities

//---------------------------------------------------------------------------
//
// Once the texture 2D object attributes have been set, acquire an actual 
// image buffer from OpenCL.
//
//---------------------------------------------------------------------------

bool OpenCL::Texture2D::Generate()
{
	return( OpenCLTexture2DGenerate(mpSTexture2D) ); 
} // Acquire

//---------------------------------------------------------------------------

bool OpenCL::Texture2D::Read(const size_t *pOrigin, 
							 const size_t *pRegion,
							 void *pHost,
							 size_t *pRowPitch)
{
	return( OpenCLTexture2DEnqueueReadImage(pOrigin,
											pRegion,
											pHost,
											pRowPitch,
											mpSTexture2D) );
} // Read

//---------------------------------------------------------------------------

bool OpenCL::Texture2D::Write(const size_t *pOrigin, 
							  const size_t *pRegion,
							  const void * const pHost,
							  size_t *pRowPitch)
{
	return( OpenCLTexture2DEnqueueWriteImage(pOrigin,
											 pRegion,
											 pHost,
											 pRowPitch,
											 mpSTexture2D) );
} // Write

//---------------------------------------------------------------------------

bool OpenCL::Texture2D::Copy(const Buffer &rBuffer)
{
	return( OpenCLTexture2DCopyFromBufferAlias(rBuffer, mpSTexture2D) );
} // Copy

//---------------------------------------------------------------------------

bool OpenCL::Texture2D::Copy(const Buffer *pBuffer)
{
	return( OpenCLTexture2DCopyFromBufferRef(pBuffer, mpSTexture2D) );
} // Copy

//---------------------------------------------------------------------------
//
// Make a full copy of the memory associated with the source texture image
// buffer.
//
//---------------------------------------------------------------------------

bool OpenCL::Texture2D::Copy(const Texture2D &rSrcTexture2D)
{
	return( OpenCLTexture2DClone(NULL, 
								 NULL, 
								 rSrcTexture2D.mpSTexture2D, 
								 mpSTexture2D) );
} // Copy

//---------------------------------------------------------------------------
//
// Make a copy of the memory associated with the source texture image 
// buffer in the rectangle described by its width and height, and centered
// at (0, 0).
//
//---------------------------------------------------------------------------

bool OpenCL::Texture2D::Copy(const size_t *pRegion, 
							 const Texture2D &rSrcTexture2D)
{
	return( OpenCLTexture2DClone(NULL, 
								 pRegion, 
								 rSrcTexture2D.mpSTexture2D, 
								 mpSTexture2D) );
} // Copy

//---------------------------------------------------------------------------
//
// Make a copy of the memory associated with the source texture image 
// buffer in the rectangle described by its origin, width and height.
//
//---------------------------------------------------------------------------

bool OpenCL::Texture2D::Copy(const size_t *pOrigin, 
							 const size_t *pRegion, 
							 const Texture2D &rSrcTexture2D)
{
	return( OpenCLTexture2DClone(pOrigin, 
								 pRegion, 
								 rSrcTexture2D.mpSTexture2D, 
								 mpSTexture2D) );
} // Copy

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Mapped Image

//---------------------------------------------------------------------------

void *OpenCL::Texture2D::ImagePointer()
{
	return( mpSTexture2D->mpMappedBuffer );
} // ImagePointer

//---------------------------------------------------------------------------

bool OpenCL::Texture2D::ImageMap(const size_t *pOrigin, 
								 const size_t *pRegion, 
								 size_t *pImageRowPitch)
{
	return( OpenCLTexture2DEnqueueMapImage(pOrigin, 
										   pRegion,
										   pImageRowPitch, 
										   mpSTexture2D) );
} // ImageMap

//---------------------------------------------------------------------------

bool OpenCL::Texture2D::ImageUnmap()
{
	return( OpenCLTexture2DEnqueueUnmapImage(mpSTexture2D) );
} // ImageUnmap

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
