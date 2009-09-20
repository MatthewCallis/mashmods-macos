/* Console */

#import <Cocoa/Cocoa.h>

@interface Console : NSWindowController{
	IBOutlet id textView;
}

- (IBAction)clear:(id)sender;

- (void)show;

- (void)addText:(NSString *)notif;

@end
