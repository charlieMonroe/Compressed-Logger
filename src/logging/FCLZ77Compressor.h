//
//  FCLZ77Compressor.h
//  Logger
//
//  Created by alto on 2/2/11.
//  Copyright 2011 FuelCollective. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FCCompressedLogger.h"


/* Minumum length to be matched length & maximum length */
#define MATCH_THRESHOLD 2
#define MATCH_BITS 4
#define MATCH_SIZE  ((1 << MATCH_BITS) + MATCH_THRESHOLD - 1)

/** Try 2 ^ 16 size for the dict size */
#define DICT_BITS 16
#define DICT_SIZE (1 << DICT_BITS)


/** Try 2 ^ 8 hash table size */
#define HASH_BITS 8
#define HASH_SIZE (1 << HASH_BITS)


/** Define a value used as a placeholder in the hash table
 *  and the dictionary. */
#define NO_VALUE 0xFFFF


/** The class that actually does all the work. */
@interface FCLZ77Algorithm : NSObject {
	// So that we don't have to output each bit, 
	// just keep a cached byte
	uint8_t _cachedByte;
	
	// Number of bits used out of the _cachedByte
	uint8_t _usedBits;
	
	//Used for counting the number of nodes
	uint16_t _numberCounter;
	
	uint8_t _hashTable[HASH_SIZE];
	uint8_t _dictionary[DICT_SIZE + MATCH_SIZE];
	uint8_t _dictLinkList[DICT_SIZE];
	
	uint32_t _dictPosition;
	uint32_t _sectorLength;
	BOOL _deleteOldData;
	
	

}

/** Most of the method names are self-explanotary. The rest is 
 *  commented in the implementation file. 
 */
-(void)compressChar:(unsigned char)c toFile:(FILE*)file;
-(NSString*)decompressStringInFile:(FILE*)file ofLength:(uint32_t)len;
-(void)flushToFile:(FILE*)file;
-(BOOL)hasUnwrittenData;

@end





/** This class serves as a proxy between the FCCompressionAlgorithmClassProtocol
 *  protocol and the FCLZ77Algorithm class.
 */
@interface FCLZ77Compressor : NSObject {
	FCLZ77Algorithm *_alg;
}

@end
