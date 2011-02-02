//
//  LoggerAppDelegate.h
//  Logger
//
//  Created by alto on 1/23/11.
//  Copyright 2011 FuelCollective. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FCCompressedLogger.h"

@interface LoggerAppDelegate : NSObject <NSApplicationDelegate, FCCompressedLoggerDelegate, NSTableViewDelegate> {
    NSWindow *window;
	IBOutlet NSArrayController *_runController;
	IBOutlet NSTextView *_textView;
}

@property (assign) IBOutlet NSWindow *window;

-(IBAction)open:(id)sender;

@end
