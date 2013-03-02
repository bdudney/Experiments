//---------------------------------------------------------------------------
//
//	File: OpenCLFile.mm
//
//  Abstract: A utility class to obtain the contents of a file
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
#import <fstream>

//---------------------------------------------------------------------------

#import "OpenCLFile.h"

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Data Structures

//---------------------------------------------------------------------------

class OpenCL::FileStruct
{
public:
	char    *mpContents;
	size_t   mnContentsSize;
};

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Constructor

//---------------------------------------------------------------------------

static void OpenCLFileCopyContents(const std::string &rFileName,
								   std::ifstream &rFile,
								   OpenCL::FileStruct *pSFile)
{
	pSFile->mnContentsSize = rFile.tellg();
	
	if( pSFile->mnContentsSize )
	{
		pSFile->mpContents = new char[pSFile->mnContentsSize];
		
		if( pSFile->mpContents != NULL )
		{
			rFile.seekg(0, std::ios::beg);
			
			rFile.read(pSFile->mpContents, pSFile->mnContentsSize);
			rFile.close();
		} // if
		else 
		{
			std::cerr	<< ">> ERROR: OpenCL File - \"" 
			<< rFileName 
			<< "\" failed allocating memory to read the source!" 
			<< std::endl;
		} // else
	} // if
	else 
	{
		std::cerr	<< ">> ERROR: OpenCL File - \"" 
		<< rFileName 
		<< "\" file has size 0!" 
		<< std::endl;
	} // else
} // OpenCLFileCopyContents

//---------------------------------------------------------------------------

static void OpenCLFileReadContents(const std::string &rFileName,
								   OpenCL::FileStruct *pSFile)
{
	std::ifstream iFile(rFileName.c_str(), std::ios::in|std::ios::binary|std::ios::ate);
	
	if( iFile.is_open() )
	{
		OpenCLFileCopyContents(rFileName, iFile, pSFile);
	} // if
	else 
	{
		std::cerr	<< ">> ERROR: OpenCL File - \"" 
		<< rFileName 
		<< "\" not opened!" 
		<< std::endl;
	} // else
} // OpenCLFileReadContents

//---------------------------------------------------------------------------

static OpenCL::FileStruct *OpenCLFileCreateWithNameAlias( const std::string &rFileName )
{
	OpenCL::FileStruct  *pSFile = NULL;
	
	if( rFileName.length() )
	{
		pSFile = new OpenCL::FileStruct;
		
		if( pSFile != NULL )
		{
			OpenCLFileReadContents(rFileName, pSFile);
		} // if
	} // if
	else 
	{
		std::cerr << ">> ERROR: OpenCL File - NULL file name!" << std::endl;
	} // else
	
	return( pSFile );
} // OpenCLFileCreateWithNameAlias

//---------------------------------------------------------------------------

static OpenCL::FileStruct *OpenCLFileCreateWithNameRef( const std::string *pFileName )
{
	OpenCL::FileStruct  *pSFile = NULL;
	
	if( pFileName != NULL )
	{
		pSFile = OpenCLFileCreateWithNameAlias(*pFileName);
	} // if
	
	return( pSFile );
} // OpenCLFileCreateWithNameRef

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Copy Constructor

//---------------------------------------------------------------------------

static OpenCL::FileStruct *OpenCLFileCopy( OpenCL::FileStruct *pSFileSrc )
{
	OpenCL::FileStruct *pSFileDst = NULL;
	
	if( pSFileSrc != NULL )
	{
		pSFileDst = new OpenCL::FileStruct;
		
		if( pSFileDst != NULL )
		{
			pSFileDst->mnContentsSize = pSFileSrc->mnContentsSize;
			
			pSFileDst->mpContents = new char[pSFileDst->mnContentsSize];
			
			if( pSFileDst->mpContents != NULL )
			{
				std::strncpy(pSFileDst->mpContents,
							 pSFileSrc->mpContents,
							 pSFileSrc->mnContentsSize);
			} // if
		} // if
	} // if
	
	return( pSFileDst );
} // OpenCLFileCopy

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Private - Destructor

//---------------------------------------------------------------------------

static void OpenCLFileContentsRelease( OpenCL::FileStruct *pSFile )
{
	if( pSFile->mpContents != NULL )
	{
		delete [] pSFile->mpContents;
		
		pSFile->mpContents = NULL;
	} // if
} // OpenCLFileRelease

//---------------------------------------------------------------------------

static void OpenCLFileRelease( OpenCL::FileStruct *pSFile )
{
	if( pSFile != NULL )
	{
		OpenCLFileContentsRelease( pSFile );
		
		delete pSFile;
		
		pSFile = NULL;
	} // if
} // OpenCLFileRelease

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Constructors

//---------------------------------------------------------------------------

OpenCL::File::File( const std::string &rFileName )
{
	mpSFile = OpenCLFileCreateWithNameAlias( rFileName );
} // Constructor

//---------------------------------------------------------------------------

OpenCL::File::File( const std::string *pFileName )
{
	mpSFile = OpenCLFileCreateWithNameRef( pFileName );
} // Constructor

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Destructor

//---------------------------------------------------------------------------

OpenCL::File::~File()
{
	OpenCLFileRelease(mpSFile);
} // Destructor

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Copy Constructor

//---------------------------------------------------------------------------

OpenCL::File::File( const File &rFile )
{
	mpSFile = OpenCLFileCopy( rFile.mpSFile );
} // Copy Constructor

//---------------------------------------------------------------------------

OpenCL::File::File( const File *pSFile )
{
	if( pSFile != NULL )
	{
		mpSFile = OpenCLFileCopy( pSFile->mpSFile );
	} // if
} // Copy Constructor

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Assignment Operator

//---------------------------------------------------------------------------

OpenCL::File &OpenCL::File::operator=(const File &rFile)
{
	if( ( this != &rFile ) && ( rFile.mpSFile != NULL ) )
	{
		OpenCLFileRelease(mpSFile);
		
		mpSFile = OpenCLFileCopy( rFile.mpSFile );
	} // if
	
	return( *this );
} // Assignment Operator

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#pragma mark -
#pragma mark Public - Accessors

//---------------------------------------------------------------------------

const char *OpenCL::File::GetContents() const
{
	return( mpSFile->mpContents );
} // GetContents

//---------------------------------------------------------------------------

const size_t OpenCL::File::GetContentsSize() const
{
	return( mpSFile->mnContentsSize );
} // GetContentsSize

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
