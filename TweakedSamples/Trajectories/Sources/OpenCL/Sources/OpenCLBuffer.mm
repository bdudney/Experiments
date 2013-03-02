//---------------------------------------------------------------------------
//
//	File: OpenCLBuffer.mm
//
//  Abstract: A utility class to create an OpenCL memory buffer
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

#import "OpenCLBuffer.h"

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Data Structures

//---------------------------------------------------------------------------

class OpenCL::BufferStruct
{
public:
	cl_context        mpContext;
	cl_command_queue  mpCommandQueue;
	cl_mem_flags      mnBufferFlags;
	cl_int            mnError;
	cl_mem            mpMemBuffer;
	cl_uint           mnBufferIndex;
	size_t            mnBufferSize;
	bool              mbIsBlocking;
	bool              mbIsPOT;
	bool              mbIsAcquired;
	bool              mbIsSetHPtrInUse;
	bool              mbIsSetHPtrCopy;
	void             *mpMappedBuffer;
};

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Utilities - Numerics

//---------------------------------------------------------------------------
//
// Get the next power of 2.  If already a power of 2 then returns the same
// input value.
//
//---------------------------------------------------------------------------

static cl_uint OpenCLGetPOT( cl_uint nValue )
{
	--nValue;
	
	nValue |= (nValue >> 1);
	nValue |= (nValue >> 2);
	nValue |= (nValue >> 4);
	nValue |= (nValue >> 8);
	nValue |= (nValue >> 16);
	
	++nValue;
	
	return( nValue );
} // OpenCLGetPOT

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
//
// For a complete discussion of OpenCL buffer APIs refer to,
//
// http://www.khronos.org/registry/cl/specs/opencl-1.0.33.pdf
//
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Utilities - Wrappers

//---------------------------------------------------------------------------

static inline bool OpenCLBufferCreate(void *pHost,
									  OpenCL::BufferStruct *pSBuffer)
{
    pSBuffer->mpMemBuffer = clCreateBuffer(pSBuffer->mpContext, 
										   pSBuffer->mnBufferFlags, 
										   pSBuffer->mnBufferSize, 
										   pHost, 
										   &pSBuffer->mnError);
	
	bool bBufferCreated = ( pSBuffer->mpMemBuffer != NULL ) && ( pSBuffer->mnError == CL_SUCCESS );
	
    if( !bBufferCreated )
    {
        std::cerr << ">> ERROR: OpenCL Buffer - Failed to create buffer!" << std::endl;
    } // if
	
	return( bBufferCreated ); 
} // OpenCLBufferCreate

//---------------------------------------------------------------------------

static inline bool OpenCLBufferEnqueueCopy(const size_t nBufferSize, 
										   OpenCL::BufferStruct *pSBufferSrc,
										   OpenCL::BufferStruct *pSBufferDst)
{
	pSBufferDst->mnError = clEnqueueCopyBuffer(pSBufferDst->mpCommandQueue, 
											   pSBufferSrc->mpMemBuffer,
											   pSBufferDst->mpMemBuffer, 
											   0,
											   0,
											   nBufferSize, 
											   0,
											   NULL,
											   NULL);
	
	bool bCopiedSource = pSBufferDst->mnError == CL_SUCCESS;
	
	if( !bCopiedSource )
	{
		std::cerr << ">> ERROR: OpenCL Buffer - Failed to make a copy of the source buffer!" << std::endl;
	} // if
	
	return( bCopiedSource ); 
} // OpenCLBufferEnqueueCopy

//---------------------------------------------------------------------------

static inline bool OpenCLBufferEnqueueClone(OpenCL::BufferStruct *pSBufferSrc,
											OpenCL::BufferStruct *pSBufferDst)
{
	pSBufferDst->mnError = clEnqueueCopyBuffer(pSBufferDst->mpCommandQueue, 
											   pSBufferSrc->mpMemBuffer,
											   pSBufferDst->mpMemBuffer, 
											   0,
											   0,
											   pSBufferDst->mnBufferSize, 
											   0,
											   NULL,
											   NULL);
	
	bool bClonedSource = pSBufferDst->mnError == CL_SUCCESS;
	
	if( !bClonedSource )
	{
		std::cerr << ">> ERROR: OpenCL Buffer - Failed to clone the source buffer!" << std::endl;
	} // if
	
	return( bClonedSource ); 
} // OpenCLBufferEnqueueClone

//---------------------------------------------------------------------------

static bool OpenCLBufferEnqueueRead(const size_t nBufferSize, 
									void *pHost,
									OpenCL::BufferStruct *pSBuffer)
{
	bool bReadSource = false;
	
	if( pSBuffer->mbIsAcquired )
	{
		pSBuffer->mnError = clEnqueueReadBuffer(pSBuffer->mpCommandQueue, 
												pSBuffer->mpMemBuffer, 
												pSBuffer->mbIsBlocking, 
												0, 
												nBufferSize, 
												pHost, 
												0, 
												NULL, 
												NULL);
		
		bReadSource = pSBuffer->mnError == CL_SUCCESS;
		
		if( !bReadSource )
		{
			std::cerr << ">> ERROR: OpenCL Buffer - Failed to Read from the device!" << std::endl;
		} // if
	} // if
	
	return( bReadSource ); 
} // OpenCLBufferEnqueueRead

//---------------------------------------------------------------------------

static bool OpenCLBufferEnqueueWrite(const size_t nBufferSize, 
									 const void * const pHost,
									 OpenCL::BufferStruct *pSBuffer)
{
	bool bWroteSource = false;
	
	if( pSBuffer->mbIsAcquired )
	{
		pSBuffer->mnError = clEnqueueWriteBuffer(pSBuffer->mpCommandQueue, 
												 pSBuffer->mpMemBuffer, 
												 pSBuffer->mbIsBlocking, 
												 0, 
												 nBufferSize, 
												 pHost, 
												 0, 
												 NULL, 
												 NULL);
		
		bWroteSource = pSBuffer->mnError == CL_SUCCESS;
		
		if( !bWroteSource )
		{
			std::cerr << ">> ERROR: OpenCL Buffer - Failed to write to source array!" << std::endl;
		} // if
	} // if
	
	return( bWroteSource ); 
} // OpenCLBufferEnqueueWrite

//---------------------------------------------------------------------------

static bool OpenCLBufferEnqueueMapBuffer(const size_t nOffset, 
										 const size_t nSize,
										 OpenCL::BufferStruct *pSBuffer)
{
	bool bMappedBuffer = false;
	
	if( pSBuffer->mbIsAcquired )
	{
		pSBuffer->mpMappedBuffer = clEnqueueMapBuffer(pSBuffer->mpCommandQueue,
													  pSBuffer->mpMemBuffer,
													  pSBuffer->mbIsBlocking, 
													  pSBuffer->mnBufferFlags,
													  nOffset,
													  nSize,
													  0,
													  NULL,
													  NULL,
													  &pSBuffer->mnError);
		
		bMappedBuffer = ( pSBuffer->mnError == CL_SUCCESS ) && ( pSBuffer->mpMappedBuffer != NULL );
		
		if( !bMappedBuffer )
		{
			std::cerr << ">> ERROR: OpenCL Buffer - Failed to map a buffer!" << std::endl;
		} // if
	} // if
	
	return( bMappedBuffer ); 
} // OpenCLBufferEnqueueMapBuffer

//---------------------------------------------------------------------------

static bool OpenCLBufferEnqueueUnmapBuffer(OpenCL::BufferStruct *pSBuffer)
{
	bool bUnmappedBuffer = false;
	
	if( pSBuffer->mbIsAcquired )
	{
		pSBuffer->mnError = clEnqueueUnmapMemObject(pSBuffer->mpCommandQueue,
													pSBuffer->mpMemBuffer,
													pSBuffer->mpMappedBuffer, 
													0,
													NULL,
													NULL);
		
		bUnmappedBuffer = pSBuffer->mnError == CL_SUCCESS;
		
		if( !bUnmappedBuffer )
		{
			std::cerr << ">> ERROR: OpenCL Buffer - Failed to unmap a buffer!" << std::endl;
		} // if
	} // if
	
	return( bUnmappedBuffer ); 
} // OpenCLBufferEnqueueUnmapBuffer

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Acquire

//---------------------------------------------------------------------------
//
// If a POT size is requested, and the input size is NPOT, convert it to a
// POT size.
//
//---------------------------------------------------------------------------

static inline size_t OpenCLBufferSetSize(OpenCL::BufferStruct *pSBuffer,
										 const size_t nBufferSize)
{
	return( pSBuffer->mbIsPOT ? OpenCLGetPOT(nBufferSize) : nBufferSize );
} // OpenCLBufferSetSize

//---------------------------------------------------------------------------
//
// Once the buffer attributes have been set, acquire an actual buffer from
// OpenCL, using size and host memory.
//
//---------------------------------------------------------------------------

static bool OpenCLBufferAcquire(const cl_uint nBufferIndex, 
								const size_t nBufferSize,
								void *pHost,
								OpenCL::BufferStruct *pSBuffer)
{
	if( !pSBuffer->mbIsAcquired )
	{
		pSBuffer->mnBufferIndex = nBufferIndex;
		pSBuffer->mnBufferSize  = OpenCLBufferSetSize(pSBuffer, nBufferSize);
		pSBuffer->mbIsAcquired  = OpenCLBufferCreate(pHost, pSBuffer);
	} // if
	
	return( pSBuffer->mbIsAcquired );
} // Acquire

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Destructor

//---------------------------------------------------------------------------

static bool OpenCLBufferReleaseMemory(OpenCL::BufferStruct *pSBuffer)
{
	bool bValidRefCount = false;
	
	if( pSBuffer->mbIsAcquired )
	{
		cl_int nBufferRefCount = 0;
		
		pSBuffer->mnError = clGetMemObjectInfo(pSBuffer->mpMemBuffer, 
											   CL_MEM_REFERENCE_COUNT, 
											   sizeof(cl_int), 
											   &nBufferRefCount,
											   NULL);
		
		bValidRefCount = ( nBufferRefCount ) && ( pSBuffer->mnError == CL_SUCCESS );
		
		if( !bValidRefCount )
		{
			std::cerr << ">> ERROR: OpenCL Buffer - Failed to validate the reference count!" << std::endl;
		} // if
		else
		{
			clReleaseMemObject(pSBuffer->mpMemBuffer);
		} // else
	} // if
	
	return( bValidRefCount );
} // OpenCLBufferReleaseMemory

//---------------------------------------------------------------------------

static void OpenCLBufferRelease(OpenCL::BufferStruct *pSBuffer)
{
	if( pSBuffer != NULL )
	{
		OpenCLBufferReleaseMemory( pSBuffer );
		
		delete pSBuffer;
		
		pSBuffer = NULL;
	} // if
} // OpenCLBufferRelease

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Constructor

//---------------------------------------------------------------------------
//
// Construct a buffer object from a program object alias.
//
//---------------------------------------------------------------------------

static OpenCL::BufferStruct *OpenCLBufferCreateWithProgramAlias( const OpenCL::Program &rProgram )
{
	OpenCL::BufferStruct *pSBuffer = new OpenCL::BufferStruct;
	
	if( pSBuffer != NULL )
	{
		pSBuffer->mpContext      = rProgram.GetContext();
		pSBuffer->mpCommandQueue = rProgram.GetCommandQueue();
		pSBuffer->mnBufferFlags  = CL_MEM_READ_WRITE;
		pSBuffer->mnError        = CL_SUCCESS;
		pSBuffer->mnBufferSize   = 0;
		pSBuffer->mnBufferIndex  = 0;
		pSBuffer->mpMemBuffer    = NULL;
		pSBuffer->mpMappedBuffer = NULL;
		
		pSBuffer->mbIsBlocking     = true;
		pSBuffer->mbIsPOT          = true;
		pSBuffer->mbIsAcquired     = false;
		pSBuffer->mbIsSetHPtrInUse = false;
		pSBuffer->mbIsSetHPtrCopy  = false;
	} // if
	
	return( pSBuffer );
} // OpenCLBufferCreateWithProgramAlias

//---------------------------------------------------------------------------
//
// Construct a buffer object from a program object reference.
//
//---------------------------------------------------------------------------

static OpenCL::BufferStruct *OpenCLBufferCreateWithProgramRef( const OpenCL::Program *pProgram )
{
	OpenCL::BufferStruct *pSBuffer = NULL;
	
	if( pProgram != NULL )
	{
		pSBuffer = OpenCLBufferCreateWithProgramAlias(*pProgram);
	} // if
	
	return( pSBuffer );
} // OpenCLBufferCreateWithProgramRef

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Copy Utilities

//---------------------------------------------------------------------------
//
// Copy from the OpenCL memory associated with the source buffer into the 
// OpenCL memory instance variable of the buffer structure.  If the buffer 
// copy size that is passed in, is 0, then make a full copy from source to 
// destination.
//
//---------------------------------------------------------------------------

static bool OpenCLBufferCopy(const size_t nBufferExpSize,
							 OpenCL::BufferStruct *pSBufferSrc, 
							 OpenCL::BufferStruct *pSBufferDst)
{
	bool bBufferCopied = false;
	
	if( pSBufferDst->mbIsAcquired )
	{
		size_t nBufferActSize = ( nBufferExpSize == 0 ) ? pSBufferSrc->mnBufferSize : nBufferExpSize;
		
		if( nBufferActSize > 0 ) 
		{
			nBufferActSize = ( nBufferActSize < pSBufferDst->mnBufferSize ) ? nBufferActSize : pSBufferDst->mnBufferSize;
			
			bBufferCopied = OpenCLBufferEnqueueCopy(nBufferActSize, 
													pSBufferSrc,
													pSBufferDst);
		} // if
	} // if
	
	return( bBufferCopied );
} // OpenCLBufferCopy

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Copy Constructor

//---------------------------------------------------------------------------
//
// Clone all buffer attributes.
//
//---------------------------------------------------------------------------

static OpenCL::BufferStruct *OpenCLBufferClone(OpenCL::BufferStruct *pSBufferSrc)
{
	OpenCL::BufferStruct *pSBufferDst = NULL;
	
	if( pSBufferSrc != NULL )
	{
		pSBufferDst = new OpenCL::BufferStruct;
		
		if( pSBufferDst != NULL )
		{
			pSBufferDst->mbIsSetHPtrInUse = pSBufferSrc->mbIsSetHPtrInUse;
			pSBufferDst->mbIsSetHPtrCopy  = pSBufferSrc->mbIsSetHPtrCopy;
			pSBufferDst->mbIsBlocking     = pSBufferSrc->mbIsBlocking;
			pSBufferDst->mbIsPOT          = pSBufferSrc->mbIsPOT;
			pSBufferDst->mbIsAcquired     = false;
			
			pSBufferDst->mpContext      = pSBufferSrc->mpContext;
			pSBufferDst->mpCommandQueue = pSBufferSrc->mpCommandQueue;
			pSBufferDst->mnBufferFlags  = pSBufferSrc->mnBufferFlags;
			pSBufferDst->mnBufferSize   = pSBufferSrc->mnBufferSize;
			pSBufferDst->mnBufferIndex  = pSBufferSrc->mnBufferIndex;
			pSBufferDst->mnError        = pSBufferSrc->mnError;
			pSBufferDst->mpMappedBuffer = pSBufferSrc->mpMappedBuffer;
			pSBufferDst->mpMemBuffer    = NULL;
			pSBufferDst->mbIsAcquired   = OpenCLBufferCreate(NULL, pSBufferDst);
			
			if( pSBufferDst->mbIsAcquired )
			{
				bool bBufferCopied = OpenCLBufferEnqueueClone(pSBufferSrc, pSBufferDst);
				
				if( !bBufferCopied )
				{
					std::cerr << ">> ERROR: OpenCL Buffer - Failed to clone the source buffer!" << std::endl;
				} // if
			} // if
		} // if
	} // if	
	
	return( pSBufferDst );
} // OpenCLBufferClone

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Setters

//---------------------------------------------------------------------------
//
// Set a buffer to be read-only.
//
//---------------------------------------------------------------------------

static inline void OpenCLBufferSetReadOnly(OpenCL::BufferStruct *pSBuffer)
{
	if( !pSBuffer->mbIsAcquired )
	{
		pSBuffer->mnBufferFlags = CL_MEM_READ_ONLY;
	} // if
} // OpenCLBufferSetReadOnly

//---------------------------------------------------------------------------
//
// Set a buffer to be write-only.
//
//---------------------------------------------------------------------------

static inline void OpenCLBufferSetWriteOnly(OpenCL::BufferStruct *pSBuffer)
{
	if( !pSBuffer->mbIsAcquired )
	{
		pSBuffer->mnBufferFlags = CL_MEM_WRITE_ONLY;
	} // if
} // OpenCLBufferSetWriteOnly

//---------------------------------------------------------------------------
//
// Set a buffer to use a host pointer.
//
//---------------------------------------------------------------------------

static inline void OpenCLBufferSetUseHostPointer(OpenCL::BufferStruct *pSBuffer)
{
	if( !pSBuffer->mbIsSetHPtrInUse && !pSBuffer->mbIsAcquired )
	{
		pSBuffer->mnBufferFlags |= CL_MEM_USE_HOST_PTR;
		
		pSBuffer->mbIsSetHPtrInUse = true;
		pSBuffer->mbIsSetHPtrCopy  = true;
	} // if
} // OpenCLBufferSetUseHostPointer

//---------------------------------------------------------------------------
//
// Set a buffer to allocate a host pointer.
//
//---------------------------------------------------------------------------

static inline void OpenCLBufferSetAllocHostPointer(OpenCL::BufferStruct *pSBuffer)
{
	if( !pSBuffer->mbIsSetHPtrInUse && !pSBuffer->mbIsAcquired )
	{
		pSBuffer->mnBufferFlags |= CL_MEM_ALLOC_HOST_PTR;
		
		pSBuffer->mbIsSetHPtrInUse = true;
		pSBuffer->mbIsSetHPtrCopy  = false;
	} // if
} // OpenCLBufferSetAllocHostPointer

//---------------------------------------------------------------------------
//
// Set a buffer to copy a host pointer.
//
//---------------------------------------------------------------------------

static inline void OpenCLBufferSetCopyHostPointer(OpenCL::BufferStruct *pSBuffer)
{
	if( !pSBuffer->mbIsSetHPtrCopy && !pSBuffer->mbIsAcquired )
	{
		pSBuffer->mnBufferFlags |= CL_MEM_COPY_HOST_PTR;
		
		pSBuffer->mbIsSetHPtrInUse = true;
		pSBuffer->mbIsSetHPtrCopy  = true;
	} // if
} // OpenCLBufferSetCopyHostPointer

//---------------------------------------------------------------------------
//
// Set a buffer to be blocking.
//
//---------------------------------------------------------------------------

static inline void OpenCLBufferSetIsBlocking(OpenCL::BufferStruct *pSBuffer)
{
	if( !pSBuffer->mbIsAcquired )
	{
		pSBuffer->mbIsBlocking = true;
	} // if
} // OpenCLBufferSetIsBlocking

//---------------------------------------------------------------------------
//
// Set a buffer to be non-blocking.
//
//---------------------------------------------------------------------------

static inline void OpenCLBufferSetIsNonBlocking(OpenCL::BufferStruct *pSBuffer)
{
	if( !pSBuffer->mbIsAcquired )
	{
		pSBuffer->mbIsBlocking = false;
	} // if
} // OpenCLBufferSetIsNonBlocking

//---------------------------------------------------------------------------
//
// Set a buffer to be blocking.
//
//---------------------------------------------------------------------------

static inline void OpenCLBufferSetIsPOT(OpenCL::BufferStruct *pSBuffer)
{
	if( !pSBuffer->mbIsAcquired )
	{
		pSBuffer->mbIsPOT = true;
	} // if
} // OpenCLBufferSetIsPOT

//---------------------------------------------------------------------------
//
// Set a buffer to be non-blocking.
//
//---------------------------------------------------------------------------

static inline void OpenCLBufferSetIsNPOT(OpenCL::BufferStruct *pSBuffer)
{
	if( !pSBuffer->mbIsAcquired )
	{
		pSBuffer->mbIsPOT = false;
	} // if
} // OpenCLBufferSetIsNPOT

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Constructors

//---------------------------------------------------------------------------
//
// Construct a buffer object from a program object alias.
//
//---------------------------------------------------------------------------

OpenCL::Buffer::Buffer( const OpenCL::Program &rProgram )
{
	mpSBuffer = OpenCLBufferCreateWithProgramAlias(rProgram);
} // Constructor

//---------------------------------------------------------------------------
//
// Construct a buffer object from a program object reference.
//
//---------------------------------------------------------------------------

OpenCL::Buffer::Buffer( const OpenCL::Program *pProgram )
{
	mpSBuffer = OpenCLBufferCreateWithProgramRef(pProgram);
} // Constructor

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Copy Constructor

//---------------------------------------------------------------------------
//
// Construct a deep copy of a buffer object from another. 
//
//---------------------------------------------------------------------------

OpenCL::Buffer::Buffer( const OpenCL::Buffer &rBuffer ) 
{
	mpSBuffer = OpenCLBufferClone(rBuffer.mpSBuffer);
} // Copy Constructor

//---------------------------------------------------------------------------

OpenCL::Buffer::Buffer( const OpenCL::Buffer *pSBuffer ) 
{
	if( pSBuffer != NULL )
	{
		mpSBuffer = OpenCLBufferClone(pSBuffer->mpSBuffer);
	} // if
} // Copy Constructor

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Assignment Operator

//---------------------------------------------------------------------------
//
// Construct a deep copy of a buffer object from another using the 
// assignment operator.
//
//---------------------------------------------------------------------------

OpenCL::Buffer &OpenCL::Buffer::operator=(const OpenCL::Buffer &rBuffer)
{
	if( ( this != &rBuffer ) && ( rBuffer.mpSBuffer != NULL ) )
	{
		OpenCLBufferRelease( mpSBuffer );
		
		mpSBuffer = OpenCLBufferClone(rBuffer.mpSBuffer);
	} // if
	
	return( *this );
} // Assignment Operator

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Destructor

//---------------------------------------------------------------------------
//
// Release the buffer object.
//
//---------------------------------------------------------------------------

OpenCL::Buffer::~Buffer()
{
	OpenCLBufferRelease(mpSBuffer);
} // Destructor

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Setters

//---------------------------------------------------------------------------
//
// Set a buffer to be read-only.
//
//---------------------------------------------------------------------------

void OpenCL::Buffer::SetReadOnly()
{
	OpenCLBufferSetReadOnly(mpSBuffer);
} // SetReadOnly

//---------------------------------------------------------------------------
//
// Set a buffer to be write-only.
//
//---------------------------------------------------------------------------

void OpenCL::Buffer::SetWriteOnly()
{
	OpenCLBufferSetWriteOnly(mpSBuffer);
} // SetWriteOnly

//---------------------------------------------------------------------------
//
// Set a buffer to use a host pointer.
//
//---------------------------------------------------------------------------

void OpenCL::Buffer::SetUseHostPointer()
{
	OpenCLBufferSetUseHostPointer(mpSBuffer);
} // SetUseHostPointer

//---------------------------------------------------------------------------
//
// Set a buffer to allocate a host pointer.
//
//---------------------------------------------------------------------------

void OpenCL::Buffer::SetAllocHostPointer()
{
	OpenCLBufferSetAllocHostPointer(mpSBuffer);
} // SetAllocHostPointer

//---------------------------------------------------------------------------
//
// Set a buffer to copy a host pointer.
//
//---------------------------------------------------------------------------

void OpenCL::Buffer::SetCopyHostPointer()
{
	OpenCLBufferSetCopyHostPointer(mpSBuffer);
} // SetCopyHostPointer

//---------------------------------------------------------------------------
//
// Set a buffer to be blocking.
//
//---------------------------------------------------------------------------

void OpenCL::Buffer::SetIsBlocking()
{
	OpenCLBufferSetIsBlocking(mpSBuffer);
} // SetIsBlocking

//---------------------------------------------------------------------------
//
// Set a buffer to be non-blocking.
//
//---------------------------------------------------------------------------

void OpenCL::Buffer::SetIsNonBlocking()
{
	OpenCLBufferSetIsNonBlocking(mpSBuffer);
} // SetIsNonBlocking

//---------------------------------------------------------------------------
//
// Set a buffer to be POT.
//
//---------------------------------------------------------------------------

void OpenCL::Buffer::SetIsPOT()
{
	OpenCLBufferSetIsPOT(mpSBuffer);
} // SetIsPOT

//---------------------------------------------------------------------------
//
// Set a buffer to be NPOT.
//
//---------------------------------------------------------------------------

void OpenCL::Buffer::SetIsNPOT()
{
	OpenCLBufferSetIsNPOT(mpSBuffer);
} // SetIsNPOT

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Getters

//---------------------------------------------------------------------------
//
// Get the OpenCL memory buffer.
//
//---------------------------------------------------------------------------

const cl_mem OpenCL::Buffer::GetBuffer() const
{
	return( mpSBuffer->mpMemBuffer );
} // GetBuffer

//---------------------------------------------------------------------------
//
// Get the OpenCL memory buffer size - POT on return.
//
//---------------------------------------------------------------------------

const size_t OpenCL::Buffer::GetBufferSize() const
{
	return( mpSBuffer->mnBufferSize );
} // GetBufferSize

//---------------------------------------------------------------------------
//
// Get the OpenCL memory buffer parameter index.
//
//---------------------------------------------------------------------------

const cl_uint OpenCL::Buffer::GetBufferIndex() const
{
	return( mpSBuffer->mnBufferIndex );
} // GetBufferIndex

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Utilities

//---------------------------------------------------------------------------
//
// Once the buffer attributes have been set, acquire an actual buffer from
// OpenCL.
//
//---------------------------------------------------------------------------

bool OpenCL::Buffer::Acquire(const cl_uint nBufferIndex, 
							 const size_t nBufferSize)
{
	return( OpenCLBufferAcquire(nBufferIndex, 
								nBufferSize,
								NULL,
								mpSBuffer) ); 
} // Acquire

//---------------------------------------------------------------------------
//
// Once the buffer attributes have been set, acquire an actual buffer from
// OpenCL with the contents of the host memory.
//
//---------------------------------------------------------------------------

bool OpenCL::Buffer::Acquire(const cl_uint nBufferIndex, 
							 const size_t nBufferSize, 
							 void *pHost)
{
	return( OpenCLBufferAcquire(nBufferIndex, 
								nBufferSize,
								pHost,
								mpSBuffer) ); 
} // Acquire

//---------------------------------------------------------------------------
//
// Write to the buffer object with the contents of host memory.
//
//---------------------------------------------------------------------------

bool OpenCL::Buffer::Write(const size_t nBufferSize, 
						   const void * const pHost)
{
	return( OpenCLBufferEnqueueWrite(nBufferSize, 
									 pHost,
									 mpSBuffer) ); 
} // Write

//---------------------------------------------------------------------------
//
// Read from the buffer object with the contents of host memory.
//
//---------------------------------------------------------------------------

bool OpenCL::Buffer::Read(const size_t nBufferSize, 
						  void *pHost)
{
	return( OpenCLBufferEnqueueRead(nBufferSize, 
									pHost,
									mpSBuffer) ); 
} // Read

//---------------------------------------------------------------------------
//
// Make a full copy of the memory associated with the source buffer object.
//
//---------------------------------------------------------------------------

bool OpenCL::Buffer::Copy(const Buffer &rSrcBuffer)
{
	return( OpenCLBufferCopy(0, rSrcBuffer.mpSBuffer, mpSBuffer) );
} // Copy

//---------------------------------------------------------------------------
//
// Make a copy of the memory associated with the source buffer object.
//
//---------------------------------------------------------------------------

bool OpenCL::Buffer::Copy(const size_t nBufferSize, 
						  const Buffer &rSrcBuffer)
{
	return( OpenCLBufferCopy(nBufferSize, 
							 rSrcBuffer.mpSBuffer, 
							 mpSBuffer) );
} // Copy

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Mapped Buffer

//---------------------------------------------------------------------------

void *OpenCL::Buffer::BufferPointer()
{
	return( mpSBuffer->mpMappedBuffer );
} // BufferPointer

//---------------------------------------------------------------------------

bool OpenCL::Buffer::BufferMap(const size_t nOffset, 
							   const size_t nSize)
{
	return( OpenCLBufferEnqueueMapBuffer(nOffset, 
										 nSize, 
										 mpSBuffer) );
} // BufferMap

//---------------------------------------------------------------------------

bool OpenCL::Buffer::BufferUnmap()
{
	return( OpenCLBufferEnqueueUnmapBuffer(mpSBuffer) );
} // BufferUnmap

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
