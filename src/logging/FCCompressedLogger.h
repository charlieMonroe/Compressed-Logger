//
//  FCCompressedLogger.h
//  Logger
//
//  Created by Krystof Vasa on 1/23/11.
//  Copyright 2011 FuelCollective. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// Forward declaration
@class FCCompressedLogger;


/***** Enumaration of available compression algorithms *****/
typedef enum {
	FCCompressionAlgorithmHuffmanCoding = 1,
	FCCompressionAlgorithmLZ77 = 2
} FCCompressionAlgorithm;




/***** Structs used in the class *****/

// Used as the file header at the very beginning
typedef struct {
	uint8_t _compression_algorithm; //Type of a compression algorithm (see the enum above)
	uint64_t _runlist_position; //Position in the file with the run list
	uint8_t _version;
} compressed_logger_file_header;

// Used as the runlist
typedef struct {
	uint32_t _number_of_runs; //Number of runs
} runlist_header;

// Runlist item
typedef struct {
	uint64_t _run_position; //Position of the run in the file
	
	// A time stamp. Using time since 1970/1/1.
	uint64_t _time_stamp;
	
	// The compressor may save some additional information about the run:
	uint32_t _compressor_data_length; 
	void *_compressor_data;
} runlist_item;


/***** A protocol the delegate should implement *****/
@protocol FCCompressedLoggerDelegate

/** When the compressed logger is inited and the file doesn't exist yet, the
 *  delegate is asked to pick a compression algorithm.
 */
-(FCCompressionAlgorithm)loggerShouldUseCompressionAlgorithm:(FCCompressedLogger*)logger;

@end

/***** A protocol that the compressing class has to implement ******/
@protocol FCCompressionAlgorithmClassProtocol

/** Write the string to the file. You should include a line break after the end of formattedString.
 */
-(void)compressedLogger:(FCCompressedLogger*)logger compressString:(NSString*)formattedString toFile:(FILE*)file;


/** Is called before the file is closed. Output some EOF char or something. */
-(void)compressedLogger:(FCCompressedLogger*)logger fileWillBeClosed:(FILE*)file;

/** Decompress the string. The original position in file is stored and restored. */
-(NSString*)compressedLogger:(FCCompressedLogger*)logger decompressFromFile:(FILE*)file startingPosition:(uint64_t)pos length:(uint32_t)len;

/** Store the data specific to this run into data and return the 
 *  length of the data. This is the place to store the Huffman tree 
 *  for example. 
 */
-(size_t)compressedLogger:(FCCompressedLogger*)logger getCustomRunListData:(void**)data;
@end



/***** The actual logging class ******/
@interface FCCompressedLogger : NSObject {
	id <FCCompressedLoggerDelegate> _delegate; //weak ref
	NSString *_path;
	FILE *_fileDesc;
	
	id <FCCompressionAlgorithmClassProtocol> _compressor;
	
	compressed_logger_file_header _header;
	runlist_header _rlist_header;
	
	runlist_item _current_run;
	
	// Instead of some linked list, use the NSMutableArray with 
	// NSValue objects.
	NSMutableArray *_runlist;
	
	BOOL _readOnly;
}

/** This creates a new instance with a default location at ~/Logs/com.yourcompany.yourapp.clog.
 *  It creates a dummy delegate that will choose the FCHuffmanCodingCompressor.
 */
+(FCCompressedLogger*)sharedLogger;

/** If you don't want to use the default settings with sharedLogger, just create your own
 *  with the init method and set it here. 
 *  Warning: if the static logger already exists, it's released. The logger gets retained. 
 */
+(void)setSharedLogger:(FCCompressedLogger*)logger;

/** The date the run was performed on. */
-(NSDate*)dateForRun:(NSInteger)run;

/** Flushes internal cache and writes everything onto the disk, so that the file 
 *  is consistent.
 */
-(void)flushCache;

/** If the file already exists, the logger reads from the file and decides 
 *  on its own which compression algorithm was used before. If the file doesn't
 *  exist yet, the delegate is asked which algorithm to use. The @delegate 
 *  mustn't be nil.
 */
-(id)initWithFile:(NSString*)path delegate:(id <FCCompressedLoggerDelegate>)delegate;

/** Used for just reading the log, so that no additional logs are appended. */
-(id)initWithReadOnlyFile:(NSString*)file;

/** Used for actual logging. First, the string is created and then passed
 *  to the compressor, to compress it. It's easier to use the FCCLog macro,
 *  though.
 */
-(void)log:(NSString*)format, ...;

/** Returns the number of runs. Doesn't count the current session. */
-(NSInteger)numberOfRuns;

/** Returns a decompressed string of run @runNumber. */
-(NSString*)stringForRun:(NSInteger)runNumber;

@end


/** Calls the shared logger. */
#define FCCLog(A, ...) [[FCCompressedLogger sharedLogger] log:[NSString stringWithFormat:A, ## __VA_ARGS__ ]]
//extern void FCCLog(NSString *format, ...);

