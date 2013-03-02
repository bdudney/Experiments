//---------------------------------------------------------------------------
//
//	File: OpenCLProgram.mm
//
//  Abstract: A utility class to build an OpenCL program
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
//  Copyright (c) 2009-2010 Apple Inc., All rights reserved.
//
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#import <iostream>

//---------------------------------------------------------------------------

#import <OpenGL/OpenGL.h>
#import <OpenCL/opencl.h>

//---------------------------------------------------------------------------

#import "OpenCLProgram.h"

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Data Structures

//---------------------------------------------------------------------------

class OpenCL::ProgramStruct
{
	public:
		bool                          mbUseCGLShareGroup;
		const size_t                 *mpProgramLengths;
		const char                   *mpProgramSource;
		cl_int                        mnError;
		cl_uint                       mnDeviceEntries;
		cl_uint                       mnDeviceCount;
		cl_uint                       mnProgramCount;
		cl_uint                       mnPlatformCount;
		cl_device_type                mnDeviceType;
		cl_platform_id                mnPlatformId;
		cl_device_id                  mnDeviceId;
		cl_context_properties        *mpContextProperties;
		cl_command_queue_properties   mnCmdQueueProperties;
		cl_context                    mpContext;
		cl_command_queue              mpCommandQueue;
		cl_program                    mpProgram;
};

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
//
// For a detailed discussion of OpenCL device, context, command queue, and 
// program APIs refer to the reference,
//
// http://www.khronos.org/registry/cl/specs/opencl-1.0.33.pdf
//
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Utilities - Platform

//---------------------------------------------------------------------------

static inline bool OpenCLPlatformGetIDs( OpenCL::ProgramStruct *pSProgram )
{
	pSProgram->mnError = clGetPlatformIDs(pSProgram->mnDeviceEntries,
										  &pSProgram->mnPlatformId,
										  &pSProgram->mnPlatformCount);
	
	bool bGetPlatformIDs = pSProgram->mnError == CL_SUCCESS;
	
	if( !bGetPlatformIDs )
	{
		std::cerr << ">> ERROR: OpenCL Program - Failed to get plaform attributes!" << std::endl;
	} // if
	
	return( bGetPlatformIDs );
} // OpenCLPlatformGetIDs

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Utilities - Device

//---------------------------------------------------------------------------

static inline bool OpenCLDeviceGetIDs( OpenCL::ProgramStruct *pSProgram )
{
	pSProgram->mnError = clGetDeviceIDs(pSProgram->mnPlatformId,
										pSProgram->mnDeviceType,
										pSProgram->mnDeviceEntries,
										&pSProgram->mnDeviceId,
										&pSProgram->mnDeviceCount);
	
	bool bGetDeviceIDs = pSProgram->mnError == CL_SUCCESS;
	
	if( !bGetDeviceIDs )
	{
		std::cerr << ">> ERROR: OpenCL Program - Failed to create a device group!" << std::endl;
	} // if
	
	return( bGetDeviceIDs );
} // OpenCLDeviceGetIDs

//---------------------------------------------------------------------------

static bool OpenCLDeviceGetInfo(const size_t  nDeviceIDsSize,
								cl_device_id  *pDeviceIDs,
								OpenCL::ProgramStruct *pSProgram )
{
	bool bDeviceFound = false;
	
	cl_uint         nDeviceIndex    = 0;
	cl_uint         nDeviceTypeSize = sizeof(cl_device_type);
	cl_uint         nDeviceCount    = nDeviceIDsSize / sizeof(cl_device_id);
	cl_device_type  nDeviceType     = 0;	
	
	while( !bDeviceFound && ( nDeviceIndex < nDeviceCount ) ) 
	{
		clGetDeviceInfo(pDeviceIDs[nDeviceIndex], 
						CL_DEVICE_TYPE, 
						nDeviceTypeSize, 
						&nDeviceType, 
						NULL);
		
		if( nDeviceType == pSProgram->mnDeviceType ) 
		{
			pSProgram->mnDeviceId = pDeviceIDs[nDeviceIndex];
			bDeviceFound = true;
		} // if
		
		++nDeviceIndex;
	} // while
	
	if( !bDeviceFound )
	{
		std::cerr << ">> ERROR: OpenCL Program - Failed to locate the compute device!" << std::endl;
	} // if
	
	return( bDeviceFound );
} // OpenCLDeviceGetInfo

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Utilities - Context

//---------------------------------------------------------------------------

static bool OpenCLContextPropertiesSetWithCGLSharedGroup(cl_context_properties *pCtxProperties)
{
	bool bSetContexProperties = false;
	
	CGLContextObj pCGLContext = CGLGetCurrentContext();
	
	if( pCGLContext != NULL )
	{
		CGLShareGroupObj pCGLShareGroup = CGLGetShareGroup(pCGLContext);
		
		if( pCGLShareGroup != NULL )
		{
			pCtxProperties[0] = CL_CONTEXT_PROPERTY_USE_CGL_SHAREGROUP_APPLE;
			pCtxProperties[1] = (cl_context_properties)pCGLShareGroup;
			pCtxProperties[2] = 0;
			
			bSetContexProperties = true;
		} // if
		else
		{
			std::cerr << ">> ERROR: OpenCL Program - Failed to get a CGL share group!" << std::endl;
		} // if
	} // if
	else
	{
		std::cerr << ">> ERROR: OpenCL Program - Failed to get the current CGL context!" << std::endl;
	} // if
	
	return( bSetContexProperties );
} // OpenCLContextPropertiesSetWithCGLSharedGroup

//---------------------------------------------------------------------------

static bool OpenCLContextCreateWithCGLSharedGroup( OpenCL::ProgramStruct *pSProgram )
{
	bool bCreatedContext = false;
	
	cl_context_properties properties[3];
	
	if( OpenCLContextPropertiesSetWithCGLSharedGroup(properties) )
	{
		pSProgram->mpContext = clCreateContext(properties, 
											   0, 
											   NULL, 
											   clLogMessagesToStdoutAPPLE, 
											   NULL, 
											   &pSProgram->mnError);
		
		bCreatedContext = ( pSProgram->mpContext != NULL ) && ( pSProgram->mnError == CL_SUCCESS );
		
		if( !bCreatedContext )
		{
			std::cerr << ">> ERROR: OpenCL Program - Failed to create a shared CGL group context!" << std::endl;
		} // if
	} // if
	
	return( bCreatedContext );
} // OpenCLContextCreateWithCGLSharedGroup

//---------------------------------------------------------------------------

static bool OpenCLContextCreateWithDefaults( OpenCL::ProgramStruct *pSProgram )
{
    pSProgram->mpContext = clCreateContext(pSProgram->mpContextProperties, 
										   pSProgram->mnDeviceEntries, 
										   &pSProgram->mnDeviceId, 
										   clLogMessagesToStdoutAPPLE, 
										   NULL, 
										   &pSProgram->mnError);
	
	bool bCreatedContext = ( pSProgram->mpContext != NULL ) && ( pSProgram->mnError == CL_SUCCESS );
	
    if( !bCreatedContext )
    {
		std::cerr << ">> ERROR: OpenCL Program - Failed to create a compute context!" << std::endl;
    } // if
	
	return( bCreatedContext );
} // OpenCLContextCreateWithDefaults

//---------------------------------------------------------------------------

static bool OpenCLContextAcquire( OpenCL::ProgramStruct *pSProgram )
{
	bool bNewContext = false;
	
	if( pSProgram->mbUseCGLShareGroup )
	{
		bNewContext = OpenCLContextCreateWithCGLSharedGroup(pSProgram);
	} // if
	else 
	{
		bNewContext = OpenCLContextCreateWithDefaults(pSProgram);
	} // else
	
	return( bNewContext );
} // OpenCLContextAcquire

//---------------------------------------------------------------------------

static bool OpenCLContextGetInfo( OpenCL::ProgramStruct *pSProgram )
{
	bool bDeviceFound = false;
	
	cl_device_id  aDeviceIDs[16];
	
	size_t nDeviceIDsSize;
	
	pSProgram->mnError = clGetContextInfo(pSProgram->mpContext, 
										  CL_CONTEXT_DEVICES, 
										  sizeof(aDeviceIDs), 
										  aDeviceIDs, 
										  &nDeviceIDsSize);
	
	bool bGotContextInfo = pSProgram->mnError == CL_SUCCESS;
	
	if( !bGotContextInfo  )
	{
		std::cerr << ">> ERROR: OpenCL Program - Failed to retrieve the compute devices for context!" << std::endl;
	} // if
	else
	{
		bDeviceFound = OpenCLDeviceGetInfo(nDeviceIDsSize, aDeviceIDs, pSProgram);
	} // if
	
	return( bGotContextInfo && bDeviceFound );
} // OpenCLContextGetInfo

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Utilities - Command Queue

//---------------------------------------------------------------------------

static bool OpenCLCommandQueueCreate( OpenCL::ProgramStruct *pSProgram )
{
    pSProgram->mpCommandQueue = clCreateCommandQueue(pSProgram->mpContext, 
													 pSProgram->mnDeviceId, 
													 pSProgram->mnCmdQueueProperties, 
													 &pSProgram->mnError);
	
	bool bCreatedCmdQueue = ( pSProgram->mpCommandQueue != NULL ) && ( pSProgram->mnError == CL_SUCCESS );
	
    if( !bCreatedCmdQueue )
    {
		std::cerr << ">> ERROR: OpenCL Program - Failed to create a command queue!" << std::endl;
    } // if
	
	return( bCreatedCmdQueue );
} // OpenCLCommandQueueCreate

//---------------------------------------------------------------------------

static bool OpenCLCommandQueueFlush(OpenCL::ProgramStruct *pSProgram)
{
	pSProgram->mnError = clFlush(pSProgram->mpCommandQueue);
	
	bool bFlushedCmdQueue = pSProgram->mnError == CL_SUCCESS;
	
    if( !bFlushedCmdQueue )
    {
		std::cerr << ">> ERROR: OpenCL Program - Failed to flush the command queue!" << std::endl;
    } // if
	
	return( bFlushedCmdQueue );
} // OpenCLCommandQueueFlush

//---------------------------------------------------------------------------

static bool OpenCLCommandQueueFinish(OpenCL::ProgramStruct *pSProgram)
{
	pSProgram->mnError = clFinish(pSProgram->mpCommandQueue);
	
	bool bFinishCmdQueue = pSProgram->mnError == CL_SUCCESS;
	
    if( !bFinishCmdQueue )
    {
		std::cerr << ">> ERROR: OpenCL Program - Failed to finish the command queue!" << std::endl;
    } // if
	
	return( bFinishCmdQueue );
} // OpenCLCommandQueueFinish

//---------------------------------------------------------------------------

static bool OpenCLCommandQueueBarrier( OpenCL::ProgramStruct *pSProgram )
{
    pSProgram->mnError = clEnqueueBarrier(pSProgram->mpCommandQueue);
	
	bool bSetBarrier = pSProgram->mnError == CL_SUCCESS;
	
    if( !bSetBarrier )
    {
		std::cerr << ">> ERROR: OpenCL Program - Failed to enqueue barrier for the device!" << std::endl;
    }  // if 
	
    return( bSetBarrier );
} // OpenCLCommandQueueBarrier

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Utilities - Program

//---------------------------------------------------------------------------

static bool OpenCLProgramCreateWithSource( OpenCL::ProgramStruct *pSProgram )
{
    pSProgram->mpProgram = clCreateProgramWithSource(pSProgram->mpContext, 
													 pSProgram->mnProgramCount, 
													 (const char **)&pSProgram->mpProgramSource, 
													 pSProgram->mpProgramLengths, 
													 &pSProgram->mnError);
	
	bool bCreatedProgram = ( pSProgram->mpProgram != NULL ) && ( pSProgram->mnError == CL_SUCCESS );
	
    if( !bCreatedProgram )
    {
        std::cerr << ">> ERROR: OpenCL Program - Failed to create a compute program!" << std::endl;
    } // if
	
	return( bCreatedProgram );
} // OpenCLProgramCreateWithSource

//---------------------------------------------------------------------------

static inline void OpenCLProgramBuildLogInvalidProgram()
{
	std::cerr	<< ">> ERROR: OpenCL Program - Program is not a valid program object!" 
				<< std::endl;
} // OpenCLProgramBuildLogInvalidProgram

//---------------------------------------------------------------------------

static inline void OpenCLProgramBuildLogInvalidValue()
{
	std::cerr	<< ">> ERROR: OpenCL Program - Device list is NULL and number of devices is greater than zero," 
				<< std::endl
				<< "                           or if device list is not NULL and number of devices is zero!" 
				<< std::endl;
} // OpenCLProgramBuildLogInvalidValue

//---------------------------------------------------------------------------

static inline void OpenCLProgramBuildLogInvalidDevice()
{
	std::cerr	<< ">> ERROR: OpenCL Program - Devices listed in device list are not in the list of" 
				<< std::endl
				<< "                           devices associated with program!" 
				<< std::endl;
} // OpenCLProgramBuildLogInvalidDevice

//---------------------------------------------------------------------------

static inline void OpenCLProgramBuildLogInvalidBinary()
{
	std::cerr	<< ">> ERROR: OpenCL Program - Program is created with clCreateWithProgramBinary and devices" 
				<< std::endl
				<< "                           listed in device list do not have a valid program binary loaded!" 
				<< std::endl;
} // OpenCLProgramBuildLogInvalidBinary

//---------------------------------------------------------------------------

static inline void OpenCLProgramBuildLogInvalidOptions()
{
	std::cerr	<< ">> ERROR: OpenCL Program - Build options specified by options are invalid!" 
				<< std::endl;
} // OpenCLProgramBuildLogInvalidOptions

//---------------------------------------------------------------------------

static inline void OpenCLProgramBuildLogInvalidOperation()
{
	std::cerr	<< ">> ERROR: OpenCL Program - Build of a program executable for any of thew devices listed by a" 
				<< std::endl
				<< "                           previous call to clBuildProgram for program has not completed, or" 
				<< std::endl
				<< "                           if there kernel objects attached to program!" 
				<< std::endl;
} // OpenCLProgramBuildLogInvalidOperation

//---------------------------------------------------------------------------

static inline void OpenCLProgramBuildLogOutOfHostMemory()
{
	std::cerr	<< ">> ERROR: OpenCL Program - Failed to allocated resources required by the OpenCL" 
				<< std::endl
				<< "                           implementation on the host!" 
				<< std::endl;
} // OpenCLProgramBuildLogOutOfHostMemory

//---------------------------------------------------------------------------

static inline void OpenCLProgramBuildLogFailure()
{
	std::cerr	<< ">> ERROR: OpenCL Program - Failed to build a program executable!" 
				<< std::endl;
} // OpenCLProgramBuildLogFailure

//---------------------------------------------------------------------------

static void OpenCLProgramBuildLogError( OpenCL::ProgramStruct *pSProgram )
{
	switch( pSProgram->mnError ) 
	{
		case CL_INVALID_PROGRAM:
			OpenCLProgramBuildLogInvalidProgram();
			break;
			
		case CL_INVALID_VALUE:
			OpenCLProgramBuildLogInvalidValue();
			break;
			
		case CL_INVALID_DEVICE:
			OpenCLProgramBuildLogInvalidDevice();
			break;
			
		case CL_INVALID_BINARY:
			OpenCLProgramBuildLogInvalidBinary();
			break;
			
		case CL_INVALID_BUILD_OPTIONS:
			OpenCLProgramBuildLogInvalidOptions();
			break;
			
		case CL_INVALID_OPERATION:
			OpenCLProgramBuildLogInvalidOperation();
			break;
			
		case CL_OUT_OF_HOST_MEMORY:
			OpenCLProgramBuildLogOutOfHostMemory();
			break;
			
		case CL_BUILD_PROGRAM_FAILURE:
			OpenCLProgramBuildLogFailure();
			break;
			
		default:
			break;
	} // switch
} // OpenCLProgramBuildLogError

//---------------------------------------------------------------------------

static inline bool OpenCLProgramBuildSuccess(OpenCL::ProgramStruct *pSProgram)
{
	bool bProgramBuilt = pSProgram->mnError == CL_SUCCESS;
	
	if( !bProgramBuilt )
	{
		std::cerr	<< ">> ERROR[" 
					<< pSProgram->mnError 
					<< "]: OpenCL Program - Program build unsuccessful!" 
					<< std::endl;
	} // if
	
	return( bProgramBuilt );
} // OpenCLProgramBuildSuccess

//---------------------------------------------------------------------------

static bool OpenCLProgramBuild( OpenCL::ProgramStruct *pSProgram )
{
    pSProgram->mnError = clBuildProgram(pSProgram->mpProgram, 
										0, 
										NULL, 
										NULL, 
										NULL, 
										NULL);
	
	bool bBuildSuccess = OpenCLProgramBuildSuccess(pSProgram);
	
	if( !bBuildSuccess )
	{
		OpenCLProgramBuildLogError(pSProgram);
	} // if
	
	return( bBuildSuccess );
} // OpenCLProgramBuild

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Utilities - Acquire

//---------------------------------------------------------------------------
//
// Create an OpenCL program by first getting device IDs, command queue, and 
// context.  The create an OpenCL program from a source file.
//
//---------------------------------------------------------------------------

static bool OpenCLProgramAcquire(OpenCL::ProgramStruct *pSProgram)
{
	bool bFlagIsValid = false;
	
	if( pSProgram->mpProgramSource != NULL )
	{
		if( OpenCLPlatformGetIDs(pSProgram) )
		{
			if( OpenCLDeviceGetIDs(pSProgram) )
			{
				if( OpenCLContextAcquire(pSProgram) )
				{
					if( OpenCLContextGetInfo(pSProgram) )
					{
						if( OpenCLCommandQueueCreate(pSProgram) )
						{
							if( OpenCLProgramCreateWithSource(pSProgram) )
							{
								bFlagIsValid = OpenCLProgramBuild(pSProgram);
							} // if
						} // if
					} // if
				} // if
			} // if
		} // if
	} // else
	else
	{
		std::cerr << ">> ERROR: OpenCL Program - Failed to open the file containing progam's source!" << std::endl;
	} // else
	
	return( bFlagIsValid );
} // OpenCLProgramAcquire

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Constructor

//---------------------------------------------------------------------------

static OpenCL::ProgramStruct *OpenCLProgramCreateWithFileAlias( const OpenCL::File &rFile )
{
	OpenCL::ProgramStruct *pSProgram = new OpenCL::ProgramStruct;
	
	if( pSProgram != NULL )
	{
		pSProgram->mbUseCGLShareGroup   = false;
		pSProgram->mnDeviceType         = CL_DEVICE_TYPE_GPU;
		pSProgram->mnDeviceEntries      = 1;
		pSProgram->mnDeviceCount        = 1;
		pSProgram->mnPlatformCount      = 1;
		pSProgram->mnProgramCount       = 1;
		pSProgram->mnCmdQueueProperties = 0;
		pSProgram->mnDeviceId           = NULL;
		pSProgram->mnPlatformId         = NULL;
		pSProgram->mpContextProperties  = NULL;
		pSProgram->mpContext            = NULL;
		pSProgram->mpCommandQueue       = NULL;
		pSProgram->mpProgram            = NULL;
		pSProgram->mpProgramLengths     = NULL;
		pSProgram->mpProgramSource      = rFile.GetContents();
	} // if
	
	return( pSProgram );
} // OpenCLProgramCreateWithFileAlias

//---------------------------------------------------------------------------

static OpenCL::ProgramStruct *OpenCLProgramCreateWithFileRef( const OpenCL::File *pFile )
{
	OpenCL::ProgramStruct *pSProgram = NULL;
	
	if( pFile != NULL )
	{
		pSProgram = OpenCLProgramCreateWithFileAlias(*pFile);
	} // if
	
	return( pSProgram );
} // OpenCLProgramCreateWithFileRef

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Destructor

//---------------------------------------------------------------------------
//
// Release the OpenCL program, command queue, and context; along with the
// program object.
//
//---------------------------------------------------------------------------

static void OpenCLProgramRelease( OpenCL::ProgramStruct *pSProgram )
{
	if( pSProgram != NULL )
	{
		OpenCLCommandQueueFinish(pSProgram);
		
		if( pSProgram->mpProgram != NULL )
		{
			clReleaseProgram(pSProgram->mpProgram);
		} // if
		
		if( pSProgram->mpCommandQueue != NULL )
		{
			clReleaseCommandQueue(pSProgram->mpCommandQueue);
		} // if
		
		if( pSProgram->mpContext != NULL )
		{
			clReleaseContext(pSProgram->mpContext);
		} // if
		
		delete pSProgram;
	} // if
} // OpenCLProgramRelease

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Copy Constructor

//---------------------------------------------------------------------------

static OpenCL::ProgramStruct *OpenCLProgramCopy(const OpenCL::ProgramStruct * const pSProgramSrc, 
												const OpenCL::File &rFile )
{
	OpenCL::ProgramStruct *pSProgramDst = NULL;
	
	if( pSProgramSrc != NULL )
	{
		pSProgramDst = new OpenCL::ProgramStruct;
		
		if( pSProgramDst != NULL )
		{
			pSProgramDst->mbUseCGLShareGroup   = pSProgramSrc->mbUseCGLShareGroup;
			pSProgramDst->mnDeviceType         = pSProgramSrc->mnDeviceType;
			pSProgramDst->mnDeviceEntries      = pSProgramSrc->mnDeviceEntries;
			pSProgramDst->mnDeviceId           = pSProgramSrc->mnDeviceId;
			pSProgramDst->mnDeviceCount        = pSProgramSrc->mnDeviceCount;
			pSProgramDst->mnPlatformId         = pSProgramSrc->mnPlatformId;
			pSProgramDst->mnPlatformCount      = pSProgramSrc->mnPlatformCount;
			pSProgramDst->mnProgramCount       = pSProgramSrc->mnProgramCount;
			pSProgramDst->mnCmdQueueProperties = pSProgramSrc->mnCmdQueueProperties;
			pSProgramDst->mpContextProperties  = NULL;
			pSProgramDst->mpContext            = NULL;
			pSProgramDst->mpCommandQueue       = NULL;
			pSProgramDst->mpProgram            = NULL;
			pSProgramDst->mpProgramLengths     = NULL;
			pSProgramDst->mpProgramSource      = rFile.GetContents();
			
			OpenCLProgramAcquire(pSProgramDst);
		} // if
	} // if
	
	return( pSProgramDst );
} // OpenCLProgramCopy

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Constructor

//---------------------------------------------------------------------------
//
// Construct a program object from a program source file.
//
// After instantiating a program object, for now and if you're running on 
// non-NVidia GPUs (e.g. ATI), use the public method 
//
//		SetDeviceType( const cl_device_type nDeviceType ) 
//
// with the device type CL_DEVICE_TYPE_CPU.
//
//---------------------------------------------------------------------------

OpenCL::Program::Program( const std::string &rFileName ) : OpenCL::File( rFileName )
{
	mpSProgram = OpenCLProgramCreateWithFileAlias(*this);
} // Constructor

//---------------------------------------------------------------------------

OpenCL::Program::Program( const std::string *pFileName ) : OpenCL::File( pFileName )
{
	mpSProgram = OpenCLProgramCreateWithFileRef(this);
} // Constructor

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Copy Constructor

//---------------------------------------------------------------------------
//
// Construct a deep copy of a program object from another. 
//
//---------------------------------------------------------------------------

OpenCL::Program::Program( const Program &rProgram ) : OpenCL::File(rProgram)
{
	mpSProgram = OpenCLProgramCopy( rProgram.mpSProgram, *this );
} // Copy Constructor

//---------------------------------------------------------------------------

OpenCL::Program::Program( const Program *pSProgram ) : OpenCL::File(pSProgram)
{
	if( pSProgram != NULL )
	{
		mpSProgram = OpenCLProgramCopy( pSProgram->mpSProgram, *this );
	} // if
} // Copy Constructor

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Assignment Operator

//---------------------------------------------------------------------------
//
// Construct a deep copy of a program object from another using the 
// assignment operator.
//
//---------------------------------------------------------------------------

OpenCL::Program &OpenCL::Program::operator=(const OpenCL::Program &rProgram)
{
	if( ( this != &rProgram ) && ( rProgram.mpSProgram != NULL ) )
	{
		OpenCLProgramRelease( mpSProgram );
		
		mpSProgram = OpenCLProgramCopy( rProgram.mpSProgram, *this );
	} // if
	
	return( *this );
} // Assignment Operator

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Destructor

//---------------------------------------------------------------------------
//
// Release the program object.
//
//---------------------------------------------------------------------------

OpenCL::Program::~Program()
{
	OpenCLProgramRelease( mpSProgram );
} // Destructor

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Setters

//---------------------------------------------------------------------------
//
// For a detailed discussion of these various attributes refer to,
//
// http://www.khronos.org/registry/cl/specs/opencl-1.0.33.pdf
//
//---------------------------------------------------------------------------

void OpenCL::Program::SetDeviceType( const cl_device_type nDeviceType )
{
	mpSProgram->mnDeviceType = nDeviceType;
} // SetDeviceType

//---------------------------------------------------------------------------

void OpenCL::Program::SetDeviceEntries( const cl_uint nEntries )
{
	mpSProgram->mnDeviceEntries = nEntries;
} // SetDeviceEntries

//---------------------------------------------------------------------------

void OpenCL::Program::SetContextPropertyWithCGLShareGroup()
{
	mpSProgram->mbUseCGLShareGroup = true;
} // SetContextPropertyWithCGLShareGroup

//---------------------------------------------------------------------------

void OpenCL::Program::SetContextProperties( cl_context_properties *pContextProperties )
{
	mpSProgram->mpContextProperties = pContextProperties;
} // SetContextProperties

//---------------------------------------------------------------------------

void OpenCL::Program::SetCommandQueueProperties( const cl_command_queue_properties nCmdQueueProperties )
{
	mpSProgram->mnCmdQueueProperties = nCmdQueueProperties;
} // SetCommandQueueProperties

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Getters

//---------------------------------------------------------------------------

const cl_device_id OpenCL::Program::GetDeviceId() const
{
	return(mpSProgram->mnDeviceId);
} // GetDeviceId

//---------------------------------------------------------------------------

const cl_program OpenCL::Program::GetProgram() const
{
	return(mpSProgram->mpProgram);
} // GetProgram

//---------------------------------------------------------------------------

const cl_context OpenCL::Program::GetContext() const
{
	return(mpSProgram->mpContext);
} // GetContext

//---------------------------------------------------------------------------

const cl_command_queue OpenCL::Program::GetCommandQueue() const
{
	return(mpSProgram->mpCommandQueue);
} // GetCommandQueue

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Utilities

//---------------------------------------------------------------------------
//
// After the program attributes have been set, build a program.
//
//---------------------------------------------------------------------------

bool OpenCL::Program::Acquire()
{
    return( OpenCLProgramAcquire(mpSProgram) );
} // Acquire

//---------------------------------------------------------------------------
//
// Issues all previously queued commands in the command queue to the device.
//
//---------------------------------------------------------------------------

bool OpenCL::Program::Flush()
{
    return( OpenCLCommandQueueFlush(mpSProgram) );
} // Flush

//---------------------------------------------------------------------------
//
// Blocks until all previously queued commands in the command queue are 
// issued to the device and have completed.
//
//---------------------------------------------------------------------------

bool OpenCL::Program::Finish()
{
    return( OpenCLCommandQueueFinish(mpSProgram) );
} // Finish

//---------------------------------------------------------------------------
//
// Barrier is a synchronization point that ensures that all queued  
// commands in a particular command queue have finished execution   
// before the next batch of commands can begin execution.
//
//---------------------------------------------------------------------------

bool OpenCL::Program::Barrier()
{
    return( OpenCLCommandQueueBarrier(mpSProgram) );
} // Barrier

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
