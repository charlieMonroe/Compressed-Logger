//
//  FCHuffmanCodingCompressor.h
//  Logger
//
//  Created by alto on 1/25/11.
//  Copyright 2011 FuelCollective. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FCCompressedLogger.h"

//Number of possible values
#define HUFFMAN_CHAR_SIZE 256
#define NUMBER_OF_NUMBERS (HUFFMAN_CHAR_SIZE * 2)

struct huff_tree_node_t;
typedef struct huff_tree_node_t *huff_node_ptr;
typedef struct {
	//The letter the structure represents.
	//We don't need a signed char as we remember
	//all the other information in other variables.
	unsigned char letter;
	
	//We need to number the nodes
	uint16_t number;
	
	//Occurence of the char
	uint32_t occurrence;
	
	// Indicates that this node represents 
	// the escape
	BOOL isEsc;
	
	//Indicates the node is a leaf.
	BOOL isLeaf;
	
	huff_node_ptr parent;
	huff_node_ptr leftChild;
	huff_node_ptr rightChild;
	
} huff_tree_node_t;

/** The class that actually does all the work. */
@interface FCHuffmanTreeAlgorithm : NSObject {
	// So that we don't have to output each bit, 
	// just keep a cached byte
	uint8_t _cachedByte;
	
	// Number of bits used out of the _cachedByte
	uint8_t _usedBits;
	
	//Used for counting the number of nodes
	uint16_t _numberCounter;
	
	// Instead of using just a tree with pointers, it's much
	// faster (e.g. for searching) to keep a list of nodes
	// in the list as well
	huff_tree_node_t* _list[HUFFMAN_CHAR_SIZE];
	
	// We also index the nodes by their node number
	huff_tree_node_t* _numbers[NUMBER_OF_NUMBERS+1];
	
	huff_tree_node_t *_treeRoot;
	huff_tree_node_t *_escNode;
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
 *  protocol and the FCHuffmanTreeAlgorithm class.
 */
@interface FCHuffmanCodingCompressor : NSObject <FCCompressionAlgorithmClassProtocol> {
	FCHuffmanTreeAlgorithm *_alg;
}

@end
