//---------------------------------------------------------------------------
//
//	File: OpenCLKernel.mm
//
//  Abstract: A utility class to manage OpenCL kernels
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
#import <map>

//---------------------------------------------------------------------------

#import <OpenCL/opencl.h>

//---------------------------------------------------------------------------

#import "OpenCLKernel.h"

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Constants

//---------------------------------------------------------------------------

static const size_t kOpenCLBufferSize = sizeof(cl_mem);

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Data Structures

//---------------------------------------------------------------------------

struct OpenCLKernelSize
{
	size_t mnWidth;
	size_t mnHeight;
};

typedef struct OpenCLKernelSize OpenCLKernelSize;

//---------------------------------------------------------------------------

struct OpenCLKernelWorkGroup
{
	OpenCLKernelSize maLocalWorkSize;
	OpenCLKernelSize maGlobalWorkSize;
};

typedef struct OpenCLKernelWorkGroup OpenCLKernelWorkGroup;

//---------------------------------------------------------------------------

typedef std::map<std::string,cl_kernel>              OpenCLKernelMap;
typedef std::map<std::string,size_t>                 OpenCLULongMap;
typedef std::map<std::string,OpenCLKernelWorkGroup>  OpenCLKernelWorkGroupMap;

typedef OpenCLULongMap::iterator            OpenCLULongMapIterator;
typedef OpenCLKernelMap::iterator           OpenCLKernelMapIterator;
typedef OpenCLKernelWorkGroupMap::iterator  OpenCLKernelWorkGroupMapIterator;

//---------------------------------------------------------------------------

class OpenCL::KernelStruct
{
public:
	bool              mbKernelAcquired;
	cl_int            mnError;
	cl_device_id      mnDeviceId;
	cl_command_queue  mpCommandQueue;
	cl_program        mpProgram;
	
	OpenCLULongMap            maLocalDomainSizeMap;	// Per kernel local domain size associative array
	OpenCLULongMap            maWorkGroupItemsMap;	// Per kernel work group items associative array
	OpenCLULongMap            maWorkDimMap;			// Per kernel work dimension associative array
	OpenCLKernelWorkGroupMap  maWorkGroupMap;		// Per kernel work group associative array
	OpenCLKernelMap           maKernelMap;			// Kernels associated array
	OpenCLKernelMapIterator   mpKernelMapIter;		// Kernel associative array iterator
};

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
//
// The core of the OpenCL execution model is defined by how the kernels 
// execute. When a kernel is submitted for execution by the host, an 
// index space is defined. An instance of the kernel executes for each 
// point in this index space. This kernel instance is called a work-item 
// and is identified by its point in the index space, which provides a 
// global ID for the work-item. Each work-item executes the same code but 
// the specific execution pathway through the code and the data operated 
// upon can vary per work-item.
//
// Work-items are organized into work-groups. The work-groups provide a 
// more coarse-grained decomposition of the index space.	Work-groups 
// are assigned a unique work-group ID with the same dimensionality as 
// the index space used for the work-items. Work-items are assigned a 
// unique local ID within a work-group so that a single work-item can 
// be uniquely identified by its global ID or by a combination of its 
// local ID and work-group ID. The work-items in a given work-group 
// execute concurrently on the processing elements of a single compute 
// unit.
//
//---------------------------------------------------------------------------
//
// For a complete discussion of OpenCL Kernel APIs refer to, 
//
// http://www.khronos.org/registry/cl/specs/opencl-1.0.33.pdf
//
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Utilities - Numerics

//---------------------------------------------------------------------------
//
// Determine if there is a remainder, then return the divided value rounded 
// up, else just divide - i.e., after integer divsion round-up.
//
//---------------------------------------------------------------------------

static inline size_t OpenCLCDiv(size_t n, size_t d) 
{
    return( ((n % d) != 0) ? (n / d + 1) : (n / d) );
} // OpenCLCDiv

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Utilities - Management

//---------------------------------------------------------------------------

static bool OpenCLKernelInsertIntoMap(const std::string &rKernelName,
									  OpenCL::KernelStruct *pSKernel)
{
	bool bKernelInsertedIntoMap = false;
	
	const char *pKernelName = rKernelName.c_str();
	
	cl_kernel pKernelMem = clCreateKernel(pSKernel->mpProgram, 
										  pKernelName, 
										  &pSKernel->mnError);
	
	bool bKernelCreated = ( pKernelMem != NULL ) && ( pSKernel->mnError == CL_SUCCESS );
	
	if( !bKernelCreated )
	{
		std::cerr << ">> ERROR: OpenCL Kernel - Failed to create a compute kernel!" << std::endl;
	} // if
	else 
	{
		// Insert the allocated kernel memory object into the associative array
		
		pSKernel->maKernelMap.insert(std::make_pair(rKernelName, pKernelMem));
		
		// Check to see if now you can find the kernel memory object
		
		pSKernel->mpKernelMapIter = pSKernel->maKernelMap.find(rKernelName);
		
		// If the end of the associative array was reached then the memory 
		// object was not inserted
		
		bKernelInsertedIntoMap = pSKernel->mpKernelMapIter != pSKernel->maKernelMap.end();
		
		if( !bKernelInsertedIntoMap )
		{
			std::cerr	<< ">> ERROR: OpenCL Kernel - Failed to insert the kernel \"" 
			<< rKernelName 
			<< "\" into the map!" 
			<< std::endl;
		} // if
	} // else
	
	return( bKernelCreated && bKernelInsertedIntoMap );
} // OpenCLKernelInsertIntoMap

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Utilities - Parameters

//---------------------------------------------------------------------------

static inline bool OpenCLKernelSetParameter(const cl_uint nParamIndex,
											const size_t nParamSize,
											const void *pParam,
											OpenCL::KernelStruct *pSKernel)
{
    pSKernel->mnError = clSetKernelArg(pSKernel->mpKernelMapIter->second,  
									   nParamIndex, 
									   nParamSize, 
									   pParam);
	
	bool bParamSet = pSKernel->mnError == CL_SUCCESS;
	
    if( !bParamSet )
    {
        std::cerr << ">> ERROR: OpenCL Kernel - Failed to set kernel arguments!" << std::endl;
    } // if
	
	return( bParamSet );
} // OpenCLKernelSetParameter

//---------------------------------------------------------------------------

static bool OpenCLKernelSetParameterWithBufferAlias(OpenCL::Buffer &rBuffer,
													OpenCL::KernelStruct *pSKernel)
{
	const cl_uint   nParamIndex = rBuffer.GetBufferIndex();
	const void     *pParam      = rBuffer.GetBuffer();
	
	return( OpenCLKernelSetParameter(nParamIndex,
									 kOpenCLBufferSize, 
									 &pParam,
									 pSKernel) );
} // OpenCLKernelSetParameterWithBufferAlias

//---------------------------------------------------------------------------

static bool OpenCLKernelSetParameterWithBufferRef(OpenCL::Buffer *pBuffer,
												  OpenCL::KernelStruct *pSKernel)
{
	bool bSetKernelParameter = false;
	
	if( pBuffer != NULL )
	{
		const cl_uint   nParamIndex = pBuffer->GetBufferIndex();
		const void     *pParam      = pBuffer->GetBuffer();
		
		bSetKernelParameter = OpenCLKernelSetParameter(nParamIndex,
													   kOpenCLBufferSize, 
													   &pParam,
													   pSKernel);
	} // if
	else 
	{
		std::cerr << ">> ERROR: OpenCL Kernel - Failed to bind to a NULL buffer object!" << std::endl;
	} // else
	
	return( bSetKernelParameter );
} // OpenCLKernelSetParameterWithBufferAlias

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Utilities - Execute

//---------------------------------------------------------------------------

static inline bool OpenCLKernelEnqueueNDRange(const std::string &rKernelName,
											  const size_t *pGlobalWorkOffset,
											  const size_t *pGlobalWorkSize,
											  const size_t *pLocalWorkSize,
											  OpenCL::KernelStruct *pSKernel)
{
	cl_uint nWorkDim = pSKernel->maWorkDimMap[rKernelName];
	
	pSKernel->mnError = clEnqueueNDRangeKernel(pSKernel->mpCommandQueue, 
											   pSKernel->mpKernelMapIter->second, 
											   nWorkDim, 
											   pGlobalWorkOffset, 
											   pGlobalWorkSize,
											   pLocalWorkSize, 
											   0, 
											   NULL, 
											   NULL);
	
	bool bEnqueued = pSKernel->mnError == CL_SUCCESS;
	
	if( !bEnqueued )
	{
		std::cerr << ">> ERROR: OpenCL Kernel - Failed to execute kernel!" << std::endl;
	} // if
	
	return( bEnqueued );
} // OpenCLKernelEnqueueNDRange

//---------------------------------------------------------------------------

static void OpenCLKernelComputeWorkGroupSize(const std::string &rKernelName,
											 const cl_uint nLocalDomainSize,
											 OpenCL::KernelStruct *pSKernel)
{
	size_t nLocalWidth  = 0;
	size_t nLocalHeight = 0;
	
	cl_uint nWorkGroupItems = pSKernel->maWorkGroupItemsMap[rKernelName];
	
	if( nWorkGroupItems > 0 )
	{
		nLocalWidth  = ( nLocalDomainSize > 1 ) ? ( nLocalDomainSize / nWorkGroupItems ) : nLocalDomainSize;
		nLocalHeight = nLocalDomainSize / nLocalWidth;
	} // if
	
	pSKernel->maLocalDomainSizeMap[rKernelName] = nLocalDomainSize;
	
	pSKernel->maWorkGroupMap[rKernelName].maLocalWorkSize.mnWidth  = nLocalWidth;
	pSKernel->maWorkGroupMap[rKernelName].maLocalWorkSize.mnHeight = nLocalHeight;
} // OpenCLKernelComputeWorkGroupSize

//---------------------------------------------------------------------------

static bool OpenCLKernelGetWorkGroupInfo(const std::string &rKernelName,
										 OpenCL::KernelStruct *pSKernel)
{
	cl_uint nLocalDomainSize = 0;
	
    pSKernel->mnError = clGetKernelWorkGroupInfo(pSKernel->mpKernelMapIter->second, 
												 pSKernel->mnDeviceId, 
												 CL_KERNEL_WORK_GROUP_SIZE, 
												 sizeof(size_t), 
												 &nLocalDomainSize,
												 NULL);
	
	bool bGotKernelWGI = pSKernel->mnError == CL_SUCCESS;
	
    if( !bGotKernelWGI )
    {
        std::cerr << ">> ERROR: OpenCL Kernel - Failed to retrieve kernel work group info!" << std::endl;
    } // if
	else
	{		
		OpenCLKernelComputeWorkGroupSize(rKernelName, 
										 nLocalDomainSize, 
										 pSKernel);
	} // else
	
	return( bGotKernelWGI );
} // OpenCLKernelGetWorkGroupInfo

//---------------------------------------------------------------------------
//
// Execute the kernel using the global work offset, global work size,
// and local work size.  If the input local work size was NULL, then
// determine the local domain size of the device.
//
//---------------------------------------------------------------------------

static bool OpenCLKernelExecute(const size_t *pGlobalWorkOffset,
								const size_t *pGlobalWorkSize,
								const size_t *pLocalWorkSize,
								OpenCL::KernelStruct *pSKernel)
{
	bool bKernelExeced = false;
	
	if( pSKernel->mbKernelAcquired )
	{
		const std::string aKernelName = pSKernel->mpKernelMapIter->first;
		
		if( pLocalWorkSize == NULL )
		{
			// Get the maximum work group size for executing the kernel on the device
			
			bKernelExeced = OpenCLKernelGetWorkGroupInfo(aKernelName, pSKernel);
			
			if( bKernelExeced )
			{
				bKernelExeced = OpenCLKernelEnqueueNDRange(aKernelName,
														   pGlobalWorkOffset,
														   pGlobalWorkSize,
														   &pSKernel->maLocalDomainSizeMap[aKernelName],
														   pSKernel);
			} // if
		} // if
		else 
		{
			bKernelExeced = OpenCLKernelEnqueueNDRange(aKernelName,
													   pGlobalWorkOffset,
													   pGlobalWorkSize,
													   pLocalWorkSize,
													   pSKernel);
		} // else
	} // if
	
	return( bKernelExeced );
} // OpenCLKernelExecute

//---------------------------------------------------------------------------
//
// Compute the local and global work sizes with width (e.g., image width), 
// and height (e.g., image height. Then execute the kernel using the newly
// computed values, and the global work offset.
//
//---------------------------------------------------------------------------

static bool OpenCLKernelEnqueue(const size_t *pGlobalWorkOffset,
								OpenCL::KernelStruct *pSKernel)
{
	bool bKernelExeced = false;
	
	if( pSKernel->mbKernelAcquired )
	{
		const std::string aKernelName = pSKernel->mpKernelMapIter->first;
		
		size_t aGlobalWorkSize[2] = { 0, 0 };
		size_t aLocalWorkSize[2]  = { 0, 0 };
		
		aLocalWorkSize[0] = pSKernel->maWorkGroupMap[aKernelName].maLocalWorkSize.mnWidth;
		aLocalWorkSize[1] = pSKernel->maWorkGroupMap[aKernelName].maLocalWorkSize.mnHeight;
		
		aGlobalWorkSize[0] = pSKernel->maWorkGroupMap[aKernelName].maGlobalWorkSize.mnWidth;
		aGlobalWorkSize[1] = pSKernel->maWorkGroupMap[aKernelName].maGlobalWorkSize.mnHeight;
		
		bKernelExeced = OpenCLKernelEnqueueNDRange(aKernelName,
												   pGlobalWorkOffset,
												   aGlobalWorkSize,
												   aLocalWorkSize,
												   pSKernel);
	} // if
	
	return( bKernelExeced );
} // OpenCLKernelEnqueue

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Utilities - Acquire

//---------------------------------------------------------------------------
//
// Acquire a kernel object.  If the kernel object was previously acquired,
// then return its pointer.
//
//---------------------------------------------------------------------------

static bool OpenCLKernelAcquire(const std::string &rKernelName,
								OpenCL::KernelStruct *pSKernel)
{
	pSKernel->mbKernelAcquired = false;
	
	if( rKernelName.empty() )
	{
		std::cerr << ">> ERROR: OpenCL Kernel - Invalid kernel name!" << std::endl;
	} // if
	else
	{
		OpenCLKernelMapIterator pKernelMapIterEnd = pSKernel->maKernelMap.end();
		
		pSKernel->mpKernelMapIter = pSKernel->maKernelMap.find(rKernelName);
		
		if( pSKernel->mpKernelMapIter == pKernelMapIterEnd )
		{
			pSKernel->mbKernelAcquired = OpenCLKernelInsertIntoMap(rKernelName, pSKernel);
		} // if
		else 
		{
			pSKernel->mbKernelAcquired = pSKernel->mpKernelMapIter != pKernelMapIterEnd;
		} // else
	} // if
	
	return( pSKernel->mbKernelAcquired );
} // OpenCLKernelAcquire

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Utilities - Work Groups

//---------------------------------------------------------------------------
//
// Compute the global work size.
//
//---------------------------------------------------------------------------

static inline size_t OpenCLKernelSetGlobalWorkSize(size_t nLen, size_t nSize) 
{
    return( OpenCLCDiv(nLen, nSize) * nSize );
} // OpenCLKernelSetGlobalWorkSize

//---------------------------------------------------------------------------
//
// Compute the global work size values from work group size array values.
//
//---------------------------------------------------------------------------

static bool OpenCLKernelSetGlobalWorkSizes(const std::string &rKernelName,
										   const size_t nWidth,
										   const size_t nHeight,
										   OpenCL::KernelStruct *pSKernel) 
{
	size_t nLocalWidth  = pSKernel->maWorkGroupMap[rKernelName].maLocalWorkSize.mnWidth;
	size_t nLocalHeight = pSKernel->maWorkGroupMap[rKernelName].maLocalWorkSize.mnHeight;
	
	size_t nGlobalWidth  = 0;
	size_t nGlobalHeight = 0;
	
	if( ( nLocalWidth > 0 ) && ( nLocalHeight > 0 ) )
	{
		nGlobalWidth  = OpenCLKernelSetGlobalWorkSize(nWidth, nLocalWidth);
		nGlobalHeight = OpenCLKernelSetGlobalWorkSize(nHeight, nLocalHeight);
		
		pSKernel->maWorkGroupMap[rKernelName].maGlobalWorkSize.mnWidth  = nGlobalWidth;
		pSKernel->maWorkGroupMap[rKernelName].maGlobalWorkSize.mnHeight = nGlobalHeight;
	} // if
	
	return( ( nGlobalWidth > 0 ) && ( nGlobalHeight > 0 ) );
} // OpenCLKernelSetGlobalWorkSizes

//---------------------------------------------------------------------------
//
// Compute the local and global work sizes with width (e.g., image width), 
// and height (e.g., image height. Then execute the kernel using the newly
// computed values, and the global work offset.
//
//---------------------------------------------------------------------------

static bool OpenCLKernelSetWorkGroupSize(const size_t nWidth,
										 const size_t nHeight,
										 OpenCL::KernelStruct *pSKernel)
{
	bool bSetWorkGroupSize = false;
	
	if( pSKernel->mbKernelAcquired )
	{
		size_t nDim = nWidth * nHeight;
		
		if( nDim > 0 )
		{
			const std::string aKernelName = pSKernel->mpKernelMapIter->first;
			
			pSKernel->maWorkDimMap[aKernelName] = 2;
			
			if( OpenCLKernelGetWorkGroupInfo(aKernelName, pSKernel) )
			{
				bSetWorkGroupSize = OpenCLKernelSetGlobalWorkSizes(aKernelName, 
																   nWidth, 
																   nHeight, 
																   pSKernel);
			} // if
		} // if
		else 
		{
			std::cerr	<< ">> ERROR: OpenCL Kernel - Failed to set work group sizes!" 
			<< std::endl
			<< "                          Invalid dimensions = [ " 
			<< nWidth 
			<< " x " 
			<< nHeight 
			<< " ]" 
			<< std::endl;
		} // else
	} // if
	
	return( bSetWorkGroupSize );
} // OpenCLKernelSetWorkGroupSize

//---------------------------------------------------------------------------
//
// Set the kernel's work group item count if and only if a kernel was
// previously acquired.
//
//---------------------------------------------------------------------------

static bool OpenCLKernelSetWorkGroupItems(const cl_uint nWorkGroupItems,
										  OpenCL::KernelStruct *pSKernel)
{
	bool bSetWorkGroupItems = false;
	
	if( pSKernel->mbKernelAcquired )
	{
		pSKernel->maWorkGroupItemsMap[pSKernel->mpKernelMapIter->first] = nWorkGroupItems;
		
		bSetWorkGroupItems = true;
	} // if
	
	return( bSetWorkGroupItems );
} // OpenCLKernelSetWorkGroupItems

//---------------------------------------------------------------------------
//
// Set the kernel's work dimension if and only if a kernel was previously 
// acquired.
//
//---------------------------------------------------------------------------

static bool OpenCLKernelSetWorkDimension(const cl_uint nWorkDim,
										 OpenCL::KernelStruct *pSKernel)
{
	bool bSetWorkDimension = false;
	
	if( pSKernel->mbKernelAcquired )
	{
		pSKernel->maWorkDimMap[pSKernel->mpKernelMapIter->first] = nWorkDim;
		
		bSetWorkDimension = true;
	} // if
	
	return( bSetWorkDimension );
} // OpenCLKernelSetWorkDimension

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Constructors

//---------------------------------------------------------------------------

static OpenCL::KernelStruct *OpenCLKernelKernelCreateWithProgramAlias( const OpenCL::Program &rProgram )
{
	OpenCL::KernelStruct *pSKernel = new OpenCL::KernelStruct;
	
	if( pSKernel != NULL )
	{
		pSKernel->mnDeviceId     = rProgram.GetDeviceId();
		pSKernel->mpCommandQueue = rProgram.GetCommandQueue();
		pSKernel->mpProgram      = rProgram.GetProgram();
	} // if
	
	return( pSKernel );
} // OpenCLKernelKernelCreateWithProgramAlias

//---------------------------------------------------------------------------

static OpenCL::KernelStruct *OpenCLKernelKernelCreateWithProgramRef( const OpenCL::Program *pProgram )
{
	OpenCL::KernelStruct *pSKernel = NULL;
	
	if( pProgram != NULL )
	{
		pSKernel = OpenCLKernelKernelCreateWithProgramAlias(*pProgram);
	} // if
	
	return( pSKernel );
} // OpenCLKernelKernelCreateWithProgramRef

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Destructor

//---------------------------------------------------------------------------
//
// Release the kernel object memory structure.
//
//---------------------------------------------------------------------------

static void OpenCLKernelRelease( OpenCL::KernelStruct *pSKernel )
{
	if( pSKernel != NULL )
	{
		OpenCLKernelMapIterator  pKernelMapPos;	
		OpenCLKernelMapIterator  pKernelMapPosBegin = pSKernel->maKernelMap.begin();
		OpenCLKernelMapIterator  pKernelMapPosEnd   = pSKernel->maKernelMap.end();	
		
		for(pKernelMapPos  = pKernelMapPosBegin; 
			pKernelMapPos != pKernelMapPosEnd; 
			++pKernelMapPos )
		{
			if( pKernelMapPos->second )
			{
				clReleaseKernel(pKernelMapPos->second);
			} // if
		} // for
		
		pSKernel->maKernelMap.clear();
		pSKernel->maWorkDimMap.clear();
		pSKernel->maWorkGroupMap.clear();
		pSKernel->maWorkGroupItemsMap.clear();
		pSKernel->maLocalDomainSizeMap.clear();
		
		delete pSKernel;
		
		pSKernel = NULL;
	} // if
} // OpenCLKernelRelease

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Copy Constructor

//---------------------------------------------------------------------------
//
// Clone kernels' local domain size associative array.
//
//---------------------------------------------------------------------------

static void OpenCLKernelCopyLocalDomainSizeMap(OpenCL::KernelStruct *pSKernelSrc,
											   OpenCL::KernelStruct *pSKernelDst) 
{
	OpenCLULongMapIterator  pSrcKernelLocalDomainSizeMapPos;	
	OpenCLULongMapIterator  pSrcKernelLocalDomainSizeMapPosBegin = pSKernelSrc->maLocalDomainSizeMap.begin();
	OpenCLULongMapIterator  pSrcKernelLocalDomainSizeMapPosEnd   = pSKernelSrc->maLocalDomainSizeMap.end();	
	
	for(pSrcKernelLocalDomainSizeMapPos  = pSrcKernelLocalDomainSizeMapPosBegin; 
		pSrcKernelLocalDomainSizeMapPos != pSrcKernelLocalDomainSizeMapPosEnd; 
		++pSrcKernelLocalDomainSizeMapPos )
	{
		pSKernelDst->maLocalDomainSizeMap.insert(std::make_pair(pSrcKernelLocalDomainSizeMapPos->first,
																pSrcKernelLocalDomainSizeMapPos->second));
	} // for
} // pSrcKernelLocalDomainSizeMapPos

//---------------------------------------------------------------------------
//
// Clone kernels' work group items associative array.
//
//---------------------------------------------------------------------------

static void OpenCLKernelCopyWorkGroupItemsMap(OpenCL::KernelStruct *pSKernelSrc,
											  OpenCL::KernelStruct *pSKernelDst) 
{
	OpenCLULongMapIterator  pSrcKernelWorkGroupItemsMapPos;	
	OpenCLULongMapIterator  pSrcKernelWorkGroupItemsMapPosBegin = pSKernelSrc->maWorkGroupItemsMap.begin();
	OpenCLULongMapIterator  pSrcKernelWorkGroupItemsMapPosEnd   = pSKernelSrc->maWorkGroupItemsMap.end();	
	
	for(pSrcKernelWorkGroupItemsMapPos  = pSrcKernelWorkGroupItemsMapPosBegin; 
		pSrcKernelWorkGroupItemsMapPos != pSrcKernelWorkGroupItemsMapPosEnd; 
		++pSrcKernelWorkGroupItemsMapPos )
	{
		pSKernelDst->maWorkGroupItemsMap.insert(std::make_pair(pSrcKernelWorkGroupItemsMapPos->first,
															   pSrcKernelWorkGroupItemsMapPos->second));
	} // for
} // OpenCLKernelCopyWorkGroupItemsMap

//---------------------------------------------------------------------------
//
// Clone kernels' work dimension associative array.
//
//---------------------------------------------------------------------------

static void OpenCLKernelCopyWorkGroupMap(OpenCL::KernelStruct *pSKernelSrc,
										 OpenCL::KernelStruct *pSKernelDst) 
{
	OpenCLKernelWorkGroupMapIterator  pSrcKernelWorkGroupMapPos;	
	OpenCLKernelWorkGroupMapIterator  pSrcKernelWorkGroupMapPosBegin = pSKernelSrc->maWorkGroupMap.begin();
	OpenCLKernelWorkGroupMapIterator  pSrcKernelWorkGroupMapPosEnd   = pSKernelSrc->maWorkGroupMap.end();	
	
	for(pSrcKernelWorkGroupMapPos  = pSrcKernelWorkGroupMapPosBegin; 
		pSrcKernelWorkGroupMapPos != pSrcKernelWorkGroupMapPosEnd; 
		++pSrcKernelWorkGroupMapPos )
	{
		pSKernelDst->maWorkGroupMap.insert(std::make_pair(pSrcKernelWorkGroupMapPos->first,
														  pSrcKernelWorkGroupMapPos->second));
	} // for
} // OpenCLKernelCopyWorkGroupMap

//---------------------------------------------------------------------------
//
// Clone kernels' work dimension associative array.
//
//---------------------------------------------------------------------------

static void OpenCLKernelCopyWorkDimMap(OpenCL::KernelStruct *pSKernelSrc,
									   OpenCL::KernelStruct *pSKernelDst) 
{
	OpenCLULongMapIterator  pSrcWorkDimMapPos;	
	OpenCLULongMapIterator  pSrcWorkDimMapPosBegin = pSKernelSrc->maWorkDimMap.begin();
	OpenCLULongMapIterator  pSrcWorkDimMapPosEnd   = pSKernelSrc->maWorkDimMap.end();	
	
	for(pSrcWorkDimMapPos  = pSrcWorkDimMapPosBegin; 
		pSrcWorkDimMapPos != pSrcWorkDimMapPosEnd; 
		++pSrcWorkDimMapPos )
	{
		pSKernelDst->maWorkDimMap.insert(std::make_pair(pSrcWorkDimMapPos->first,
														pSrcWorkDimMapPos->second));
	} // for
} // OpenCLKernelCopyWorkDimMap

//---------------------------------------------------------------------------
//
// Clone all kernels in the associative array.
//
//---------------------------------------------------------------------------

static void OpenCLKernelCopyMap(OpenCL::KernelStruct *pSKernelSrc,
								OpenCL::KernelStruct *pSKernelDst) 
{
	OpenCLKernelMapIterator  pSrcKernelMapPos;	
	OpenCLKernelMapIterator  pSrcKernelMapPosBegin = pSKernelSrc->maKernelMap.begin();
	OpenCLKernelMapIterator  pSrcKernelMapPosEnd   = pSKernelSrc->maKernelMap.end();	
	
	for(pSrcKernelMapPos  = pSrcKernelMapPosBegin; 
		pSrcKernelMapPos != pSrcKernelMapPosEnd; 
		++pSrcKernelMapPos )
	{
		OpenCLKernelAcquire(pSrcKernelMapPos->first, pSKernelDst);
	} // for
} // OpenCLKernelCopyMap

//---------------------------------------------------------------------------
//
// Clone a kernel attributes.
//
//---------------------------------------------------------------------------

static void OpenCLKernelCopyAttributes(OpenCL::KernelStruct *pSKernelSrc,
									   OpenCL::KernelStruct *pSKernelDst) 
{
	pSKernelDst->mnDeviceId      = pSKernelSrc->mnDeviceId;
	pSKernelDst->mpCommandQueue  = pSKernelSrc->mpCommandQueue;
	pSKernelDst->mpProgram       = pSKernelSrc->mpProgram;
	pSKernelDst->mpKernelMapIter = pSKernelSrc->mpKernelMapIter;
} // OpenCLKernelCopyAttributes

//---------------------------------------------------------------------------
//
// Clone a kernel structure.
//
//---------------------------------------------------------------------------

static OpenCL::KernelStruct *OpenCLKernelCopy(OpenCL::KernelStruct *pSKernelSrc) 
{
	OpenCL::KernelStruct *pSKernelDst = NULL;
	
	if( pSKernelSrc != NULL )
	{
		pSKernelDst = new OpenCL::KernelStruct;
		
		if( pSKernelDst != NULL )
		{
			OpenCLKernelCopyAttributes(pSKernelSrc, pSKernelDst);
			OpenCLKernelCopyWorkDimMap(pSKernelSrc, pSKernelDst);
			OpenCLKernelCopyWorkGroupMap(pSKernelSrc, pSKernelDst);
			OpenCLKernelCopyWorkGroupItemsMap(pSKernelSrc, pSKernelDst);
			OpenCLKernelCopyLocalDomainSizeMap(pSKernelSrc, pSKernelDst);
			OpenCLKernelCopyMap(pSKernelSrc, pSKernelDst);
		} // if
	} // if
	
	return( pSKernelDst );
} // OpenCLKernelCopy

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Constructors

//---------------------------------------------------------------------------
//
// Construct a kernel object from a program object alias.
//
//---------------------------------------------------------------------------

OpenCL::Kernel::Kernel( const OpenCL::Program &rProgram )
{
	mpSKernel = OpenCLKernelKernelCreateWithProgramAlias(rProgram);
} // Constructor

//---------------------------------------------------------------------------
//
// Construct a kernel object from a program object reference.
//
//---------------------------------------------------------------------------

OpenCL::Kernel::Kernel( const OpenCL::Program *pProgram )
{
	mpSKernel = OpenCLKernelKernelCreateWithProgramRef(pProgram);
} // Constructor

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Copy Constructor

//---------------------------------------------------------------------------
//
// Construct a deep copy of a kernel object from another. 
//
//---------------------------------------------------------------------------

OpenCL::Kernel::Kernel( const Kernel &rKernel ) 
{
	mpSKernel = OpenCLKernelCopy( rKernel.mpSKernel );
} // Copy Constructor

//---------------------------------------------------------------------------
//
// Construct a deep copy of a kernel object from another. 
//
//---------------------------------------------------------------------------

OpenCL::Kernel::Kernel(const Kernel *pSKernel) 
{
	if( pSKernel != NULL )
	{
		mpSKernel = OpenCLKernelCopy( pSKernel->mpSKernel );
	} // if
} // Copy Constructor

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Assignment Operator

//---------------------------------------------------------------------------
//
// Construct a deep copy of a kernel object from another using the 
// assignment operator.
//
//---------------------------------------------------------------------------

OpenCL::Kernel &OpenCL::Kernel::operator=(const Kernel &rKernel)
{
	if( ( this != &rKernel ) && ( rKernel.mpSKernel != NULL ) )
	{
		OpenCLKernelRelease( mpSKernel );
		
		mpSKernel = OpenCLKernelCopy( rKernel.mpSKernel );
	} // if
	
	return( *this );
} // Assignment Operator

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Destructor

//---------------------------------------------------------------------------
//
// Release the kernel object.
//
//---------------------------------------------------------------------------

OpenCL::Kernel::~Kernel()
{
	OpenCLKernelRelease( mpSKernel );
} // Destructor

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Accessors

//---------------------------------------------------------------------------

const cl_kernel OpenCL::Kernel::GetKernel(const std::string &rKernelName) const
{
	return( mpSKernel->maKernelMap[rKernelName] );
} // GetKernel

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Acquire

//---------------------------------------------------------------------------
//
// Acquire a named kernel from an OpenCL program.  One must call this
// method, before using any other utility and accessor methods that follow.
// The method sets the internal state, and the current kernel name, that'll
// be in use by all the utility and accessor methods that follow.
//
//---------------------------------------------------------------------------

bool OpenCL::Kernel::Acquire( const std::string &rKernelName )
{
	return( OpenCLKernelAcquire(rKernelName, mpSKernel) );
} // Acquire

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Setters

//---------------------------------------------------------------------------
//
// Set the kernel's work group item count.
//
//---------------------------------------------------------------------------

bool OpenCL::Kernel::SetWorkGroupItems(const cl_uint nWorkGroupItems)
{
	return( OpenCLKernelSetWorkGroupItems(nWorkGroupItems, mpSKernel) );
} // SetWorkGroupItems

//---------------------------------------------------------------------------
//
// Set the kernel's work dimension.
//
//---------------------------------------------------------------------------

bool OpenCL::Kernel::SetWorkDimension(const cl_uint nWorkDim)
{
	return( OpenCLKernelSetWorkDimension(nWorkDim, mpSKernel) );
} // SetWorkDimension

//---------------------------------------------------------------------------
//
// Set the kernel's work group size using a width and height.
//
//---------------------------------------------------------------------------

bool OpenCL::Kernel::SetWorkGroupSize(const size_t nWidth, 
									  const size_t nHeight)
{
	return( OpenCLKernelSetWorkGroupSize(nWidth,
										 nHeight,
										 mpSKernel) );
} // SetWorkGroupSize

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Utilities - Binding

//---------------------------------------------------------------------------
//
// Using a buffer object alias, bind a buffer object to this kernel, with
// its index and memory.
//
//---------------------------------------------------------------------------

bool OpenCL::Kernel::BindBuffer(Buffer &rBuffer)
{
	return( OpenCLKernelSetParameterWithBufferAlias(rBuffer, mpSKernel) );
} // BindBuffer

//---------------------------------------------------------------------------
//
// Using a buffer object reference, bind a buffer object to this kernel,
// with its index and memory.
//
//---------------------------------------------------------------------------

bool OpenCL::Kernel::BindBuffer(Buffer *pBuffer)
{
	return( OpenCLKernelSetParameterWithBufferRef(pBuffer, mpSKernel) );
} // BindBuffer

//---------------------------------------------------------------------------
//
// Bind a parameter to this kernel, using its index and size.
//
//---------------------------------------------------------------------------

bool OpenCL::Kernel::BindParameter(const cl_uint nParamIndex,
								   const size_t nParamSize)
{
	return( OpenCLKernelSetParameter(nParamIndex, 
									 nParamSize, 
									 NULL,
									 mpSKernel) );
} // BindParameter

//---------------------------------------------------------------------------
//
// Bind a parameter to this kernel; using its index, size, and memory 
// contents.
//
//---------------------------------------------------------------------------

bool OpenCL::Kernel::BindParameter(const cl_uint nParamIndex,
								   const size_t nParamSize,
								   const void *pParam)
{
	return( OpenCLKernelSetParameter(nParamIndex, 
									 nParamSize, 
									 pParam,
									 mpSKernel) );
} // BindParameter

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Utilities - Executing

//---------------------------------------------------------------------------
//
// For a detailed discussion on global and local work size refer to the
// OpenCL documentation:
//
// http://www.khronos.org/registry/cl/specs/opencl-1.0.33.pdf
//
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
//
// Excute an acquired kernel using a global work size.
//
//---------------------------------------------------------------------------

bool OpenCL::Kernel::Execute(const size_t *pGlobalWorkSize)
{
	return( OpenCLKernelExecute(NULL, 
								pGlobalWorkSize, 
								NULL,
								mpSKernel) );
} // Execute

//---------------------------------------------------------------------------
//
// Excute an acquired kernel using a global work offset and size.
//
//---------------------------------------------------------------------------

bool OpenCL::Kernel::Execute(const size_t *pGlobalWorkOffset,
							 const size_t *pGlobalWorkSize)
{
	return( OpenCLKernelExecute(pGlobalWorkOffset, 
								pGlobalWorkSize, 
								NULL,
								mpSKernel) );
} // Execute

//---------------------------------------------------------------------------
//
// Excute an acquired kernel using a global work offset and size, and the
// local work size.
//
//---------------------------------------------------------------------------

bool OpenCL::Kernel::Execute(const size_t *pGlobalWorkOffset,
							 const size_t *pGlobalWorkSize,
							 const size_t *pLocalWorkSize)
{
	return( OpenCLKernelExecute(pGlobalWorkOffset, 
								pGlobalWorkSize, 
								pLocalWorkSize,
								mpSKernel) );
} // Execute

//---------------------------------------------------------------------------
//
// Enqueue an acquired kernel with width and height (e.g., image width and
// height).
//
//---------------------------------------------------------------------------

bool OpenCL::Kernel::Enqueue()
{
	return( OpenCLKernelEnqueue(NULL, mpSKernel) );
} // Enqueue

//---------------------------------------------------------------------------
//
// Enqueue an acquired kernel with width (e.g., image width), height (e.g., 
// image height), and a global work offset.
//
//---------------------------------------------------------------------------

bool OpenCL::Kernel::Enqueue(const size_t *pGlobalWorkOffset)
{
	return( OpenCLKernelEnqueue(pGlobalWorkOffset, mpSKernel) );
} // Enqueue

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
