#import "AppController.h"
#include "ftd2xx.h"
#include "NSString+Truncate.h"

#import <þekking/RomFile.h>
#import <þekking/ParseRomDelegate.h>

FT_HANDLE ftHandleA;	// DATA BUS
FT_STATUS ftStatus;		// STATUS

//Number of boot block and regular sectors
#define FLASH_BOOT_8K 8
#define FLASH_MIDDLE_64K 63

@implementation AppController

- (id)init{
	if(self = [super init]){
		cartBanking = FALSE;
	}
	filename = nil;
	return self;
}

- (void)dealloc{
	[algorithmTags release];
	[super dealloc];
}

- (void)awakeFromNib{
//	NSLog(@"awakeFromNib");
	NSArray *dragTypes = [NSArray arrayWithObjects:NSFilenamesPboardType, nil];
	[window registerForDraggedTypes:dragTypes];
	console = [[Console alloc] init];
	[console show];
}

- (IBAction)detectRomType:(id)sender{
	[console addText:@"Detecting ROM Type...\n"];
	if(![self openPort]) return;
	[self powerOn];
	if([self flashDetect]){
		[self readEEPROM];
	}
	else{
		[self disableEE];
		[self detectHIROM];
	}
	[self powerOff];
	[self closePort];
}

- (IBAction)dumpCart:(id)sender{
	NSSavePanel *outputDirectory = [NSSavePanel savePanel];
	[outputDirectory setCanSelectHiddenExtension:TRUE];
	[outputDirectory setCanCreateDirectories:TRUE];
	if([outputDirectory runModalForDirectory:nil file:nil] == NSFileHandlingPanelOKButton){
		[console addText:[NSString stringWithFormat:@"File will be saved as: %@\n", [[outputDirectory filename] lastPathComponent]]];
		if(![self openPort]) return;
		[self powerOn];
		[self disableEE];
		[self detectHIROM];
		[self readROM:[outputDirectory filename] kbytes:cartSize];
		[self powerOff];
		[self closePort];
	}
	else{
		return;
	}
}

- (IBAction)dumpSave:(id)sender{
	NSSavePanel *outputDirectory = [NSSavePanel savePanel];
	[outputDirectory setCanSelectHiddenExtension:TRUE];
	[outputDirectory setCanCreateDirectories:TRUE];
	if([outputDirectory runModalForDirectory:nil file:nil] == NSFileHandlingPanelOKButton){
		[console addText:[NSString stringWithFormat:@"File will be saved as: %@\n", [outputDirectory filename]]];
		if(![self openPort]) return;
		[self powerOn];
		[self disableEE];
		[self detectHIROM];
		[self readSaveFile:[outputDirectory filename]];
		[self powerOff];
		[self closePort];
	}
	else{
		return;
	}
}

- (IBAction)writeCart:(id)sender{
	NSOpenPanel *outputDirectory = [NSOpenPanel openPanel];
	[outputDirectory setCanChooseFiles:TRUE];
	[outputDirectory setAllowsMultipleSelection:FALSE];
	[outputDirectory setCanCreateDirectories:TRUE];
	if([outputDirectory runModalForDirectory:nil file:nil] == NSFileHandlingPanelOKButton){
		[console addText:[NSString stringWithFormat:@"'%@' will be written to Flash Cart.\n", [[outputDirectory filename] lastPathComponent]]];
		ParseRomDelegate *parseRom = [[ParseRomDelegate alloc] init];
		NSMutableArray *parsedRomsArray = (NSMutableArray *)[parseRom listFiles:[outputDirectory filenames]];
		[parseRom release];

		NSEnumerator *filesEnumerator = [parsedRomsArray objectEnumerator];
		RomFile *currentFile;
		while(currentFile = [filesEnumerator nextObject]){
			[console addText:[NSString stringWithFormat:@"Cart Type: %@\n", [currentFile cartType]]];
			[console addText:[NSString stringWithFormat:@"Country    %@\n", [currentFile country]]];
			[console addText:[NSString stringWithFormat:@"Game Code: %@\n", [currentFile gameCode]]];
			[console addText:[NSString stringWithFormat:@"Version:   %@\n", [currentFile version]]];
			[console addText:[NSString stringWithFormat:@"Header:    %@\n", [currentFile headerCheck]]];
			[console addText:[NSString stringWithFormat:@"Title:     %@\n", [currentFile internalTitle]]];
			[console addText:[NSString stringWithFormat:@"CRC32:     %@\n", [currentFile fileCRC32]]];
			[console addText:[NSString stringWithFormat:@"SHA1:      %@\n", [currentFile fileSHA1]]];
			[console addText:[NSString stringWithFormat:@"MD5:       %@\n", [currentFile fileMD5]]];
			[console addText:[NSString stringWithFormat:@"Save Size: %@\n", [currentFile saveSize]]];
			[console addText:[NSString stringWithFormat:@"File Size: %@\n", [currentFile romSize]]];
			[console addText:[NSString stringWithFormat:@"ROM Map:   %@\n", [currentFile romMap]]];
			if([[currentFile romMap] isEqualToString:[NSString stringWithString:@"HiROM"]]){
				cartBanking = TRUE;
			}	
			else{
				cartBanking = FALSE;
			}
		}

		NSFileManager *fm = [NSFileManager defaultManager];
		NSDictionary *fattrs = [fm fileAttributesAtPath:[outputDirectory filename] traverseLink:NO];
		cartSize = [[fattrs objectForKey:NSFileSize] intValue] / 1024;

		[console addText:[NSString stringWithFormat:@"Cart Size: %d\n", cartSize]];

		if(![self openPort]) return;
		[self powerOn];
		sleep(1);
		[self writeEEPROM:[[outputDirectory filename] lastPathComponent]];
		sleep(1);
		[self disableEE];
		sleep(2);
		if([self flashDetect]){
			sleep(2);
			[self flashErase: cartSize];
			sleep(2);
			[self flashROM:[outputDirectory filename]];
			sleep(1);
			[self clearSave];
		}
		[self powerOff];
		[self closePort];
	}
	else{
		return;
	}
}

- (IBAction)writeSave:(id)sender{
	NSOpenPanel *outputDirectory = [NSOpenPanel openPanel];
	[outputDirectory setCanChooseFiles:TRUE];
	[outputDirectory setAllowsMultipleSelection:FALSE];
	[outputDirectory setCanCreateDirectories:TRUE];
	if([outputDirectory runModalForDirectory:nil file:nil] == NSFileHandlingPanelOKButton){
		[console addText:[NSString stringWithFormat:@"'%@' will be written to Flash Cart.\n", [[outputDirectory filename] lastPathComponent]]];
		if(![self openPort]) return;
		[self powerOn];
		[self disableEE];
		[self detectHIROM];
		[self writeSaveFile:[outputDirectory filename]];
		[self powerOff];
		[self closePort];
	}
	else{
		return;
	}
}

- (IBAction)eraseCart:(id)sender{
	[console addText:@"Erase Cart...\n"];
	if(![self openPort]) return;
	[self powerOn];
	cartBanking = FALSE;
	sleep(1);
	[self writeEEPROM:@""];
	sleep(1);
	[self disableEE];
	sleep(1);
	if([self flashDetect]){
		[self flashErase: 4096];
		sleep(1);
		cartBanking = TRUE;
		[self flashErase: 4096];
		sleep(1);
		[self clearSave];
		sleep(1);
	}
	[self powerOff];
	[self closePort];
}

#pragma mark -
#pragma mark - Drag & Drop Functions

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender{
	NSView *view = [window contentView];

	if(![self dragIsFile:sender]){
		return NSDragOperationNone;
	}

	[view lockFocus];

	[[NSColor selectedControlColor] set];
	[NSBezierPath setDefaultLineWidth:5];
	[NSBezierPath strokeRect:[view bounds]];

	[view unlockFocus];

	[window flushWindow];

	return NSDragOperationGeneric;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender{
	filename = [self getFileForDrag:sender];

	[[window contentView] setNeedsDisplay:YES];

	return YES;
}

- (BOOL)dragIsFile:(id <NSDraggingInfo>)sender{
	BOOL isDirectory;
	NSString *dragFilename = [self getFileForDrag:sender];
	[[NSFileManager defaultManager] fileExistsAtPath:dragFilename isDirectory:&isDirectory];
	return !isDirectory;
}

- (NSString *)getFileForDrag:(id <NSDraggingInfo>)sender{
	NSPasteboard *pb = [sender draggingPasteboard];
	NSString *availableType = [pb availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
	NSString *dragFilename;
	NSArray *props;

	props = [pb propertyListForType:availableType];
	dragFilename = [props objectAtIndex:0];

	return dragFilename;	
}

- (void)draggingExited:(id <NSDraggingInfo>)sender{
	[[window contentView] setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark - USB Functions

/* USB Interface */
- (void) powerOn{
	[console addText:@"Powering On...\n"];
	unsigned char command[2];
	command[0] = 'P'; //Power On
	command[1] = 1;
	[self writeBytes:command bytes:2];
}

- (void) powerOff{
	[console addText:@"Powering Off...\n"];
	unsigned char command[4];
	command[0] = 'C'; // Set CS
	command[1] = 0;
	command[2] = 'P'; // Power Off
	command[3] = 0;
	[self writeBytes:command bytes:4];
}

- (BOOL) openPort{
	[console addText:@"Opening Port...\n"];
	ftStatus = FT_OpenEx("USB SNES FLASH", FT_OPEN_BY_DESCRIPTION, &ftHandleA); //open data bus
	if(ftStatus == FT_OK){
		// Success - Device Open
		[console addText:@"Device Found!\n"];
	}
	else{
		// Failure - one or both of the devices has not been opened
		[console addText:@"USB Error: Opening of USB SNES FLASH Failed!\n"];
		return FALSE;
	}
	return TRUE;
}

- (void) closePort{
	[console addText:@"Port Closed!\n"];
	FT_Close(ftHandleA);
}

/* Input / Output (IO) */
- (BOOL) writeBytes:(unsigned char *)data bytes:(int)bytes{
	DWORD bytesWritten = 0;

	ftStatus = FT_Write(ftHandleA, data, bytes, &bytesWritten);
//	NSLog(@"Write Status: %i / %i", ftStatus, FT_OK);
	if(ftStatus == FT_OK){
//		NSLog(@"Write Success! (%d bytes)", bytesWritten);
		// FT_Read OK
		return TRUE;
	}
	else{
		// FT_Write Timeout 
		[console addText:[NSString stringWithFormat:@"FT STATUS = %i\n", ftStatus]];
		return FALSE;
	}
}

- (BOOL) readBytes:(unsigned char *)data bytes:(int)bytes{
//	NSLog(@"Reading %d bytes...", bytes);
	DWORD bytesReceived = 0;
	FT_SetTimeouts(ftHandleA, 10000, 0);
	ftStatus = FT_Read(ftHandleA, data, bytes, &bytesReceived);
	if(ftStatus == FT_OK){
		if(bytesReceived != bytes){
			[console addText:[NSString stringWithFormat:@"Timed out! Only %d bytes read!\n", bytesReceived]];
			return FALSE;
		}
		// FT_Read OK
//		NSLog(@"Read Success (%d bytes)", bytes);
		return TRUE;
	}
	else{
		// FT_Read Failed
		[console addText:[NSString stringWithFormat:@"USB Error: Read Failed!\n"]];
		[console addText:[NSString stringWithFormat:@"FT STATUS = %i\n", ftStatus]];
		return FALSE;
	}
}

- (BOOL) detectHIROM{
	unsigned char  command[32];

	unsigned char *buffer1 = (unsigned char*)malloc(1024);
	unsigned char *buffer2 = (unsigned char*)malloc(1024);
	unsigned char *buffer3 = (unsigned char*)malloc(1024);

	// Read 
	command[0] = 'C';	// Set CS
	command[1] = 1;
	command[6] = 'R';	// Autoread 1
	command[7] = 0x00;	// 0x407C00 - A15=0 LoROM
	command[8] = 0x7C;
	command[9] = 0x40;
	command[10] = 'R';	// Autoread 2
	command[11] = 0x00;	// 0x40FC00 - A15=1 HiROM
	command[12] = 0xFC;
	command[13] = 0x40;
	command[14] = 'R';	// Autoread 3
	command[15] = 0x00;	// 0x400000 - A15=0
	command[16] = 0x00;
	command[17] = 0x40;
	command[18] = 'C';	// Set CS
	command[19] = 0;

	// Send the command
	[self writeBytes: command bytes: 20];

	// Read back the data
	[self readBytes:buffer1 bytes: 1024];
	[self readBytes:buffer2 bytes: 1024];
	[self readBytes:buffer3 bytes: 1024];

	// Compare
	cartBanking = FALSE;

	// Check for 64k banks (uses A15 for bank 40, not mirror)
	// Sometimes it does use A15 for LOROM and sets it to open bus
	if(memcmp(buffer1, buffer2, 1024) != 0){
	// Check for 64k banks again (real data when A15=0)
		if(memcmp(buffer1, buffer3, 1024) != 0){
	// Done!
			cartBanking = TRUE;
//			NSLog(@"HiROM! (1)");
//			[textFieldBank setStringValue:@"HiROM"];
		}
		else{
			cartBanking = FALSE;
//			NSLog(@"LoROM! (1)");
//			[textFieldBank setStringValue:@"LoROM"];
		}
	}

	unsigned char sizeByte = buffer2[983];
	unsigned char saveByte = buffer2[984];
//	NSData *bufferA = [NSData dataWithBytes:buffer1 length:1024];
//	NSLog(@"%@", [bufferA description]);
//	NSData *bufferB = [NSData dataWithBytes:buffer2 length:1024];
//	NSLog(@"%@", [bufferB description]);
//	NSData *bufferC = [NSData dataWithBytes:buffer3 length:1024];
//	NSLog(@"%@", [bufferC description]);
//	NSLog(@"Maker Code: %02x", buffer2[944]);
//	NSLog(@"Maker Code: %02x", buffer2[945]);
//	NSLog(@"ROM Speed:	%02x", buffer2[981]);
//	NSLog(@"Cart Type:	%02x", buffer2[982]);
//	NSLog(@"File Size:	%02x", buffer2[983]);
//	NSLog(@"SRAM Size:	%02x", buffer2[984]);

	switch(sizeByte){
		case 0x08: cartSize = 256;	break; // 2MB
		case 0x09: cartSize = 512;	break; // 4MB
		case 0x0A: cartSize = 1024;	break; // 8MB
		case 0x0B: cartSize = 2048;	break; // 16MB
		case 0x0C: cartSize = 4096;	break; // 32MB
		case 0x0D: cartSize = 6144;	break; // 48MB
		case 0x0E: cartSize = 8192;	break; // 64MB
		default:   cartSize = 4096;	break; // 32MB
	}

	switch(saveByte){
		case 0x00: saveSize = 0;	break;
		case 0x01: saveSize = 2;	break;
		case 0x02: saveSize = 8;	break;
		case 0x03: saveSize = 8;	break;
		case 0x04: saveSize = 32;	break; // ???
		case 0x05: saveSize = 32;	break; // Star Fox 2
		case 0x06: saveSize = 32;	break; // Marvelous (J)
		case 0x07: saveSize = 32;	break; // Kaite Tukutte Asoberu Dezaemon (J)
		case 0x08: saveSize = 32;	break; // Air Management - Oozora ni Kakeru (J) (V1.1) [!]
		case 0x12: saveSize = 32;	break; // Super Power League 2 (J) (V1.1) [!]
		default:   saveSize = 32;	break;
	}

	[console addText:[NSString stringWithFormat:@"Cart Size: %d\n", cartSize]];
	[console addText:[NSString stringWithFormat:@"Save Size: %d\n", saveSize]];

	// Done
	free(buffer3);
	free(buffer2);
	free(buffer1);

	return cartBanking;
}

- (BOOL) writeEEPROM:(NSString *)fileName{
	sleep(3);
	[console addText:@"Writing EEPROM Setting...\n"];
	unsigned char eedata[128];
	int bytes;

	// Set Config Bits
	eedata[0] = 0;

	if(cartBanking)			eedata[0] |= 0x10;	// AddrMode = 0x10
	if(saveSize == 2)		eedata[0] |= 0x20;	// SaveRAMEnable = 0x20
	else if(saveSize == 8)	eedata[0] |= 0x60;	// SaveRAMMask1 = 0x40
	else if(saveSize == 32)	eedata[0] |= 0xE0;	// SaveRAMMask2 = 0x80

	[console addText:[NSString stringWithFormat:@"EEPROM Save: 0x%02x\n", eedata[0]]];

	if(![fileName isEqualToString:@""]){
		int i;
		for(i = 0; i < 128; i++){
			if(i < ([[fileName lastPathComponent] length] - 4)){
				eedata[i+1] = [[fileName lastPathComponent] characterAtIndex:i];
//				NSLog(@"eedata[%d+1] = %c", i, [[fileName lastPathComponent] characterAtIndex:i]);
			}
			else if(i == ([[fileName lastPathComponent] length] - 4)){
				eedata[i+1] = 0;
			}
			else{
				eedata[i+1] = -1;
			}
		}
		bytes = 128;
	}
	else{
		bytes = 1;
	}

	if([self writeEE:eedata bytes:bytes] == FALSE){
		[console addText:@"ERROR: Could not write EEPROM!\n"];
		return FALSE;
	}

	[console addText:[NSString stringWithFormat:@"Wrote %d byte EEPROM!\n", bytes]];
	return TRUE;
}

- (BOOL) readEEPROM{
	unsigned char *eedata = (unsigned char*)malloc(128);
	[self readEE:eedata bytes:128];
	int i = 0;
	eedata[127] = 0;

	NSData *bufferA = [NSData dataWithBytes:eedata length:128];
	[console addText:[NSString stringWithFormat:@"%@\n", [bufferA description]]];

	if((eedata[1] != 0x00) && (eedata[1] != 0xFF)){
		//Decode SaveRAM size
		if ((eedata[0] & 0xE0) == 0x20)			i = 2;
		else if ((eedata[0] & 0xE0) == 0x60)	i = 8;
		else if ((eedata[0] & 0xE0) == 0xE0)	i = 32;
		else									i = 0;

	//	NSLog(@"Filename:   %s", &eedata[1]);
	//	NSLog(@"Mode:       %s", ((eedata[0] & 0x10) ? "HIROM" : "LOROM") );
	//	NSLog(@"SaveRAM:    %d kB", i);

		//Autodetect from EEPROM
		cartBanking = (eedata[0] & 0x10) ? TRUE : FALSE;
//		saveramsize = i;
		
//		autodetect = FALSE;
	}
	else{
		[console addText:@"No EEPROM Detected!\n"];
	}
	return FALSE;
}

- (BOOL) flashDetect{
	sleep(5);
	int i = 0;

//	cartBanking = TRUE;

	unsigned char command[128];
	unsigned char results[2];

	FlashChipCode flashChipCodes[] = {
		{"Atmel AT49BV322D",  0x1F, 0xC8, TRUE},
		{"Atmel AT49BV322DT", 0x1F, 0xC9, FALSE},
		{"Spansion S29JL032H-21", 0x01, 0x55, FALSE}, //Top
		{"Spansion S29JL032H-31", 0x01, 0x50, FALSE},
		{"Spansion S29JL032H-41", 0x01, 0x5C, FALSE},
		{"Spansion S29JL032H-22", 0x01, 0x56, TRUE}, //Bottom
		{"Spansion S29JL032H-32", 0x01, 0x53, TRUE},
		{"Spansion S29JL032H-42", 0x01, 0x5F, TRUE},
		{"Winbond W19B320AB", 0xDA, 0x7E, TRUE}
	};

	// Write Flash Commands
	i = 0;
	command[i++] = 'C';
	command[i++] = 0;
	
	command[i++] = 'C'; //Product ID mode
	command[i++] = 1;
	command[i++] = 'w';
	command[i++] = 0xAA;
	command[i++] = 0x8A;
	command[i++] = 0x00;
	command[i++] = 0xAA;
	command[i++] = 'C';
	command[i++] = 0;
	
	command[i++] = 'C';
	command[i++] = 1;
	command[i++] = 'w';
	command[i++] = 0x55;
	command[i++] = 0x85;
	command[i++] = 0x00;
	command[i++] = 0x55;
	command[i++] = 'C';
	command[i++] = 0;
	
	command[i++] = 'C';
	command[i++] = 1;
	command[i++] = 'w';
	command[i++] = 0xAA;
	command[i++] = 0x8A;
	command[i++] = 0x00;
	command[i++] = 0x90;
	command[i++] = 'C';
	command[i++] = 0;
	
	command[i++] = 'C';	//Read Codes
	command[i++] = 1;
	command[i++] = 'r'; 
	command[i++] = 0x00; //Manufacturer
	command[i++] = 0x80;
	command[i++] = 0x00;
	command[i++] = 'C';
	command[i++] = 0;
	
	command[i++] = 'C';
	command[i++] = 1;
	command[i++] = 'r'; 
	command[i++] = 0x02; //Device
	command[i++] = 0x80;
	command[i++] = 0x00;
	command[i++] = 'C';
	command[i++] = 0;
	
	command[i++] = 'C'; //Exit Product ID
	command[i++] = 1;
	command[i++] = 'w';
	command[i++] = 0x00;
	command[i++] = 0x80;
	command[i++] = 0x00;
	command[i++] = 0xF0;
	command[i++] = 'C';
	command[i++] = 0;

	[self writeBytes:command bytes:i];
	[self readBytes:results bytes:2];

	// Find chip using ID
	flashChip = 999;

	for(i = 0; i < 9; i++){
//		NSLog(@"Found: %02x %02x", results[0], results[1]);
//		NSLog(@"Maybe: %02x %02x", flashChipCodes[i].manufacturer, flashChipCodes[i].device);
		if((results[0] == flashChipCodes[i].manufacturer) && (results[1] == flashChipCodes[i].device)){
			flashChip = i;
			break;
		}
	}

	if(flashChip == 999){
		[console addText:@"ERROR: No flash chip detected\n"];
		return FALSE;
	}

	[console addText:[NSString stringWithFormat:@"Found %s\n", flashChipCodes[flashChip].chipname]];

	// Set up writing protocol
	command[0] = 'G';
	command[1] = 0xAA; // flashcmd0addr0
	command[2] = 0x8A; // flashcmd0addr1
	command[3] = 0x00; // flashcmd0addr2
	command[4] = 0xAA; // flashcmd0data

	command[5] = 0x55; //flashcmd1
	command[6] = 0x85;
	command[7] = 0x00;
	command[8] = 0x55;

	command[9] = 0xAA; //flashcmd2
	command[10] = 0x8A;
	command[11] = 0x00;
	command[12] = 0xA0;

	[self writeBytes:command bytes:13];

	return TRUE;
}

// Erases FLASH memory. May take up to a minute
- (BOOL) flashErase:(int)romsize{
	int i;
	int addr;
	int error = 0;
//	long starttime;

	FlashChipCode flashChipCodes[] = {
		{"Atmel AT49BV322D",  0x1F, 0xC8,  TRUE},
		{"Atmel AT49BV322DT", 0x1F, 0xC9,  FALSE},
		{"Spansion S29JL032H-21", 0x01, 0x55,  FALSE}, //Top
		{"Spansion S29JL032H-31", 0x01, 0x50,  FALSE},
		{"Spansion S29JL032H-41", 0x01, 0x5C,  FALSE},
		{"Spansion S29JL032H-22", 0x01, 0x56,  TRUE}, //Bottom
		{"Spansion S29JL032H-32", 0x01, 0x53,  TRUE},
		{"Spansion S29JL032H-42", 0x01, 0x5F,  TRUE},
		{"Winbond W19B320AB", 0xDA, 0x7E,  TRUE}
	};

	[console addText:@"Flash Erase...\n"];
//	starttime = TickCount();

	if(1 || (cartBanking) || (romsize > 3*1024*1024) || (romsize == 0)){
		// Chip Erase
		// MUST DO THIS FOR HIROM, because of the way A15 is decoded
		if([self flashEraseCommand:0 chipErase: TRUE] == 0){
			[console addText:@"ERROR: Error erasing flash!\n"];
			return FALSE;
		}
	}
	else{
		// Sector Erase
		addr = 0;
		// 8k Bottom Sectors (64k in total)
		[console addText:@"8k Bottom Sectors (64k in total)\n"];
		if(flashChipCodes[flashChip].bottomBoot){
			for(i = 0; i < FLASH_BOOT_8K; i++){
				if([self flashEraseCommand:addr chipErase: FALSE] == 0){
					error = 1;
					break;
				}
				addr += 8*1024;
			}
			if(error){
				[console addText:@"ERROR: Error erasing flash!\n"];
				return 0;
			}
		}

		// 64k Sectors
		[console addText:@"64k Sectors\n"];
		for(i = 0; i < FLASH_MIDDLE_64K; i++){
			if([self flashEraseCommand:addr chipErase:FALSE] == 0){
				error = 1;
				break;
			}
			addr += 64*1024;
			// Only check size for 64k sectors
			// Always go one sector over, so size can be autodetected
			if(addr > romsize){
				break;
			}
		}
		if(error){
			[console addText:@"ERROR: Error erasing flash!\n"];
			return 0;
		}
		// Will never have to erase the top 8k sectors. Just use chip erase!
	}
	// Done
//	NSLog(@"Done! %d Seconds", (TickCount() - starttime) / 1000);
	return TRUE;
}

- (BOOL) flashEraseCommand:(int)addr chipErase:(BOOL)chiperase{
//	NSLog(@"Flash Erase Command...");
	int i;
	long starttime;
	unsigned char cmd;
	unsigned char command[64];

	if(chiperase){
		addr = 0x008AAA;
		cmd = 0x10;
	}
	else{
		// Sector Erase address decoding (LOROM only!)
		addr = ((addr & 0xFFFF8000) << 1) | 0x008000 | (addr & 0x00007FFF);
		cmd = 0x30;
	}

	//--- Write Flash Commands
	i = 0;
	command[i++] = 'C';
	command[i++] = 0;

	command[i++] = 'C'; //Chip Erase command. From the datasheet
	command[i++] = 1;
	command[i++] = 'w';
	command[i++] = 0xAA;
	command[i++] = 0x8A;
	command[i++] = 0x00;
	command[i++] = 0xAA;
	command[i++] = 'C';
	command[i++] = 0;
	
	command[i++] = 'C';
	command[i++] = 1;
	command[i++] = 'w';
	command[i++] = 0x55;
	command[i++] = 0x85;
	command[i++] = 0x00;
	command[i++] = 0x55;
	command[i++] = 'C';
	command[i++] = 0;
	
	command[i++] = 'C';
	command[i++] = 1;
	command[i++] = 'w';
	command[i++] = 0xAA;
	command[i++] = 0x8A;
	command[i++] = 0x00;
	command[i++] = 0x80;
	command[i++] = 'C';
	command[i++] = 0;
	
	command[i++] = 'C';
	command[i++] = 1;
	command[i++] = 'w';
	command[i++] = 0xAA;
	command[i++] = 0x8A;
	command[i++] = 0x00;
	command[i++] = 0xAA;
	command[i++] = 'C';
	command[i++] = 0;
	
	command[i++] = 'C';
	command[i++] = 1;
	command[i++] = 'w';
	command[i++] = 0x55;
	command[i++] = 0x85;
	command[i++] = 0x00;
	command[i++] = 0x55;
	command[i++] = 'C';
	command[i++] = 0;
	
	command[i++] = 'C';
	command[i++] = 1;
	command[i++] = 'w';
	command[i++] = addr & 0xFF;
	command[i++] = (addr >> 8) & 0xFF;
	command[i++] = (addr >> 16) & 0xFF;
	command[i++] = cmd;
	command[i++] = 'C';
	command[i++] = 0;
	
	[self writeBytes:command bytes:i];

	// Data Polling
	command[0] = 'C';
	command[1] = 1;
	command[2] = 'r';
	command[3] = addr & 0xFF;
	command[4] = (addr >> 8) & 0xFF;
	command[5] = (addr >> 16) & 0xFF;
	command[6] = 'C';
	command[7] = 0;

	starttime= TickCount();
	int seconds = 0;

	while(1){
		sleep(5);
		if((TickCount() - starttime) >= 1000){
			seconds++;
			starttime += 1000;
//			printf(".");
		}

		[self writeBytes:command bytes:8];
		[self readBytes:&command[32] bytes:1];

		// Check Result
		if(command[32] == 0xFF){
//			NSLog(@"Checked Result: %02x", command[32]);
//			printf(".");
			break;
		}

		// Check Timeout
		if(chiperase){
			if(seconds >= 120){
				return 0;
			}
		}
		else{
			if(seconds >= 15){
				return 0;
			}
		}
	}
//	NSLog(@"Flash Erase Command sent!");
	return TRUE;
}

// Programs Flash memory using contents of file. May take up to a minute
// This function uses CROMReader to support different formats
- (BOOL)flashROM:(NSString *)fileName{
	int i;
	int kbread;
	BOOL error;

	unsigned int addr = 0;
	unsigned char *buffer = (unsigned char*)malloc(32*1024);
	unsigned char command[32];

	[console addText:@"Flashing ROM...\n"];

	// Flash Data
//	long starttime = TickCount();
	kbread = 0;
	error = FALSE;

	NSData *myROM = [NSData dataWithContentsOfFile:fileName];
//	NSData *myBuffer;
//	NSLog(@"%@", [myROM description]);
	do{
		if(cartBanking){
//			NSLog(@"HiROM");
			addr = ((kbread * 1024) | 0x400000);
			if(kbread == 0) addr = 0x400000;
		}
		else{
			// Skip every other 32k
//			NSLog(@"LoROM");
			addr = ((kbread * 2 * 1024) | 0x008000);
//			NSLog(@"0x%x = ((%i * 2 * 1024) | 0x008000)", addr, kbread);
		}

//		NSLog(@"0x%x = (%i * 1024) | 0x400000", addr, kbread);
//		NSLog(@"...at 0x%x", addr);

		// Flash Write
		for(i = 0; i < 32; i++){
			// Read Data
			int location = ((kbread + i) * 1024);
			if(kbread == 0 && i == 0) location = 0;
//			NSLog(@"%x = ((%d + 1) * 1024)", location, kbread);
			[myROM getBytes:buffer range:NSMakeRange(location, 1024)];
//			myBuffer = [NSData dataWithBytes:buffer length:1024];
//			NSLog(@"%@", [myBuffer description]);

			command[0] = 'F'; // Flash
			command[1] = addr & 0xFF;
			command[2] = (addr >> 8) & 0xFF;
			command[3] = (addr >> 16) & 0xFF;

			[self writeBytes:command bytes:4];
			[self writeBytes:buffer bytes:1024];

//			[console addText:[NSString stringWithFormat:@"Wrote to 0x%x\n", addr]];
			addr += 1024;
		}

		// Read result codes
		[self readBytes:command bytes:32];
		kbread += 32;
		[console addText:[NSString stringWithFormat:@"Read %dKB... of %dKB\n", kbread, cartSize]];

//		myBuffer = [NSData dataWithBytes:command length:32];
//		NSLog(@"%@", [myBuffer description]);

		// Check for errors. Should all be dots
		for(i = 0; i < 32; i++){
			if(command[i] != '.'){
			//	NSLog(@"Error: %c", command[i]);
				error = TRUE;
			}
		}

		if(error){
			[console addText:@"Failed to FlashROM!\n"];
			free(buffer);
			return FALSE;
		}
	}while(kbread < cartSize);

//	NSLog("Done! %d Seconds", (TickCount() - starttime) / 1000);
	free(buffer);
	return TRUE;
}

// Reads contents of ROM cartridge into outfile. kbytes is the size to read, 0 to autodetect
// Returns number of kB read, 0 for error
- (int) readROM:(NSString *)fileName kbytes:(int)kbytes{
	int i;
	int kbread;
	unsigned int addr;
	
	unsigned char *buffer = (unsigned char*)malloc(32*1024);
	unsigned char *firstdata = NULL;
	unsigned char command[4];
	
	[console addText:@"Reading ROM...\n"];
	
	// Read ROM Data
	command[0] = 'C'; //Set CS
	command[1] = 1;
	
	[self writeBytes: command bytes: 2];
	
	kbread = 0;
	
	NSMutableData *outData = [NSMutableData dataWithCapacity:1];
	
	do{
		// Read 32kb at a time
		if(cartBanking)	addr = (kbread * 1024) | 0x400000;
		else			addr = (kbread * 2 * 1024) | 0x008000; // Skip every other 32k
		
		// Send Commands
		for(i = 0; i < 32; i++){
			command[0] = 'R'; // Autoread
			command[1] = addr & 0xFF;
			command[2] = (addr >> 8) & 0xFF;
			command[3] = (addr >> 16) & 0xFF;
			
			[self writeBytes: command bytes: 4];
			
			addr += 1024;
		}
		
		// Read Data
		[self readBytes:buffer bytes: (32 * 1024)];
		
		kbread += 32;
		
		// Autodetect Size - Check for mirror or empty data
		if(kbytes == 0){
			// Save first 32kbytes for later
			if(firstdata == NULL){
				firstdata = (unsigned char*)malloc(32*1024);
				memcpy(firstdata, buffer, 32*1024);
			}
			
			// Check on size boundries
			if( (kbread == (256+32)) || (kbread == (512+32)) || (kbread == (1024+32)) || (kbread == (1536+32)) || (kbread == (2048+32)) || (kbread == (3072+32)) ){
				BOOL check = TRUE;
				// Check for all 0s, all 1s or mirror of first 32k
				for(i = 0; i < 32 * 1024; i++){
					if((buffer[i] != firstdata[i]) && (buffer[i] != 0x00) && (buffer[i] != 0xFF)){
//						NSLog(@"Not a mirror, and not open bus");
						// Not a mirror, and not open bus
						check = FALSE;
						break;
					}
				}
				// The End
				if(check){
//					NSLog(@"The End");
					kbread -= 32;
					break;
				}
			}
		}
		[outData appendBytes:buffer length:(32 * 1024)];
		//		fwrite(buffer, 1, 32*1024, f);
		//		printf(".");
		
		// Check size limit (4MB max)
		if((kbytes) && (kbread >= kbytes)){
//			NSLog(@"Size limit reached!");
			break;
		}
	}while(kbread < kbytes);
	//	}while(kbread < 5120);
	
	// Save to file
	[outData writeToFile:fileName atomically:YES];
	
	command[0] = 'C'; //Set CS
	command[1] = 0;
	
	[self writeBytes: command bytes: 2];
	
	[console addText:[NSString stringWithFormat:@"Read %d kB\n", kbread]];

	if(firstdata) free(firstdata);
	free(buffer);

	return kbread;
}

// Reads SaveRAM to outfile. Autodetects the size
- (BOOL) readSaveFile:(NSString *)fileName{
	int i;
	int savesize;
	unsigned int addr;
	
	unsigned char *buffer = (unsigned char*)malloc(32*1024); //MAX SIZE
	unsigned char command[32];
	
	[console addText:@"Reading Save RAM...\n"];
	
	NSMutableData *outData = [NSMutableData dataWithCapacity:1];
	
	// Read SaveRAM
	if(cartBanking){
		addr = 0x306000;
		savesize = 8*1024;
		
		command[0] = 'C'; //NO CS
		command[1] = 0;
	}
	else{
		addr = 0x700000;
		savesize = 32*1024;
		
		command[0] = 'C'; //Yes CS
		command[1] = 1;
	}
	
	[self writeBytes:command bytes: 2];
	
	// Read Commands
	for(i = 0; i < savesize; i += 1024){
		command[0] = 'R'; //Autoread
		command[1] = addr & 0xFF;
		command[2] = (addr >> 8) & 0xFF;
		command[3] = (addr >> 16) & 0xFF;
		
		[self writeBytes:command bytes: 4];
		
		addr += 1024;
	}
	
	// Read Data
	[self readBytes:buffer bytes:savesize];
	
	// Determine Size
	while(savesize > 2048){
		i = savesize / 2;
		if(memcmp(&buffer[0], &buffer[i], i) == 0) savesize = i;
		else break;
	}
	
	// Write to file
	[outData appendBytes:buffer length:savesize];
	[outData writeToFile:fileName atomically:YES];
	
	[console addText:[NSString stringWithFormat:@"Read %d Bytes\n", savesize]];
	
	command[0] = 'C'; //Set CS
	command[1] = 0;
	
	[self writeBytes:command bytes: 2];
	
	return savesize;
}

// Reads SaveRAM from infile and writes to cartridge
- (BOOL) writeSaveFile:(NSString *)fileName{
	int i;
	int savesize;
	unsigned int addr;
	unsigned char *buffer = (unsigned char*)malloc(32*1024);
	unsigned char command[4];

	[console addText:@"Writing Save RAM...\n"];

	// Read File
	NSData *mySave = [NSData dataWithContentsOfFile:fileName];
	[mySave getBytes:buffer];

//	fseek(f, 0, SEEK_END);
	savesize = (int)[mySave length];
//	fseek(f, 0, SEEK_SET);
	savesize = (savesize + 0x3FF) & ~0x3FF; // Multiple of 1k

	if(savesize > 32*1024){
		savesize = 32*1024;
	}


	// Write Data
	if(cartBanking){
		addr = 0x306000;
		if(savesize > 8192){
			savesize = 8192;
		}
		command[0] = 'C'; // NO CS
		command[1] = 0;
	}
	else{
		addr = 0x700000;
		command[0] = 'C'; // Set CS
		command[1] = 1;
	}

	[self writeBytes:command bytes:2];

	// Write Commands
	for(i = 0; i < savesize; i += 1024){
		command[0] = 'W'; //Autowrite
		command[1] = addr & 0xFF;
		command[2] = (addr >> 8) & 0xFF;
		command[3] = (addr >> 16) & 0xFF;

		[self writeBytes:command bytes:4];
		[self writeBytes:(buffer + i) bytes:1024];

		addr += 1024;
	}

	command[0] = 'C'; // Set CS
	command[1] = 0;

	[self writeBytes:command bytes:2];

	[console addText:[NSString stringWithFormat:@"Wrote %d Bytes\n", savesize]];

	// Close
	free(buffer);

	return TRUE;
}

// Fills SaveRAM with all 0s
- (BOOL) clearSave{
	[console addText:@"Clear Save...\n"];
	int i;
	int savesize;
	int addr;
	unsigned char *buffer;
	unsigned char command[4];

	// Write Data
	buffer = (unsigned char*)malloc(1024);
	memset(buffer, 0, 1024);

	if(cartBanking){
		addr = 0x306000;
		savesize = 8*1024;
		command[0] = 'C'; //NO CS
		command[1] = 0;
	}
	else{
		addr = 0x700000;
		savesize = 32*1024;
		command[0] = 'C'; //Set CS
		command[1] = 1;
	}

	[self writeBytes:command bytes:2];

	// Write Commands
	for(i = 0; i < savesize; i += 1024){
		command[0] = 'W'; // Autowrite
		command[1] = addr & 0xFF;
		command[2] = (addr >> 8) & 0xFF;
		command[3] = (addr >> 16) & 0xFF;

		[self writeBytes:command bytes:4];
		[self writeBytes:buffer bytes:1024]; // 1K of zeros

		addr += 1024;
	}

	command[0] = 'C'; //Set CS
	command[1] = 0;

	[self writeBytes:command bytes:2];

	free(buffer);

	return TRUE;
}

// Send junk bytes, in case it was reset in the middle of a write
- (BOOL) sendJunk{
	int i;
	unsigned char command[32];

	memset(command, 0, 32);

	for(i = 0; i < 32; i++){
		[self writeBytes: command bytes: 32];
	}

	return TRUE;
}

// Makes IRQn go high, disabling EEPROM writing till poweroff
- (void) disableEE{
	[console addText:@"Disable EEPROM Writing!\n"];
	unsigned char command[2];
	command[0] = 'C';
	command[1] = 2;
	
	[self writeBytes:command bytes:2];
	sleep(1);
}

// Sends 1 bit of data to EEPROM using Address bus
// read = 1 to read back the bit later
// Uses a side channel to access the EEPROM
- (BOOL) sendEEBit:(int)bit read:(int)read{
	// EECLK_Out <= BUS_A12; 0x10
	// EECS_Out <= BUS_A13; 0x20
	// EEDIN_Out <= BUS_A14; 0x40
	int i;
	unsigned char command[16];
	command[0] = 'w';	// Write with A15=1, A11=0 and CS disabled
	command[1] = 0x00;
	command[2] = 0xA0;	// CLK=0, CS=1, DIN=0
	command[3] = 0x00;
	command[4] = 0x00;
	command[5] = 'w';
	command[6] = 0x00;
	command[7] = 0xB0;	// CLK=1, CS=1, DIN=0
	command[8] = 0x00;
	command[9] = 0x00;
	command[10] = 'S';	// Get RST (EE_DOUT)

	if(bit){
		command[2] |= 0x40; // Set DIN
		command[7] |= 0x40;
	}

	if(read)	i = 11;
	else		i = 10; // Skip last command

	[self writeBytes:command bytes:i];

	return TRUE;
}

// Reads a number of bytes from the EEPROM. Not too fast :(
// Commands from 93C46 datasheet
- (BOOL) readEE:(unsigned char *)data bytes:(int)bytes{
	int i, n;
	unsigned char c;
	unsigned char bits[8];
	unsigned char command[8];

	[console addText:@"Reading EEPROM...\n"];

	if(bytes > 128) bytes = 128;

	// CS disabled
	command[0] = 'C';
	command[1] = 0;

	[self writeBytes:command bytes:2];

	// READ
	[self sendEEBit:1 read:0]; // START
	[self sendEEBit:1 read:0]; // CMD1
	[self sendEEBit:0 read:0]; // CMD0
	[self sendEEBit:0 read:0]; // A6
	[self sendEEBit:0 read:0]; // A5
	[self sendEEBit:0 read:0]; // A4
	[self sendEEBit:0 read:0]; // A3
	[self sendEEBit:0 read:0]; // A2
	[self sendEEBit:0 read:0]; // A1
	[self sendEEBit:0 read:0]; // A0

	for(i = 0; i < bytes; i++){
		// Read data bits
		for(n = 0; n < 8; n++){
			[self sendEEBit:0 read:1];
		}

		// Get bits and decode
		[self readBytes:bits bytes:8];

		c = 0;
		for(n = 0; n < 8; n++){
			c <<= 1;
			c |= bits[n] & 0x01;
		}
		data[i] = c;
	//	NSLog(@"%x ", c);
	}

	// FINISH
	command[0] = 'w';
	command[1] = 0x00;
	command[2] = 0x80; // CLK=0, CS=0, DIN=0
	command[3] = 0x00;
	command[4] = 0x00;

	[self writeBytes:command bytes:5];

	return TRUE;
}

// Writes a number of bytes to the EEPROM
// Commands from 93C46 datasheet
- (BOOL) writeEE:(unsigned char *)data bytes:(int)bytes{
	int i;
	int timeout;

	unsigned char command[16];

	[console addText:@"Writing to EEPROM...\n"];

	if(bytes > 128) bytes = 128;

	// CS disabled
	command[0] = 'C';
	command[1] = 0;

	[self writeBytes:command bytes:2];

	// WRITE ENABLE
	[self sendEEBit:1 read:0]; // START
	[self sendEEBit:0 read:0]; // CMD1
	[self sendEEBit:0 read:0]; // CMD0
	[self sendEEBit:1 read:0]; // A6
	[self sendEEBit:1 read:0]; // A5
	[self sendEEBit:0 read:0]; // A4
	[self sendEEBit:0 read:0]; // A3
	[self sendEEBit:0 read:0]; // A2
	[self sendEEBit:0 read:0]; // A1
	[self sendEEBit:0 read:0]; // A0

	command[0] = 'w';
	command[1] = 0x00;
	command[2] = 0x80; // CLK=0, CS=0, DIN=0 (lower CS)
	command[3] = 0x00;
	command[4] = 0x00;

	[self writeBytes:command bytes:5];

	// ERASE ALL BYTES
	[console addText:@"Erasing EEPROM...\n"];
	for(i = 0; i < bytes; i++){
		// ERASE
		[self sendEEBit:1 read:0]; //START
		[self sendEEBit:1 read:0]; //CMD1
		[self sendEEBit:1 read:0]; //CMD0
		[self sendEEBit:(i & 0x40) read: 0]; //A6
		[self sendEEBit:(i & 0x20) read: 0]; //A5
		[self sendEEBit:(i & 0x10) read: 0]; //A4
		[self sendEEBit:(i & 0x08) read: 0]; //A3
		[self sendEEBit:(i & 0x04) read: 0]; //A2
		[self sendEEBit:(i & 0x02) read: 0]; //A1
		[self sendEEBit:(i & 0x01) read: 0]; //A0

		command[0] = 'w';
		command[1] = 0x00;
		command[2] = 0x80; //CLK=0, CS=0, DIN=0 (start erase cycle)
		command[3] = 0x00;
		command[4] = 0x00;
		command[5] = 'w';
		command[6] = 0x00;
		command[7] = 0xA0; //CLK=0, CS=1, DIN=0 (raise CS to get status)
		command[8] = 0x00;
		command[9] = 0x00;

		[self writeBytes:command bytes:10];

		// Wait for it to be done
		timeout = 0;
		do{
			timeout++;

			// Takes 5ms to erase a byte
			if(timeout >= 200){
				[console addText:@"ERROR: Timed Out!\n"];
				return FALSE;
			}

			command[0] = 'S';

			[self writeBytes:command bytes:1];
			[self readBytes:command bytes:1];
		}while((command[0] & 0x01) == 0);

		command[0] = 'w';
		command[1] = 0x00;
		command[2] = 0x80; //CLK=0, CS=0, DIN=0 (lower CS)
		command[3] = 0x00;
		command[4] = 0x00;

		[self writeBytes:command bytes:5];
	}

	// WRITE
	[console addText:@"Writing new EEPROM...\n"];

	for(i=0; i < bytes; i++){
		if(data[i] == 0xFF) continue;

		//WRITE
		[self sendEEBit:(1) read: 0]; //START
		[self sendEEBit:(0) read: 0]; //CMD1
		[self sendEEBit:(1) read: 0]; //CMD0

		[self sendEEBit:(i & 0x40) read: 0]; //A6
		[self sendEEBit:(i & 0x20) read: 0]; //A5
		[self sendEEBit:(i & 0x10) read: 0]; //A4
		[self sendEEBit:(i & 0x08) read: 0]; //A3
		[self sendEEBit:(i & 0x04) read: 0]; //A2
		[self sendEEBit:(i & 0x02) read: 0]; //A1
		[self sendEEBit:(i & 0x01) read: 0]; //A0

		[self sendEEBit:(data[i] & 0x80) read: 0]; //D7
		[self sendEEBit:(data[i] & 0x40) read: 0]; //D6
		[self sendEEBit:(data[i] & 0x20) read: 0]; //D5
		[self sendEEBit:(data[i] & 0x10) read: 0]; //D4
		[self sendEEBit:(data[i] & 0x08) read: 0]; //D3
		[self sendEEBit:(data[i] & 0x04) read: 0]; //D2
		[self sendEEBit:(data[i] & 0x02) read: 0]; //D1
		[self sendEEBit:(data[i] & 0x01) read: 0]; //D0

		command[0] = 'w';
		command[1] = 0x00;
		command[2] = 0x80; //CLK=0, CS=0, DIN=0 (start write cycle)
		command[3] = 0x00;
		command[4] = 0x00;
		command[5] = 'w';
		command[6] = 0x00;
		command[7] = 0xA0; //CLK=0, CS=1, DIN=0 (raise CS to get status)
		command[8] = 0x00;
		command[9] = 0x00;

		[self writeBytes:command bytes:10];

		// Wait for it to be done
		do{
			command[0] = 'S';
			[self writeBytes:command bytes:1];
			[self readBytes:command bytes:1];
		}while((command[0] & 0x01) == 0);

		command[0] = 'w';
		command[1] = 0x00;
		command[2] = 0x80; //CLK=0, CS=0, DIN=0 (lower CS)
		command[3] = 0x00;
		command[4] = 0x00;

		[self writeBytes:command bytes:5];
	}

	// Reset EEPROM State Machine
	// So it gets into the new ROM mode
	[console addText:@"Reset EEPROM State Machine...\n"];
	command[0] = 'w'; 
	command[1] = 0x00;
	command[2] = 0x88; //A11=1 means reset
	command[3] = 0x00;
	command[4] = 0x00;
	command[5] = 'S'; //Wait for it to finish resetting
	command[6] = 'S';
	command[7] = 'S';
	command[8] = 'S';
	command[9] = 'S';
	command[10] = 'S';
	command[11] = 'S';
	command[12] = 'S';

	[self writeBytes:command bytes:13];
	[self readBytes:command bytes:8];

	return TRUE;
}

@end
