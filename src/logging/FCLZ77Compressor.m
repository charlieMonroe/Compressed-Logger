//
//  FCLZ77Compressor.m
//  Logger
//
//  Created by alto on 2/2/11.
//  Copyright 2011 FuelCollective. All rights reserved.
//

#import "FCLZ77Compressor.h"



@implementation FCLZ77Algorithm


-(void)compressChar:(unsigned char)c toFile:(FILE*)file{
	if (_deleteOldData){
		//We need to delete old data from the dictionary
		[self _deleteOldData];
	}
	
	
}
-(id)init{
	if ((self = [super init]) != nil){
		_dictPosition = 0;
		_sectorLength = 0;
		_deleteOldData = NO;
		
		for (int i = 0; i < HASH_SIZE; ++i){
			_hashTable[i] = NO_VALUE;
		}
		
		_dictLinkList[DICT_SIZE] = NO_VALUE;
	}
	return self;
}

@end




@implementation FCLZ77Compressor

-(void)compressedLogger:(FCCompressedLogger*)logger compressString:(NSString*)formattedString toFile:(FILE*)file{
	//Get to the position
	if ([_alg hasUnwrittenData] != 0){
		//There are some bits left in the previous byte!
		fseek(file, ftell(file) - 1, SEEK_SET);
	}
	
	const char *string = [formattedString UTF8String];
	NSInteger len = [formattedString length];
	for (int i = 0; i < len; ++i){
		[_alg compressChar:string[i] toFile:file];
	}
	
	//Add a trailing newline
	//[_alg compressChar:'\n' toFile:file];
	
	[_alg flushToFile:file];
}
-(size_t)compressedLogger:(FCCompressedLogger*)logger getCustomRunListData:(void**)data{
	//No need to store any data
	return 0;
}
-(NSString*)compressedLogger:(FCCompressedLogger*)logger decompressFromFile:(FILE*)file startingPosition:(uint64_t)pos length:(uint32_t)len{
	
	fseek(file, pos, SEEK_SET);
	
	//Create new huffman tree
	FCLZ77Algorithm *alg = [[[FCLZ77Algorithm alloc] init] autorelease];
	
	//And keep decompressing.
	return [alg decompressStringInFile:file ofLength:len];
}
-(void)dealloc{
	[_alg release];
	[super dealloc];
}
-(id)init{
	if ((self = [super init]) != nil){
		_alg = [[FCLZ77Algorithm alloc] init];
	}
	return self;
}

@end
