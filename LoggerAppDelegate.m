//
//  LoggerAppDelegate.m
//  Logger
//
//  Created by alto on 1/23/11.
//  Copyright 2011 FuelCollective. All rights reserved.
//

#import "LoggerAppDelegate.h"


@implementation LoggerAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	//[FCCompressedLogger sharedLogger];
	 
	/* FCCompressedLogger *logger = [[FCCompressedLogger alloc] initWithReadOnlyFile:@"/Users/alto/Desktop/com.yourcompany.Logger.clog"];
								for (int i = 0; i < [logger numberOfRuns]; ++i){
									NSLog(@"Run %i : %@", i, [logger stringForRun:i]);
								}
								[logger release];   */   
	//NSString *log = [NSString stringWithFormat:@"%@", [NSData dataWithContentsOfFile:@"/Users/alto/Library/Logs/com.fuelcollective.Dust.log"]];
	//[log writeToFile:@"/Users/alto/Library/Logs/com.fuelcollective.Dust.hex.log" atomically:YES];
	//FCCLog(@"%@", [NSString stringWithContentsOfFile:@"/Users/alto/Library/Logs/GoogleSoftwareUpdateAgent.log"]);
	
	
	for (NSString *str in [[NSProcessInfo processInfo] environment]){
		FCCLog(@"%@ : %@", str, [[[NSProcessInfo processInfo] environment] objectForKey:str]);
	}
	
	
	//[logger release];
}
-(FCCompressionAlgorithm)loggerShouldUseCompressionAlgorithm:(FCCompressedLogger*)logger{
	return FCCompressionAlgorithmHuffmanCoding;
}
-(IBAction)open:(id)sender{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	if ([panel runModalForTypes:[NSArray arrayWithObject:@"clog"]] != NSFileHandlingPanelOKButton){
		//Cancel
		return;
	}
	
	//Clear the content
	[_runController setContent:nil];
	
	FCCompressedLogger *logger = [[FCCompressedLogger alloc] initWithReadOnlyFile:[panel filename]];
	for (int i = 0; i < [logger numberOfRuns]; ++i){
		
		[_runController addObject:[NSDictionary dictionaryWithObjectsAndKeys:[logger stringForRun:i], @"string",
						   [logger dateForRun:i], @"date",
						   nil]];
	}
	[logger release];
}
-(void)tableViewSelectionDidChange:(NSNotification *)notification{
	//Reload the _textView string;
	
	NSArray *selObjs = [_runController selectedObjects];
	if ([selObjs count] == 0){
		//No selection
		[_textView setString:@""];
		return;
	}
	
	[_textView setString:[[selObjs objectAtIndex:0] objectForKey:@"string"]];
}
@end
