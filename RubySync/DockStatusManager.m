//
//  AppDelegate.m
//  RubySync
//
//  Created by Paolo Bosetti on 6/11/11.
//  Copyright 2011 Dipartimento di Ingegneria Meccanica e Strutturale. All rights reserved.
//

#import "DockStatusManager.h"
#import "Carbon/Carbon.h"

@implementation DockStatusManager

- (id)init
{
    self = [super init];
    if (self) {
        [NSApp activateIgnoringOtherApps:YES];
    }
    
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)a_notification {
	NSBundle *myBundle = [NSBundle bundleForClass:[DockStatusManager class]];
	NSString *growlPath = [[myBundle privateFrameworksPath] stringByAppendingPathComponent:@"Growl.framework"];
	NSBundle *growlBundle = [NSBundle bundleWithPath:growlPath];
  
	if (growlBundle && [growlBundle load]) {
    [GrowlApplicationBridge setGrowlDelegate:self];
    [GrowlApplicationBridge notifyWithTitle:@"RubySync started"
                                description:@"RubySync application successfully started"
                           notificationName:@"RubySync started"
                                   iconData:[NSData data]
                                   priority:0
                                   isSticky:NO
                               clickContext:nil];
  }
	else {
		NSLog(@"ERROR: Could not load Growl.framework");
	}
}

- (void) setDockStatus: (BOOL)doShow {
  // this should be called from the application delegate's applicationDidFinishLaunching
  // method or from some controller object's awakeFromNib method
  // Neat dockless hack using Carbon from <a href="http://codesorcery.net/2008/02/06/feature-requests-versus-the-right-way-to-do-it" title="http://codesorcery.net/2008/02/06/feature-requests-versus-the-right-way-to-do-it">http://codesorcery.net/2008/02/06/feature-requests-versus-the-right-way-...</a>
  //	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"doShowInDock"]) {
  if (doShow) {
    NSLog(@"Setting Dock Status");
		ProcessSerialNumber psn = { 0, kCurrentProcess };
		// display dock icon
		TransformProcessType(&psn, kProcessTransformToForegroundApplication);
		// enable menu bar
		SetSystemUIMode(kUIModeNormal, 0);
		// switch to Dock.app
		[[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:@"com.apple.dock" options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifier:nil];
		// switch back
		[[NSApplication sharedApplication] activateIgnoringOtherApps:TRUE];
	}
}
@end
