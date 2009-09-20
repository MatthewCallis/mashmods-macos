/* AppController */

#import <Cocoa/Cocoa.h>
#import "Console.h"

// List of supported chip IDs
typedef struct {
	const char* chipname;
	unsigned char manufacturer;
	unsigned char device;
	bool bottomBoot; // boot block sectors start at addr 0
} FlashChipCode;

@interface AppController : NSObject {
	IBOutlet NSButton *openFile;
    IBOutlet NSWindow *window;
	IBOutlet NSProgressIndicator *indicator;

	NSArray *algorithmTags;
	NSString *filename;

	BOOL cartBanking; // TRUE = HiROM, FALSE = LoROM
	int cartSize;
	int saveSize;
	int flashChip;

	Console *console;
}

- (IBAction)detectRomType:(id)sender;
- (IBAction)dumpCart:(id)sender;
- (IBAction)dumpSave:(id)sender;
- (IBAction)writeCart:(id)sender;
- (IBAction)writeSave:(id)sender;
- (IBAction)eraseCart:(id)sender;

- (BOOL)dragIsFile:(id <NSDraggingInfo>)sender;
- (NSString *)getFileForDrag:(id <NSDraggingInfo>)sender;

// USB Functions
- (void)powerOn;
- (void)powerOff;
- (BOOL)openPort;
- (void)closePort;
- (BOOL)readEEPROM;
- (BOOL)writeEEPROM:(NSString *)fileName;
- (BOOL)detectHIROM;
- (BOOL)readBytes:(unsigned char *)data bytes:(int)bytes;
- (BOOL)writeBytes:(unsigned char *)data bytes:(int)bytes;
- (BOOL)flashDetect;

- (BOOL) flashErase:(int)romsize;

- (BOOL) flashEraseCommand:(int)addr chipErase:(BOOL)chiperase;

- (BOOL)flashROM:(NSString *)fileName;

- (int)readROM:(NSString *)fileName kbytes:(int)kbytes;

- (BOOL)readSaveFile:(NSString *)fileName;

- (BOOL)writeSaveFile:(NSString *)fileName;

- (BOOL)clearSave;

- (BOOL)sendJunk;

- (void)disableEE;

- (BOOL)sendEEBit:(int)bit read:(int)read;

- (BOOL)readEE:(unsigned char *)data bytes:(int)bytes;

- (BOOL)writeEE:(unsigned char *)data bytes:(int)bytes;

@end
