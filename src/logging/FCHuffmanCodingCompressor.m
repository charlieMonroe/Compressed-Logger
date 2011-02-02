//
//  FCHuffmanCodingCompressor.m
//  Logger
//
//  Created by alto on 1/25/11.
//  Copyright 2011 FuelCollective. All rights reserved.
//

#import "FCHuffmanCodingCompressor.h"

huff_tree_node_t *FCEmptyHuffTreeNode(){
	huff_tree_node_t *node = (huff_tree_node_t*)malloc(sizeof(huff_tree_node_t));
	node->letter = 0;
	node->number = 0;
	node->isLeaf = NO;
	node->occurrence = 0;
	node->isEsc = NO;
	node->parent = NULL;
	node->leftChild = NULL;
	node->rightChild = NULL;
	return node;
}

/** Returns a sibling. */
huff_tree_node_t* _FCHuffmanTreeSibling(huff_tree_node_t *node){
	if (node->parent == NULL){
		//No sibling
		return NULL;
	}
	huff_tree_node_t *parent = ((huff_tree_node_t*)node->parent);
	return (huff_tree_node_t*)(parent->leftChild == (huff_node_ptr)node ? parent->rightChild : parent->leftChild);
}

// A macro used in decompressFromFile:ofLength:
#define _FCCheckBuffer {\
		if (usedBits == 8){\
			/*Need to read a new byte*/\
			if (readBytes == len){\
				/*End*/\
				break;\
			}\
			if (fread(&byte, sizeof(byte), 1, file) == 0){\
				/*There was an error - read 0 bytes!*/\
				break;\
			}\
			++readBytes;\
			usedBits = 0;\
		}\
	}

@interface FCHuffmanTreeAlgorithm (FCPrivates)

-(huff_tree_node_t*)_getHighestEqualLeaf:(huff_tree_node_t*)node;
-(huff_tree_node_t*)_getHighestEqualNode:(huff_tree_node_t*)node;
-(void)_swapNode:(huff_tree_node_t*)node1 withNode:(huff_tree_node_t*)node2;
-(void)_outputBit:(char)bit toFile:(FILE*)file;
-(void)_outputNode:(huff_tree_node_t*)node toFile:(FILE*)file;
-(void)_updateTreeWithChar:(unsigned char)c;

@end

@implementation FCHuffmanTreeAlgorithm

/** Finds the highest leaf (!!!) node (closest to the root) with equal 
 *  occurence count.
 */
-(huff_tree_node_t*)_getHighestEqualLeaf:(huff_tree_node_t*)node{
	huff_tree_node_t *highest = NULL;
	
	// We don't need to go through the whole tree. As we number the newly
	// created nodes with lower numbers, all we need to do is to go through
	// nodes with higher numbers.
	for (int i = node->number + 1; i < NUMBER_OF_NUMBERS; ++i){
		if (node->occurrence == _numbers[i]->occurrence && _numbers[i]->isLeaf){
			//We only take leaves!
			highest = _numbers[i];
		}
	}
	return highest;
}

/** The same as _getHighestEqualLeaf, but accepts internal leaves as well.
 *  These methods are separated into two for optimization (there'd be a couple
 *  extra comparisons if we made it into one).
 */
-(huff_tree_node_t*)_getHighestEqualNode:(huff_tree_node_t*)node{
	huff_tree_node_t *highest = NULL;
	
	// We don't need to go through the whole tree. As we number the newly
	// created nodes with lower numbers, all we need to do is to go through
	// nodes with higher numbers.
	for (int i = node->number + 1; i < NUMBER_OF_NUMBERS; ++i){
		if (node->occurrence == _numbers[i]->occurrence){
			//We only take leaves!
			highest = _numbers[i];
		}
	}
	return highest;
}

/** Swaps the two nodes and updates their parents. Doesn't do anything 
 *  else with the tree. Is used for updating the tree, hence we assume both 
 *  nodes have the same occurrence counts.
 */
-(void)_swapNode:(huff_tree_node_t*)node1 withNode:(huff_tree_node_t*)node2{
	huff_tree_node_t *temp = NULL;
	uint16_t tempInt;
	
	// If these two are siblings, it's a special case:
	if (node1->parent == node2->parent){
		huff_tree_node_t *parent = (huff_tree_node_t *)node1->parent;
		if (parent->leftChild == (huff_node_ptr)node1){
			//Node1 will now be the rightChild
			parent->leftChild = (huff_node_ptr)node2;
			parent->rightChild = (huff_node_ptr)node1;
		}else{
			//Node1 will now be the leftChild
			parent->leftChild = (huff_node_ptr)node1;
			parent->rightChild = (huff_node_ptr)node2;
		}
		
		// Swap those two in the number array
		temp = _numbers[node1->number];
		_numbers[node1->number] = _numbers[node2->number];
		_numbers[node2->number] = temp;
		
		//Swap the numbers in the nodes
		tempInt = node1->number;
		node1->number = node2->number;
		node2->number = tempInt;
		
		return;
	}
	
	
	huff_tree_node_t *nodeParent1 = (huff_tree_node_t*)node1->parent;
	if (nodeParent1->leftChild == (huff_node_ptr)node1){
		//Node2 will now be leftChild of nodeParent1
		nodeParent1->leftChild = (huff_node_ptr)node2;
	}else{
		nodeParent1->rightChild = (huff_node_ptr)node2;
	}
	
	//The same with the second node
	huff_tree_node_t *nodeParent2 = (huff_tree_node_t*)node2->parent;
	if (nodeParent2->leftChild == (huff_node_ptr)node2){
		//Node1 will now be leftChild of nodeParent2
		nodeParent2->leftChild = (huff_node_ptr)node1;
	}else{
		nodeParent2->rightChild = (huff_node_ptr)node1;
	}
	
	node1->parent = (huff_node_ptr)nodeParent2;
	node2->parent = (huff_node_ptr)nodeParent1;
	
	
	// Swap those two in the number array
	temp = _numbers[node1->number];
	_numbers[node1->number] = _numbers[node2->number];
	_numbers[node2->number] = temp;
	
	//Swap the numbers in the nodes
	tempInt = node1->number;
	node1->number = node2->number;
	node2->number = tempInt;
	
}

/** Ouputs a 1 bit, if @bit is >0 */
-(void)_outputBit:(char)bit toFile:(FILE*)file{
	if (bit == 0){
		//Just move the buffer counter
		++_usedBits;
	}else{
		//Append the bit and move _usedBits
		_cachedByte |= (1 << (7 - _usedBits));
		++_usedBits;
	}
	if (_usedBits == 8){
		//End of the road, output the cached byte
		//and reset it
		fputc(_cachedByte, file);
		_cachedByte = 0;
		_usedBits = 0;
	}
	
}

/** Outputs the code for @node. */
-(void)_outputNode:(huff_tree_node_t*)node toFile:(FILE*)file{
	if (node == NULL){
		//Nothing to output
		return;
	}
	
	if (node == _treeRoot){
		//Probably the first Esc
		[self _outputBit:0 toFile:file];
		return;
	}
	
	uint8_t bitCount = 0;
	char bitBuffer[HUFFMAN_CHAR_SIZE];
	
	//We go up in the tree, up to the root
	//putting into the buffer bits coresponding
	//to whether the node was the parents
	//left or right child.
	while (node->parent != NULL){
		huff_tree_node_t *par = (huff_tree_node_t *)node->parent;
		if (node == (huff_tree_node_t *)par->leftChild){
			//The node is a left child, output 0
			bitBuffer[bitCount] = 0;
		}else{
			bitBuffer[bitCount] = 1;
		}
		
		++bitCount;
		node = (huff_tree_node_t *)node->parent;
	}
	
	//The buffer is in the reverse order
	while (bitCount > 0){
		//We need to decrement it first.
		--bitCount;
		
		[self _outputBit:bitBuffer[bitCount] toFile:file];
	}
}

/** Updates the tree with @c. If a node with this char doesn't exist yet,
 *  it's created. Otherwise it increments the occurrence count and
 *  modifies the tree according to the change.
 */
-(void)_updateTreeWithChar:(unsigned char)c{
	huff_tree_node_t *highest = NULL;
	huff_tree_node_t *node = _list[c];
	
	if (node == NULL){
		//We haven't seen c yet!
		//First, split the Esc node
		_escNode->leftChild = (huff_node_ptr)FCEmptyHuffTreeNode();
		_escNode->rightChild = (huff_node_ptr)FCEmptyHuffTreeNode();
		
		huff_tree_node_t *leftChild = (huff_tree_node_t *)_escNode->leftChild;
		huff_tree_node_t *rightChild = (huff_tree_node_t *)_escNode->rightChild;
		huff_tree_node_t *parent = _escNode;
		
		leftChild->parent = (huff_node_ptr)parent;
		rightChild->parent = (huff_node_ptr)parent;
		
		//No longer Esc
		_escNode->isEsc = NO;
		_escNode->isLeaf = NO;
		
		//The new esc is the left child
		leftChild->isEsc = YES;
		leftChild->isLeaf = YES;
		leftChild->number = _numberCounter--;
		
		_escNode = leftChild;
		
		NSLog(@"Adding %c (%i) to the tree", c, c);
		
		//The char is in the right child
		rightChild->letter = c;
		rightChild->isLeaf = YES;
		rightChild->number = _numberCounter--;
		
		
		_list[c] = rightChild;
		_numbers[leftChild->number] = leftChild;
		_numbers[rightChild->number] = rightChild;
		
		node = rightChild;
	}
	
	// First, see if the sibling is the Esc node
	if (node->parent == _escNode->parent){
		//Yes
		highest = [self _getHighestEqualLeaf:node];
		if (highest != NULL){
			//We could be the only node!
			[self _swapNode:node withNode:highest];
		}
		
		//Increase occurence and climb up the tree
		node->occurrence++;
		node = (huff_tree_node_t *)node->parent;
	}
	
	// We need to climb the tree up to the root
	// to a) update the occurence of the internal nodes
	// b) to swap nodes
	while (node != NULL){
		highest = [self _getHighestEqualNode:node];
		if (highest != NULL){
			[self _swapNode:node withNode:highest];
		}
		
		//Increase occurence and climb up the tree
		node->occurrence++;
		node = (huff_tree_node_t *)node->parent;
	}
}

/** Fills the rest of the bits with some non-sense. */
-(void)closeFile:(FILE*)file{
	if (_usedBits == 0){
		//No need to fill the bits
		return;
	}
	
	while (_usedBits < 8){
		if (_list[0] == NULL){
			//There isn't a zero-char, so let's add it
			[self _updateTreeWithChar:0];
		}
		
		//Now there is a \0 char, so try to output as much of it as possible
		huff_tree_node_t* node = _list[0];
		
		uint8_t bitCount = 0;
		char bitBuffer[HUFFMAN_CHAR_SIZE];
		while (node->parent != NULL){
			huff_tree_node_t *par = (huff_tree_node_t *)node->parent;
			if (node == (huff_tree_node_t *)par->leftChild){
				//The node is a left child, output 0
				bitBuffer[bitCount] = 0;
			}else{
				bitBuffer[bitCount] = 1;
			}
			
			++bitCount;
			node = (huff_tree_node_t *)node->parent;
		}
		
		//The buffer is in the reverse order
		while (bitCount > 0 && _usedBits < 8){
			//We need to decrement it first.
			--bitCount;
			[self _outputBit:bitBuffer[bitCount] toFile:file];
		}
		
	}
}

/** Compresses @c and outputs it into @file. */
-(void)compressChar:(unsigned char)c toFile:(FILE*)file{
	//First, let's see if it's already in the tree
	huff_tree_node_t *node = _list[c];
	if (node == NULL){
		//No occurrence of this char yet!
		//Ouput the escape char first, then 
		//the char itself
		[self _outputNode:_escNode toFile:file];
		
		//Output the char itself
		for (int i = 7; i >= 0; --i){
			[self _outputBit:(c & (1 << i)) toFile:file];
		}
	}else{
		[self _outputNode:node toFile:file];
	}
	
	[self _updateTreeWithChar:c];
	
}

/** Decompresses a string in @file of length @len. Assumes the position
 *  has been set.
 */
-(NSString*)decompressStringInFile:(FILE*)file ofLength:(uint32_t)len{
	//We'll most likely need at least len chars to represent the decompressed string
	NSMutableString *aStr = [[NSMutableString alloc] initWithCapacity:len];
	
	unsigned char byte = 0;
	uint32_t readBytes = 0;
	uint8_t usedBits = 8; //To enforce reading of the first byte
	
	huff_tree_node_t *node = _treeRoot; //Begin in the root
	
	while (true){
		_FCCheckBuffer;
		
		uint8_t bit = (byte & (1 << (7 - usedBits)));
		++usedBits;
		
		if (bit == 0){
			//Left child
			node = (huff_tree_node_t *)node->leftChild;
		}else{
			//==1 -> right child
			node = (huff_tree_node_t *)node->rightChild;
		}
		
		//Now see if this is an Esc node (accept NULL as well)
		if (node == NULL || node->isEsc){
			//Yes. Now we need to read the next 8 bits 
			//and output them as they are.
			unsigned char letter = 0;
			
			for (int i = 0; i < 8; ++i){
				//First, check the buffer for overflow
				_FCCheckBuffer;
				
				uint8_t bit = (byte & (1 << (7 - usedBits)));
				++usedBits;
				
				if (bit != 0){
					letter |= (1 << (7 - i));
				}
			}
			
			_FCCheckBuffer;
						
			[aStr appendFormat:@"%c", letter];
			[self _updateTreeWithChar:letter];
			
			//Start at the root again
			node = _treeRoot;
			
			continue;
		}
		if (node->isLeaf){
			//It's a leaf and not Esc. Output.
			[aStr appendFormat:@"%c", node->letter];
			[self _updateTreeWithChar:node->letter];
			
			//Start at the root again
			node = _treeRoot;
			
			continue;
		}
		
		
	}
	return [aStr autorelease];
	
}

-(void)dealloc{
	// Free all the nodes
	for (int i = 0; i < NUMBER_OF_NUMBERS + 1; ++i){
		if (_numbers[i] != NULL){
			//A valid pointer
			free(_numbers[i]);
		}
	}
	
	[super dealloc];
}

-(void)flushToFile:(FILE*)file{
	fputc(_cachedByte, file);
}

-(BOOL)hasUnwrittenData{
	return _usedBits > 0;
}

/** Initialization. */
-(id)init{
	if ((self = [super init]) != nil){
		for (int i = 0 ; i < HUFFMAN_CHAR_SIZE; ++i){
			_list[i] = NULL;
		}
		for (int i = 0; i < NUMBER_OF_NUMBERS+1; ++i){
			_numbers[i] = NULL;
		}
		
		//Every node needs to have a number
		_numberCounter = NUMBER_OF_NUMBERS;
		
		//Init the tree
		_treeRoot = FCEmptyHuffTreeNode();
		_treeRoot->isEsc = YES;
		_treeRoot->isLeaf = YES;
		_treeRoot->number = (_numberCounter--);
		
		_numbers[_treeRoot->number] = _treeRoot;
		
		_escNode = _treeRoot;
		
		
	}
	return self;
}

@end




@implementation FCHuffmanCodingCompressor


-(void)compressedLogger:(FCCompressedLogger*)logger compressString:(NSString*)formattedString toFile:(FILE*)file{
	//Get to the position
	if ([_alg hasUnwrittenData] != 0){
		//There are some bits left in the previous byte!
		NSLog(@"going back");
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
	FCHuffmanTreeAlgorithm *alg = [[[FCHuffmanTreeAlgorithm alloc] init] autorelease];
	
	//And keep decompressing.
	return [alg decompressStringInFile:file ofLength:len];
}
-(void)compressedLogger:(FCCompressedLogger*)logger fileWillBeClosed:(FILE*)file{
	[_alg closeFile:file];
}
-(void)dealloc{
	[_alg release];
	[super dealloc];
}
-(id)init{
	if ((self = [super init]) != nil){
		_alg = [[FCHuffmanTreeAlgorithm alloc] init];
	}
	return self;
}

@end
