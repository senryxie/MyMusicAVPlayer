//
//  SXViewController.h
//  MyMusicAVPlayer
//
//  Created by Senry Xie on 12-7-20.
//  Copyright (c) 2012年 Sogou. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface SXViewController : UIViewController
{
    NSInteger currentSong;
	BOOL isSeeking;
	BOOL seekToZeroBeforePlay;
	float restoreAfterScrubbingRate;
}

@property (retain) IBOutlet UIToolbar *toolBar;
@property (retain) IBOutlet UIBarButtonItem *playButton;
@property (retain) IBOutlet UIBarButtonItem *stopButton;
@property (retain) IBOutlet UIBarButtonItem *nextButton;
@property (retain) IBOutlet UIBarButtonItem *preButton;
@property (retain) IBOutlet UISlider *musicTimeControl;
@property (retain) AVPlayer *player;
@property (retain) AVPlayerItem *playerItem;
@property (retain) NSMutableArray *allMusicArray;
@property (retain) id timeObserver;

- (void)loadPlayItemWithURL:(NSURL *)url;

- (IBAction)beginScrubbing:(id)sender;
- (IBAction)scrub:(id)sender;
- (IBAction)endScrubbing:(id)sender;

- (IBAction)play:(id)sender;
- (IBAction)pause:(id)sender;
- (IBAction)next:(id)sender;
- (IBAction)previous:(id)sender;

@end
