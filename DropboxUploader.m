//
//  DropboxUploader.m
//  Captured for Mac
//
//  Created by Jorge Velázquez on 3/16/11.
//  Copyright 2011 Codeography. All rights reserved.
//

#import <CommonCrypto/CommonHMAC.h>

#import "CloudUploader.h"
#import "DropboxUploader.h"

// these are the Dropbox API keys, keep them safe
static char* oauthConsumerKey = "bpsv3nx35j5hua7";
static char* oauthConsumerSecretKey = "qa9tvwoivvspknm";

// characters suitable for generating a unique nonce
static char* nonceChars = "abcdefghijklmnopqrstuvwxyz0123456789";

@implementation DropboxUploader

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

- (NSInteger)uploadFile:(NSString*)sourceFile
{
	CURLcode rc = CURLE_OK;
		
	// generate a unique filename
	char tempNam[16];
	strcpy(tempNam, "XXXXX.png");
	mkstemps(tempNam, 4);
	
	// user tokens, these will need to be
	NSString* token = @"nx7s0yvpe6654x6";
	NSString* secret = @"zspeub00bk58qlr";
	
	// set the url
	NSString* url = @"https://api-content.dropbox.com/0/files/dropbox/Public";
	rc = curl_easy_setopt(handle, CURLOPT_URL, [url UTF8String]);
	
	// generate a unique nonce for this request
	time_t oauthTimestamp = time(NULL);
	NSString* oauthNonce = [self genRandStringLength:16 seed:oauthTimestamp];
	
	// format the signature base string
	NSString* sigBaseString = [NSString stringWithFormat:@"file=%s&oauth_consumer_key=%s&oauth_nonce=%@&oauth_signature_method=HMAC-SHA1&oauth_timestamp=%lu&oauth_token=%@&oauth_version=1.0", tempNam, oauthConsumerKey, oauthNonce, oauthTimestamp, token];
    CFStringEncoding encoding = CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding);
	NSString* escapedUrl = [(NSString*) CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef) url, NULL, (CFStringRef) @":?=,!$&'()*+;[]@#~/", encoding) autorelease];
    NSString* escapedPath = [(NSString*) CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef) sigBaseString, NULL, (CFStringRef) @":?=,!$&'()*+;[]@#~/", encoding) autorelease];
	sigBaseString = [NSString stringWithFormat:@"POST&%@&%@", escapedUrl, escapedPath];
 	NSData* dataToSign = [sigBaseString dataUsingEncoding:NSASCIIStringEncoding];

	// build the signature
	CCHmacContext context;
	unsigned char digestRaw[CC_SHA1_DIGEST_LENGTH];
	NSString* keyToSign = [NSString stringWithFormat:@"%s&%@", oauthConsumerSecretKey, secret];
	CCHmacInit(&context, kCCHmacAlgSHA1, [keyToSign cStringUsingEncoding:NSASCIIStringEncoding], [keyToSign length]);
	CCHmacUpdate(&context, [dataToSign bytes], [dataToSign length]);
	CCHmacFinal(&context, digestRaw);
	NSData *digestData = [NSData dataWithBytes:digestRaw length:CC_SHA1_DIGEST_LENGTH];
	NSString* oauthSignature = [digestData base64EncodedString];;
	
	// set up the body
	CFUUIDRef uuid = CFUUIDCreate(NULL);
	NSString* stringBoundary = [(NSString*)CFUUIDCreateString(NULL, uuid) autorelease];
	CFRelease(uuid);
	NSMutableData* bodyData = [NSMutableData data];
	[bodyData appendData: [[NSString stringWithFormat:@"--%@\r\n", stringBoundary] dataUsingEncoding:NSUTF8StringEncoding]];

	// Add data to upload
	[bodyData appendData: [[NSString stringWithFormat: @"Content-Disposition: form-data; name=\"file\"; filename=\"%s\"\r\n", tempNam] dataUsingEncoding:NSUTF8StringEncoding]];
	[bodyData appendData: [[NSString stringWithString:@"Content-Type: image/png\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];

	NSString* tempFilename = [NSString stringWithFormat: @"%.0f.txt", [NSDate timeIntervalSinceReferenceDate] * 1000.0];
	NSString *tempFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:tempFilename];
	if (![[NSFileManager defaultManager] createFileAtPath:tempFilePath contents:bodyData attributes:nil]) {
		NSLog(@"failed to create file");
		return -1;
	}

	NSFileHandle* bodyFile = [NSFileHandle fileHandleForWritingAtPath:tempFilePath];
	[bodyFile seekToEndOfFile];

	if ([[NSFileManager defaultManager] fileExistsAtPath:sourceFile]) {
		NSFileHandle* readFile = [NSFileHandle fileHandleForReadingAtPath:sourceFile];
		NSData* readData;
		while ((readData = [readFile readDataOfLength:1024 * 512]) != nil && [readData length] > 0) {
			@try {
				[bodyFile writeData:readData];
			} @catch (NSException* e) {
				NSLog(@"failed to write data");
				[readFile closeFile];
				[bodyFile closeFile];
				[[NSFileManager defaultManager] removeItemAtPath:tempFilePath error:nil];
				return -1;
			}
		}
		[readFile closeFile];
	} else {
		NSLog(@"unable to open sourceFile");
	}
	
    @try {
		[bodyFile writeData: [[NSString stringWithFormat:@"\r\n--%@--\r\n", stringBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
	} @catch (NSException* e) {
		NSLog(@"failed to write end of data");
		[bodyFile closeFile];
		[[NSFileManager defaultManager] removeItemAtPath:tempFilePath error:nil];
		return -1;
	}
	[bodyFile closeFile];
	
	// dropbox wants a POST
	rc = curl_easy_setopt(handle, CURLOPT_POST, 1);
	
	// build the custom headers
	NSString* authHeader = [NSString stringWithFormat:@"Authorization: OAuth file=\"%s\", oauth_consumer_key=\"%s\", oauth_signature_method=\"HMAC-SHA1\", oauth_signature=\"%@\", oauth_timestamp=\"%lu\", oauth_nonce=\"%@\", oauth_token=\"%@\", oauth_version=\"1.0\"", tempNam, oauthConsumerKey, oauthSignature, oauthTimestamp, oauthNonce, token];
	NSString* contentTypeHeader = [NSString stringWithFormat:@"Content-Type: multipart/form-data; boundary=%@", stringBoundary];
	
	// add the custom headers
	struct curl_slist *slist= NULL;
	slist = curl_slist_append(slist, [contentTypeHeader UTF8String]);
	slist = curl_slist_append(slist, [authHeader UTF8String]);
	curl_easy_setopt(handle, CURLOPT_HTTPHEADER, slist);
	
	// get the file pointer for passing
	FILE* fp = fopen([tempFilePath UTF8String], "rb");
	rc = curl_easy_setopt(handle, CURLOPT_READDATA, fp);
	
	// set the size of the data
	NSDictionary* dict = [[NSFileManager defaultManager] attributesOfItemAtPath:tempFilePath error:nil];
	unsigned long long size = [dict fileSize];
	rc = curl_easy_setopt(handle, CURLOPT_POSTFIELDSIZE, size);

	// do the upload
	rc = curl_easy_perform(handle);
	curl_slist_free_all(slist);
	if (rc == CURLE_OK)
	{
		long response_code;
		rc = curl_easy_getinfo(handle, CURLINFO_RESPONSE_CODE, &response_code);
		if (rc == CURLE_OK && response_code == 200)
			NSLog(@"File successfully uploaded to Dropbox and accessible at ");
	}
	
	[[NSFileManager defaultManager] removeItemAtPath:tempFilePath error:nil];
	fclose(fp);
	
	return rc;
}

- (NSInteger)testConnection
{
	CURLcode rc = CURLE_OK;
	
	rc = curl_easy_perform(handle);
	
	return rc;
}

-(NSString*)genRandStringLength:(int)len seed:(unsigned long)seed {
	NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
	
	srand(seed);
	for (int i=0; i<len; i++) {
		[randomString appendFormat: @"%c", nonceChars[rand() % strlen(nonceChars)]];
	}
		 
	return randomString;
}
		 
@end
