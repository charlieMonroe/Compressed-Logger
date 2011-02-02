//
//  FCCompressedLogger.m
//  Logger
//
//  Created by alto on 1/23/11.
//  Copyright 2011 FuelCollective. All rights reserved.
//

#import "FCCompressedLogger.h"
#import "FCHuffmanCodingCompressor.h"

#define FCCompressedLoggerCurrentVersion ((uint8_t)1)

static FCCompressedLogger *_staticLogger;


/* void FCCLog(NSString *format, ...){
	va_list argList;
	va_start(argList, format);
	[[FCCompressedLogger sharedLogger] log:format, argList];
	va_end(argList);
} */


// Private method declarations. Methods are commented with their 
// implementation
@interface FCCompressedLogger (FCPrivates)
-(void)_flushCache;
-(BOOL)_loadCompressorForCompressionAlgorithm:(FCCompressionAlgorithm)alg;
-(BOOL)_readFileHeaderAndCreateCompressor;
-(BOOL)_readRunList;
-(void)_writeFileHeader;
-(void)_writeRunList;

-(id)initWithFile:(NSString*)path delegate:(id <FCCompressedLoggerDelegate>)delegate readOnly:(BOOL)flag;
@end

@implementation FCCompressedLogger
/** Notice it's a class method - used for the sharedLogger. */
+(FCCompressionAlgorithm)loggerShouldUseCompressionAlgorithm:(FCCompressedLogger*)logger{
	return FCCompressionAlgorithmHuffmanCoding;
}
+(FCCompressedLogger*)sharedLogger{
	if (_staticLogger == nil){
		// There isn't one initialized
		NSString *logPath = [[NSString stringWithFormat:@"~/Library/Logs/%@.clog", [[NSBundle mainBundle] bundleIdentifier]]
					   stringByExpandingTildeInPath];
		
		/** Do a little hack with the delegate. Current 'self' is the class object.
		 *  Apple makes us think that the class is something special,
		 *  yet it's just another class, you can send messages to. The only
		 *  issue is that there's no way to say that the class itself supports
		 *  a protocol, so we have to cast it.
		 */
		_staticLogger = [[FCCompressedLogger alloc] initWithFile:logPath delegate:(id <FCCompressedLoggerDelegate>)self];
	}
	
	return _staticLogger;
}
+(void)setSharedLogger:(FCCompressedLogger*)logger{
	if (_staticLogger != nil){
		//Need to release it first
		[_staticLogger release];
	}
	_staticLogger = [logger retain];
}

/** A method that handles the notification about application
 *  termination.
 */
-(void)_applicationWillTerminateNotification{
	//The app is terminating, add this run to the runlist.
	[self _flushCache];
	[_staticLogger release];
	_staticLogger = nil;
}

/** If appendThisRun is YES, creates a new run for this particular session
 *  and adds it to the runlist.
 */
-(void)_flushCache{
	//No need to check for _readOnly as it gets
	//checked in the _writeFileHeader and _writeRunList
	//anyway
	
	// Update the runlist position in the header,
	_header._runlist_position = ftell(_fileDesc);
	_rlist_header._number_of_runs = [_runlist count];
	
	//Write the header
	[self _writeFileHeader];
	
	//Write the run list
	[self _writeRunList];
}
 
/** Returns NO if the algorithm specified is invalid. */
-(BOOL)_loadCompressorForCompressionAlgorithm:(FCCompressionAlgorithm)alg{
	switch (alg) {
		case FCCompressionAlgorithmHuffmanCoding:
			_compressor = [[FCHuffmanCodingCompressor alloc] init];
			return YES;
			break;
		case FCCompressionAlgorithmLZ77:
			#warning Create compressor
			return YES;
			break;
	}
	return NO;
}

/** Reads the header from _fileDesc. May return NO if the file was written by
 *  a newer version of FCCompressedLogger.
 */
-(BOOL)_readFileHeaderAndCreateCompressor{
	//Go to the beginning of the file and read the header
	fseek(_fileDesc, 0, SEEK_SET);
	fread(&_header, sizeof(compressed_logger_file_header), 1, _fileDesc);
	
	if (_header._version > FCCompressedLoggerCurrentVersion){
		//Created by a newer version
		NSLog(@"[FCCompressedLogger _readFileHeaderAndCreateCompressor] - File"
			@" created by a newer version.");
		return NO;
	}
	
	if (![self _loadCompressorForCompressionAlgorithm:_header._compression_algorithm]){
		//Invalid compression algorithm
		NSLog(@"[FCCompressedLogger _readFileHeaderAndCreateCompressor] - Unknown"
			@" compression algorithm.");
		return NO;
	}
	
	return YES;
}
/** Returns NO if encounters an error. */
-(BOOL)_readRunList{
	if (_header._runlist_position == 0){
		//There is no run list yet
		_runlist = [[NSMutableArray array] retain];
		return YES;
	}
	
	if (fseek(_fileDesc, _header._runlist_position, SEEK_SET) != 0){
		//Something happened
		return NO;
	}
	
	fread(&_rlist_header, sizeof(runlist_header), 1, _fileDesc);
	
	_runlist = [[NSMutableArray arrayWithCapacity:_rlist_header._number_of_runs] retain];
	
	//No read each run
	for (int i = 0; i < _rlist_header._number_of_runs; ++i){
		runlist_item *item = (runlist_item*)malloc(sizeof(runlist_item));
		
		/** We need to read the item struct item by struct item as 
		 *  we need the void *_compressor_data not to be read.
		 */
		fread(&item->_run_position, sizeof(uint64_t), 1, _fileDesc);
		fread(&item->_time_stamp, sizeof(item->_time_stamp), 1, _fileDesc);
		fread(&item->_compressor_data_length, sizeof(uint32_t), 1, _fileDesc);
		
		if (item->_compressor_data_length > 0){
			//Read the custom data
			item->_compressor_data = malloc(item->_compressor_data_length);
			fread(item->_compressor_data, item->_compressor_data_length, 1, _fileDesc);
		}else{
			//Get rid of invalid pointers
			item->_compressor_data = NULL;
		}
		
		//Add it to the _runlist
		[_runlist addObject:[NSValue valueWithPointer:item]];
	}
		
	return YES;
}
-(void)_writeFileHeader{
	if (_readOnly){
		return;
	}
	
	//Save the original position:
	int pos = ftell(_fileDesc);
	
	NSLog(@"Saving header. Original position: %i. Runlist position: %i.", pos, _header._runlist_position);
	
	//Go to the beginning of the file
	fseek(_fileDesc, 0, SEEK_SET);
	fwrite(&_header, sizeof(compressed_logger_file_header), 1, _fileDesc);
	
	//Restore the original position
	fseek(_fileDesc, pos, SEEK_SET);
}
-(void)_writeRunList{
	if (_readOnly){
		return;
	}
	
	//Remember and restore current position in the file.
	long pos = ftell(_fileDesc);
	
	NSLog(@"Writing run list - number of items: %i, runlist position %i", [_runlist count], (int)_header._runlist_position);
	
	//Write the number of runs
	fwrite(&_rlist_header._number_of_runs, sizeof(uint32_t), 1, _fileDesc);
	
	// Now write the runs
	for (NSValue *value in _runlist){
		runlist_item *item = [value pointerValue];
		
		// Write the first two items of the runlist item
		// manually
		fwrite(&item->_run_position, sizeof(item->_run_position), 1, _fileDesc);
		fwrite(&item->_time_stamp, sizeof(item->_time_stamp), 1, _fileDesc);
		fwrite(&item->_compressor_data_length, sizeof(item->_compressor_data_length), 1, _fileDesc);
		
		
		//Now write the data, if they're not NULL
		if (item->_compressor_data_length != 0){
			fwrite(item->_compressor_data, item->_compressor_data_length, 1, _fileDesc);
		}
	}
	
	//Restore the original position
	fseek(_fileDesc, pos, SEEK_SET);
}
-(NSDate*)dateForRun:(NSInteger)run{
	NSAssert(run >= 0 && run < [_runlist count], @"run out of range");
	runlist_item *item = [[_runlist objectAtIndex:run] pointerValue];
	return [NSDate dateWithTimeIntervalSince1970:item->_time_stamp];
}
-(void)dealloc{
	[_path release];
	
	//Release the items from the value objects
	for (NSValue *val in _runlist){
		runlist_item *item = (runlist_item*)[val pointerValue];
		if (item->_compressor_data_length != 0){
			free(item->_compressor_data);
		}
		if (item != &_current_run)
			free(item);
	}
	[_runlist release];
	
	[(id)_compressor release];
	
	if (_fileDesc != NULL){
		fclose(_fileDesc);
	}
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}
-(void)flushCache{
	// Pass it to the private function
	[self _flushCache];
}
-(id)initWithFile:(NSString*)path delegate:(id <FCCompressedLoggerDelegate>)delegate{
	if (delegate == nil){
		//No delegate, release and return nil
		[self release];
		self = nil;
		return nil;
	}
	return [self initWithFile:path delegate:delegate readOnly:NO];
}
-(id)initWithFile:(NSString*)path delegate:(id <FCCompressedLoggerDelegate>)delegate readOnly:(BOOL)flag{
	if ((self = [super init]) != nil){
		_delegate = delegate;
		_path = [path retain];
		_readOnly = flag;
		
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:path]){
			//Already exists
			_fileDesc = fopen([path fileSystemRepresentation], "r+");
			if (_fileDesc == NULL){
				//Error opening the file
				NSLog(@"[FCCompressedLogger initWithFile:delegate:] - couldn't open file.");
				[self release];
				return nil;
			}
			if (![self _readFileHeaderAndCreateCompressor]){
				//Couldn't for some reason read the header or create compressor
				[self release];
				return nil;
			}
			if (![self _readRunList]){
				//Couldn't load the run list.
				NSLog(@"[FCCompressedLogger initWithFile:delegate:] - couldn't read the run list.");
				[self release];
				return nil;
			}
			
			_current_run._run_position = _header._runlist_position;
			_current_run._compressor_data = NULL;
			_current_run._compressor_data_length = 0;
		}else{
			// Doesn't exist, get the type of compression from the delegate
			// and set up the _header.
			FCCompressionAlgorithm alg = [_delegate loggerShouldUseCompressionAlgorithm:self];
			if (![self _loadCompressorForCompressionAlgorithm:alg]){
				[self release];
				return nil;
			}
			
			_fileDesc = fopen([path fileSystemRepresentation], "w+");
			if (_fileDesc == NULL){
				NSLog(@"Couldn't create log file!");
				[self release];
				return nil;
			}
			
			_header._compression_algorithm = (uint8_t)alg;
			_header._runlist_position = 0; //No position yet
			_header._version = FCCompressedLoggerCurrentVersion;
			
			_runlist = [[NSMutableArray array] retain];
			
			[self _writeFileHeader];
			
			_current_run._run_position = sizeof(compressed_logger_file_header);
			_current_run._compressor_data = NULL;
			_current_run._compressor_data_length = 0;
		}
		
		_current_run._time_stamp = (uint64_t)[[NSDate date] timeIntervalSince1970];
		
		fseek(_fileDesc, _current_run._run_position, SEEK_SET);
		
		if (!_readOnly){
			//No need for these two for r-only usage
			
			[_runlist addObject:[NSValue valueWithPointer:&_current_run]];
			
			//When the app is terminating, save the log
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationWillTerminateNotification) 
										   name:NSApplicationWillTerminateNotification object:nil];
			
		}
	}
	
	return self;
}
-(id)initWithReadOnlyFile:(NSString*)file{
	//We can pass nil delegate into the private init method
	//as we should be sure that when opening read-only
	//file, we won't need any decisions.
	return [self initWithFile:file delegate:nil readOnly:YES];
}
-(void)log:(NSString*)format, ...{
	if (_readOnly){
		return;
	}
	
	va_list argList;
	va_start(argList, format);
	NSString *formattedString = [NSString stringWithFormat:format, argList];
	va_end(argList);
	
	[_compressor compressedLogger:self compressString:formattedString toFile:_fileDesc];
	
	_header._runlist_position = ftell(_fileDesc);
	
	[self _flushCache];
}

-(NSInteger)numberOfRuns{
	return [_runlist count];
}
-(NSString*)stringForRun:(NSInteger)runNumber{
	NSAssert(runNumber >= 0 && runNumber < [_runlist count], @"runNumber out of range");
	runlist_item *item = [[_runlist objectAtIndex:runNumber] pointerValue];
	
	uint64_t pos = item->_run_position;
	uint32_t length = 0;
	if (runNumber == [_runlist count] - 1){
		//It's the last run
		length = _current_run._run_position - pos;
	}else{
		//Calculate the size from the next run
		runlist_item *nextItem = [[_runlist objectAtIndex:runNumber + 1] pointerValue];
		length = nextItem->_run_position - pos;
	}
	
	//Remember and restore current position in the file.
	long position = ftell(_fileDesc);
	
	NSString *result = [_compressor compressedLogger:self decompressFromFile:_fileDesc startingPosition:pos length:length];
	
	//Restore the original position
	fseek(_fileDesc, position, SEEK_SET);
	
	return result;
}
@end
