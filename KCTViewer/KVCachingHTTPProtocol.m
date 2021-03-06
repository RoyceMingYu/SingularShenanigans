//
//  KVCachingHTTPProtocol.m
//  KCTViewer
//
//  Created by Johannes Ekberg on 2014-01-23.
//  Copyright (c) 2014 the KanColleTool team. All rights reserved.
//

#import "KVCachingHTTPProtocol.h"
#import "NSString+KVHashes.h"

static NSMutableSet *loadedURLs;

@implementation KVCachingHTTPProtocol

+ (void)load
{
	loadedURLs = [[NSMutableSet alloc] init];
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
	return [request.URL.scheme isEqualToString:@"http"] &&	// Only handle HTTP Requests...
			[request.HTTPMethod isEqualToString:@"GET"] &&	// ...GETs, more specifically...
			![request.URL.host isEqualToString:@"api.comeonandsl.am"] &&	// ...that aren't to the TL API...
			![[self class] propertyForKey:@"_handled" inRequest:request];		// ...and that aren't already handled.
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
	return request;
}

- (id)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id<NSURLProtocolClient>)client
{
	return [super initWithRequest:[request mutableCopy] cachedResponse:cachedResponse client:client];
}

- (void)startLoading
{
	[[self class] setProperty:[NSNumber numberWithBool:YES] forKey:@"_handled" inRequest:(NSMutableURLRequest*)self.request];
	
	BOOL load = YES;
	if((self.cacheEntry = [NSKeyedUnarchiver unarchiveObjectWithFile:[self cachePath]]) && self.cacheEntry.response && self.cacheEntry.data)
	{
		// As a quick-and-dirty alternative to proper handling of the "Cache-Control" header, we just check cache validity
		// based on if the URL has been loaded before during this session.
		if(![loadedURLs containsObject:self.request.URL])
		{
			// If it hasn't been loaded before on this launch, set the "If-Modified-Since" header to make the remote server
			// return a HTTP 304 and no data if the cached data is valid, otherwise the real data.
			[(NSMutableURLRequest *)self.request setValue:[[(NSHTTPURLResponse *)self.cacheEntry.response allHeaderFields] valueForKey:@"Date"] forHTTPHeaderField:@"If-Modified-Since"];
		}
		else
		{
			// If it has been loaded before, just assume it's valid and send back the cached stuff. Also don't load it twice.
			load = NO;
			[self.client URLProtocol:self didReceiveResponse:self.cacheEntry.response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
			[self.client URLProtocol:self didLoadData:self.cacheEntry.data];
			[self.client URLProtocolDidFinishLoading:self];
		}
	}
	else self.cacheEntry = [[KVCacheEntry alloc] initWithRequest:self.request];
	
	// Only load if it hasn't already been loaded from the cache
	if(load)
		self.connection = [NSURLConnection connectionWithRequest:self.request delegate:self];
}

- (void)stopLoading
{
	[self.connection cancel];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[self.cacheEntry appendData:data];
	[self.client URLProtocol:self didLoadData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	[self.client URLProtocol:self didFailWithError:error];
	self.connection = nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	if([(NSHTTPURLResponse *)response statusCode] == 304)
	{
		[loadedURLs addObject:self.request.URL];
		[self.client URLProtocol:self didReceiveResponse:self.cacheEntry.response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
		[self.client URLProtocol:self didLoadData:self.cacheEntry.data];
		[self.client URLProtocolDidFinishLoading:self];
		[self.connection cancel];
	}
	else if(self.cacheEntry.response)
	{
		[NSKeyedArchiver archiveRootObject:self.cacheEntry toFile:[self cachePath]];
		self.cacheEntry = [[KVCacheEntry alloc] initWithRequest:self.request];
		[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
	}
	else
	{
		self.cacheEntry.response = response;
		[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	[NSKeyedArchiver archiveRootObject:self.cacheEntry toFile:[self cachePath]];
	[loadedURLs addObject:self.request.URL];
	[self.client URLProtocolDidFinishLoading:self];
	self.connection = nil;
}

+ (NSString *)cacheDir
{
	return [[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"KCTViewer"] stringByAppendingPathComponent:@"ProtocolCache"];
}

- (NSString *)cachePath
{
	if(!_cachePath)
	{
		NSFileManager *fm = [[NSFileManager alloc] init];
		
		NSString *cacheID = [[self.request.URL absoluteString] sha256];
		NSString *cacheDir = [[self class] cacheDir];
		
		BOOL cacheDirIsDir;
		if(![fm fileExistsAtPath:cacheDir isDirectory:&cacheDirIsDir] || !cacheDirIsDir)
		{
			if(!cacheDirIsDir) [fm removeItemAtPath:cacheDir error:NULL];
			[fm createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:NULL];
		}
		
		_cachePath = [cacheDir stringByAppendingPathComponent:cacheID];
	}
	
	return _cachePath;
}

@end
