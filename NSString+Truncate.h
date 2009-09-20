#import <Cocoa/Cocoa.h>

@interface NSString (Truncate)

enum {
	NSTruncateStart		= 1,
	NSTruncateMiddle	= 2,
	NSTruncateEnd		= 3
};


- (NSString *)stringWithTruncatingToLength:(unsigned)length;
- (NSString *)stringTruncatedToLength:(unsigned int)length direction:(unsigned)truncateFrom;
- (NSString *)stringTruncatedToLength:(unsigned int)length direction:(unsigned)truncateFrom withEllipsisString:(NSString *)ellipsis;

@end
