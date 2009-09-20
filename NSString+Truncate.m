#import <Cocoa/Cocoa.h>

#import "NSString+Truncate.h"

@implementation NSString (Truncate)

- (NSString *)stringWithTruncatingToLength:(unsigned)length {
	return [self stringTruncatedToLength:length direction:NSTruncateStart];
}

- (NSString *)stringTruncatedToLength:(unsigned int)length direction:(unsigned)truncateFrom {
	return [self stringTruncatedToLength:length direction:truncateFrom withEllipsisString:@"…"];
}

- (NSString *)stringTruncatedToLength:(unsigned int)length direction:(unsigned)truncateFrom withEllipsisString:(NSString *)ellipsis{
	NSMutableString *result = [[NSMutableString alloc] initWithString:self];
	NSString *immutableResult;
	if([result length] <= length){
		return self;
	}

	unsigned int charactersEachSide = length / 2;
	NSString *first;
	NSString *last;
	switch(truncateFrom) {
		case NSTruncateStart:
			[result insertString:ellipsis atIndex:length - [ellipsis length]];
			immutableResult  = [[result substringToIndex:length] copy];
			[result release];
			return [immutableResult autorelease];
			break;
		case NSTruncateMiddle:
			first = [result substringToIndex:charactersEachSide - [ellipsis length]+1];
			last = [result substringFromIndex:[result length] - charactersEachSide];
			immutableResult = [[[NSArray arrayWithObjects:first, last, NULL] componentsJoinedByString:ellipsis] copy];
			[result release];
			return [immutableResult autorelease];
			break;
		case NSTruncateEnd:
			[result insertString:ellipsis atIndex:[result length] - length + [ellipsis length] ];
			immutableResult  = [[result substringFromIndex:[result length] - length] copy];
			[result release];
			return [immutableResult autorelease];
	}
}

@end