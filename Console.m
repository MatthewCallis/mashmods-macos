#import "Console.h"

@implementation Console

- (id)init{
	self = [super init];
	[NSBundle loadNibNamed:@"Console" owner:self];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addText:) name:@"ConsoleNotification" object:nil];
	return self;
}

- (void)dealloc{
	[super dealloc];
}

- (void)awakeFromNib{
	[textView setFont:[NSFont fontWithName:@"Monaco" size:10.0]];
	[textView setContinuousSpellCheckingEnabled:NO];
}

- (IBAction)clear:(id)sender{
	NSRange range = NSMakeRange (0, [[[textView textStorage] string] length]);
	[textView setSelectedRange:range];
	[textView delete:nil];
}

- (void)show{
	[[self window] makeKeyAndOrderFront:self];
}

- (void)addText:(NSString *)notif{
//	NSLog(@"%@", notif);
	[textView insertText:notif];
	NSRange range = NSMakeRange([[textView string] length], 0);
	[textView scrollRangeToVisible: range];
}

@end
