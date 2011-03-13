//
//  SFTPUploader.m
//  Captured for Mac
//
//  Created by Jorge Velázquez on 3/11/11.
//  Copyright 2011 Codeography. All rights reserved.
//

#import "SFTPUploader.h"

@implementation SFTPUploader

@synthesize handle;

- (id)init
{
	self = [super init];
	if (self) {
		handle = curl_easy_init();
	}

	return self;
}

- (void)dealloc
{
	[super dealloc];
	curl_easy_cleanup(handle);
}

- (int)uploadFile:(NSString*)sourceFile host:(NSString*)host username:(NSString*)username password:(NSString*)password targetDir:(NSString*)targetDir
{
	CURLcode rc = CURLE_OK;
	
	// first thing we do is make sure we have a file to read
	FILE* fp = fopen([sourceFile UTF8String], "rb");
	if (fp == NULL)
		return -1;
	
	// generate a unique filename
	char tempNam[16];
	strcpy(tempNam, "XXXXX");
	mkstemp(tempNam);
	
	// format the url
	NSString* url = [NSString stringWithFormat:@"sftp://%@/%@/%s", host, targetDir, tempNam];

	// reset the handle
	curl_easy_reset(handle);
	
	// set the url
	rc = curl_easy_setopt(handle, CURLOPT_URL, [url UTF8String]);
	if (rc != CURLE_OK)
	{
		fclose(fp);
		return rc;
	}
	
	// set the username and password
	rc = curl_easy_setopt(handle, CURLOPT_USERNAME, [username UTF8String]);
	if (rc != CURLE_OK)
	{
		fclose(fp);
		return rc;
	}
	rc = curl_easy_setopt(handle, CURLOPT_PASSWORD, [password UTF8String]);
	if (rc != CURLE_OK)
	{
		fclose(fp);
		return rc;
	}
	
	// tell libcurl we're doing an upload
	rc = curl_easy_setopt(handle, CURLOPT_UPLOAD, 1);
	if (rc != CURLE_OK)
	{
		fclose(fp);
		return rc;
	}
	
	// get a FILE* to pass to libcurl
	rc = curl_easy_setopt(handle, CURLOPT_READDATA, fp);
	if (rc != CURLE_OK)
	{
		fclose(fp);
		return rc;
	}
	
	// do the upload
	rc = curl_easy_perform(handle);
	
	fclose(fp);
	
	return rc;
}

- (int)testConnection:(NSString*)host username:(NSString*)username password:(NSString*)password targetDir:(NSString*)targetDir
{
	CURLcode rc = CURLE_OK;
	
	NSString* url = [NSString stringWithFormat:@"sftp://%@/%@", host, targetDir];
	
	curl_easy_reset(handle);
	
	rc = curl_easy_setopt(handle, CURLOPT_URL, [url UTF8String]);
	if (rc != CURLE_OK)
		return rc;
	
	rc = curl_easy_setopt(handle, CURLOPT_USERNAME, [username UTF8String]);
	if (rc != CURLE_OK)
		return rc;
	rc = curl_easy_setopt(handle, CURLOPT_PASSWORD, [password UTF8String]);
	if (rc != CURLE_OK)
		return rc;

	rc = curl_easy_perform(handle);
	
	return rc;
}

@end
