//---------------------------------------------------------------------------
//
//	File: Trajectory.cpp
//
//  Abstract: A class to compute trajectories using an OpenCL kernel
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

#ifndef _OPENCL_CPU_BOUND_
	#define _OPENCL_CPU_BOUND_ 1
#endif

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#import <iostream>

//---------------------------------------------------------------------------

#import "OpenCLKit.h"
#import "Trajectory.h"

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Constants

//---------------------------------------------------------------------------

static const cl_int  kFParamCount = 4;
static const cl_int  kBufferCount = 5;
static const cl_int  kFloatSize   = sizeof(cl_float);

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Data Structures

//---------------------------------------------------------------------------

class TrajectoryStruct
{
	public:
		size_t           mnBufferSize;
		size_t           mnBufferCount;
		size_t           mnGlobalWorkSize;
		cl_float         mnTimeMax;
		cl_float         maKFParam[kFParamCount];
		cl_float        *mpKResult[kBufferCount];
		OpenCL::Buffer  *mpKBuffer[kBufferCount];
		OpenCL::Kernel  *mpKernel;
};

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Utilities

//---------------------------------------------------------------------------
//
// Create buffer objects and then acquire buffer memories from OpenCL.
//
//---------------------------------------------------------------------------

static bool TrajectoryBuffersCreate(OpenCL::Program *pProgram,
									TrajectoryStruct *pSTrajectory)
{
	bool bBuffersCreated = true;
	bool bBufferAcquired = false;
	
	size_t nBufferIndex = 0;
	
	// Compute the expected buffer size.
	
	pSTrajectory->mnBufferCount = pSTrajectory->mnTimeMax / pSTrajectory->maKFParam[1];
	pSTrajectory->mnBufferSize  = pSTrajectory->mnBufferCount * kFloatSize;
	
	// Acquire the memory buffers for the kernels
	//
	// NOTE: On a successful return if the expected buffer size was not POT,
	//       a POT buffer size will be acquired.
	
	while( bBuffersCreated  && ( nBufferIndex < kBufferCount ) )  
	{
		pSTrajectory->mpKBuffer[nBufferIndex] = new OpenCL::Buffer(pProgram);
		
		bBuffersCreated = pSTrajectory->mpKBuffer[nBufferIndex] != NULL;
		
		if( bBuffersCreated )
		{
			bBufferAcquired = pSTrajectory->mpKBuffer[nBufferIndex]->Acquire(nBufferIndex,
																			 pSTrajectory->mnBufferSize);
			
			bBuffersCreated = bBuffersCreated && bBufferAcquired;
		} // if
		
		++nBufferIndex;
	} // while
	
	return( bBuffersCreated );
} // TrajectoryBuffersCreate

//---------------------------------------------------------------------------
//
// Create arrays for reading back the compute results from the kernel.
//
//---------------------------------------------------------------------------

static bool TrajectoryArraysCreate(TrajectoryStruct *pSTrajectory)
{
	bool bArrayCreated = true;
	
	size_t nArrayIndex = 0;
	size_t nArrayCount = pSTrajectory->mnBufferCount;
	
	while( bArrayCreated  && ( nArrayIndex < kBufferCount ) )  
	{
		pSTrajectory->mpKResult[nArrayIndex] = new float[nArrayCount];
		
		bArrayCreated = pSTrajectory->mpKResult[nArrayIndex] != NULL;
		
		if( bArrayCreated )
		{
			std::memset(pSTrajectory->mpKResult[nArrayIndex], 0, pSTrajectory->mnBufferSize);		
		} // if
		
		++nArrayIndex;
	} // while
	
	return( bArrayCreated );
} // TrajectoryArraysCreate

//---------------------------------------------------------------------------
//
// Instantiate an OpenCL kernel object from a program object.
//
//---------------------------------------------------------------------------

static inline bool TrajectoryKernelsCreate(OpenCL::Program *pProgram,
										   TrajectoryStruct *pSTrajectory)
{
	pSTrajectory->mpKernel = new OpenCL::Kernel(pProgram);

	return( pSTrajectory->mpKernel != NULL );
} // TrajectoryKernelsCreate

//---------------------------------------------------------------------------
//
// Set the global dimensions for the execution
//
//---------------------------------------------------------------------------

static inline void TrajectorySetGlobalWorkSize(TrajectoryStruct *pSTrajectory)
{
	// Get the actual buffer size, which if it wasn't POT, now it is

	size_t nBufferSize = pSTrajectory->mpKBuffer[0]->GetBufferSize();

	// Compute the actual number of elements based on POT buffer size

	size_t nBufferCount = nBufferSize / kFloatSize;
	
	// Set the global work size
	
	pSTrajectory->mnGlobalWorkSize = nBufferCount;
} // TrajectorySetGlobalWorkSize

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Constructor

//---------------------------------------------------------------------------
//
// Create an opaque trajectory data object by,
//
// (1) acquiring a program from OpenCL,
// (2) creating a kernel object, 
// (3) acquiring a kernel from OpenCL,
// (4) creating buffer objects, 
// (5) acquiring buffer memories from OpenCL,
// (6) creating arrays for readback,
// (7) setting global dimensions for the execution.
//
//---------------------------------------------------------------------------

static TrajectoryStruct *TrajectoryCreate(OpenCL::Program *pProgram, 
										  const float nTimeMax, 
										  const float nTimeDelta)
{
	TrajectoryStruct *pSTrajectory = new TrajectoryStruct;
	
	if( pSTrajectory != NULL )
	{
		// Maximum length of time for the simulation
		
		pSTrajectory->mnTimeMax = nTimeMax;
		
		// Initialize parameters for this trajectory
		
		pSTrajectory->maKFParam[0] = 0.0f;
		pSTrajectory->maKFParam[1] = nTimeDelta;
		pSTrajectory->maKFParam[2] = 0.0f;
		pSTrajectory->maKFParam[3] = 0.0f;
		
		#if _OPENCL_CPU_BOUND_
			// On ATI you need to do this for now.
			
			pProgram->SetDeviceType( CL_DEVICE_TYPE_CPU );
		#endif
		
		// Acquire an OpenCL program from an instantiated program object
		
		if( pProgram->Acquire() )
		{
			TrajectoryKernelsCreate(pProgram, pSTrajectory);
			TrajectoryBuffersCreate(pProgram, pSTrajectory);
			TrajectoryArraysCreate(pSTrajectory);
			TrajectorySetGlobalWorkSize(pSTrajectory);
		} // if
	} // if
	
	return( pSTrajectory );
} // TrajectoryCreate

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Destructor

//---------------------------------------------------------------------------
//
// Release trajectory data object; along with its kernels, buffers, and
// arrays.
//
//---------------------------------------------------------------------------

static bool TrajectoryRelease(TrajectoryStruct *pSTrajectory)
{
	if( pSTrajectory != NULL )
	{
		size_t i;
		
		for( i = 0; i < kBufferCount; ++i )
		{
			if( pSTrajectory->mpKResult[i] != NULL ) 
			{
				delete [] pSTrajectory->mpKResult[i];
			} // if
			
			if( pSTrajectory->mpKBuffer[i] != NULL ) 
			{
				delete pSTrajectory->mpKBuffer[i];
			} // if
		} // for
		
		if( pSTrajectory->mpKernel != NULL ) 
		{
			delete pSTrajectory->mpKernel;
		} // if
		
		delete pSTrajectory;
	} // if
} // TrajectoryRelease

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Buffers

//---------------------------------------------------------------------------
//
// Bind the buffers to this kernel
//
//---------------------------------------------------------------------------

static bool TrajectoryBindBuffers(TrajectoryStruct *pSTrajectory)
{
	bool bBuffersBound = true;
	
	size_t nBufferIndex = 0;
	
	while( bBuffersBound && ( nBufferIndex < kBufferCount ) )
	{
		bBuffersBound = bBuffersBound && pSTrajectory->mpKernel->BindBuffer( pSTrajectory->mpKBuffer[nBufferIndex] );
		
		++nBufferIndex;
	} // for
	
	return( bBuffersBound );
} // TrajectoryBindBuffers

//---------------------------------------------------------------------------
//
// Bind the constant float parameters to this kernel
//
//---------------------------------------------------------------------------

static bool TrajectoryBindParameters(TrajectoryStruct *pSTrajectory)
{
	bool bParametersBound = true;
	
	size_t nParamIndex = 0;
	
	while( bParametersBound && ( nParamIndex < kFParamCount ) )
	{
		bParametersBound = bParametersBound && pSTrajectory->mpKernel->BindParameter(nParamIndex+5, 
																					 kFloatSize, 
																					 &pSTrajectory->maKFParam[nParamIndex]);
		
		++nParamIndex;
	} // while
	
	return( bParametersBound );
} // TrajectoryBindParameters

//---------------------------------------------------------------------------
//
// Read back the results that were computed on the device
//
//---------------------------------------------------------------------------

static bool TrajectoryReadBuffers(TrajectoryStruct *pSTrajectory)
{
	bool bReadBuffers = true;
	
	size_t nBufferIndex = 0;
	
	while( bReadBuffers && ( nBufferIndex < kBufferCount ) )
	{
		bReadBuffers = bReadBuffers  && pSTrajectory->mpKBuffer[nBufferIndex]->Read(pSTrajectory->mnBufferSize,
																					pSTrajectory->mpKResult[nBufferIndex]);
		
		++nBufferIndex;
	} // while
	
	return( bReadBuffers );
} // TrajectoryReadBuffers

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Print

//---------------------------------------------------------------------------
//
// Print the results to the standard output device.
//
//---------------------------------------------------------------------------

static void TrajectoryLog(TrajectoryStruct *pSTrajectory)
{
	size_t  i;
	float   t = 0.0f;
	
	std::cout << ">> BEGIN" << std::endl;

    for( i = 0; i < pSTrajectory->mnBufferCount; ++i )
    {
		t = i * pSTrajectory->maKFParam[1];
		
        std::cout << ">>      Time: t = " << t << std::endl;
        std::cout << "    Position: ( " << pSTrajectory->mpKResult[0][i] << ", " << pSTrajectory->mpKResult[1][i] << " )" << std::endl;
		std::cout << "    Velocity: ( " << pSTrajectory->mpKResult[2][i] << ", " << pSTrajectory->mpKResult[3][i] << " )" << std::endl;
        std::cout << "       speed: || v(t) || = " << pSTrajectory->mpKResult[4][i] << std::endl;
	} // for

	std::cout << ">> END" << std::endl;
} // TrajectoryLog

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Acquire

//---------------------------------------------------------------------------
//
// Set kernel's work dimension, acquire the kernel, and bind buffers to
// this kernel.
//
//---------------------------------------------------------------------------

static bool TrajectoryAcquire(const std::string &rkernelName,
							  TrajectoryStruct *pSTrajectory)
{
	bool bFlagIsValid = false;
	
	// Get a compute kernel from OpenCL
	
	bFlagIsValid = pSTrajectory->mpKernel->Acquire(rkernelName);
	
	// Set the work dimension of an OpenCL kernel
	
	pSTrajectory->mpKernel->SetWorkDimension(1);
	
	// Bind the buffers associated to this kernel
	
	if( bFlagIsValid )
	{
		bFlagIsValid = TrajectoryBindBuffers(pSTrajectory);
	} // if
	
	return( bFlagIsValid );
} // TrajectoryAcquire

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Compute

//---------------------------------------------------------------------------
//
// Initialize the constant parameters to the kernel
//
//---------------------------------------------------------------------------

static inline void TrajectorySetInitialParams(const float nInitialTime,
											  const float nInitialSpeed,
											  const float nInitialParam,
											  TrajectoryStruct *pSTrajectory)
{
	pSTrajectory->maKFParam[0] = nInitialTime;
	pSTrajectory->maKFParam[2] = nInitialSpeed;
	pSTrajectory->maKFParam[3] = nInitialParam;
} // TrajectorySetInitialParams

//---------------------------------------------------------------------------
//
// Execute the kernel once
//
//---------------------------------------------------------------------------

static inline bool TrajectoryExecuteKernel(TrajectoryStruct *pSTrajectory)
{
	return( pSTrajectory->mpKernel->Execute( &pSTrajectory->mnGlobalWorkSize ) );
} // TrajectoryExecuteKernel

//---------------------------------------------------------------------------
//
// Last parameter can be the initial angle or the initial height, depending
// on the acquired lernel.
//
//---------------------------------------------------------------------------

static bool TrajectoryCompute(Trajectory *pTrajectory,
							  TrajectoryStruct *pSTrajectory)
{
	bool computed = false;
	
	// Bind the constant parameters to the kernel
	
	if( TrajectoryBindParameters(pSTrajectory) )
	{
		// Execute the kernel
		
		if( TrajectoryExecuteKernel(pSTrajectory) )
		{
			pTrajectory->Flush();
			
			// Readback the results
			
			computed = TrajectoryReadBuffers(pSTrajectory);
		} // if
	} // if
	
    return( computed );
} // TrajectoryCompute

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Constructors

//---------------------------------------------------------------------------

Trajectory::Trajectory(const std::string &rProgramSource, 
					   const cl_float nTimeMax, 
					   const cl_float nTimeDelta) 
	: OpenCL::Program(rProgramSource)
{
	mpSTrajectory = TrajectoryCreate(this, nTimeMax, nTimeDelta);
} // Constructor

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Destructor

//---------------------------------------------------------------------------

Trajectory::~Trajectory()
{
	TrajectoryRelease(mpSTrajectory);
} // Destructor

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Utilities

//---------------------------------------------------------------------------

bool Trajectory::Acquire(const std::string &rkernelName)
{
	return( TrajectoryAcquire(rkernelName, mpSTrajectory) );
} // Acquire

//---------------------------------------------------------------------------

bool Trajectory::Compute(const cl_float nInitialTime,
						 const cl_float nInitialSpeed,
						 const cl_float nInitialParam)
{
	TrajectorySetInitialParams(nInitialTime, 
							   nInitialSpeed, 
							   nInitialParam, 
							   mpSTrajectory);
	
    return( TrajectoryCompute(this, mpSTrajectory) );
} // Compute

//---------------------------------------------------------------------------

void Trajectory::Log()
{
	TrajectoryLog(mpSTrajectory);
} // Log

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Accessors

//---------------------------------------------------------------------------

const float *Trajectory::PositionX() const
{
	return( mpSTrajectory->mpKResult[0] );
} // PositionX

//---------------------------------------------------------------------------

const float *Trajectory::PositionY() const
{
	return( mpSTrajectory->mpKResult[1] );
} // PositionY

//---------------------------------------------------------------------------

const float *Trajectory::VelocityX() const
{
	return( mpSTrajectory->mpKResult[2] );
} // VelocityX

//---------------------------------------------------------------------------

const float *Trajectory::VelocityY() const
{
	return( mpSTrajectory->mpKResult[3] );
} // VelocityY

//---------------------------------------------------------------------------

const float *Trajectory::Speed() const
{
	return( mpSTrajectory->mpKResult[4] );
} // Speed

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
