//
//  SXViewController.m
//  MyMusicAVPlayer
//
//  Created by Senry Xie on 12-7-20.
//  Copyright (c) 2012年 Sogou. All rights reserved.
//

#import "SXViewController.h"
#import <MediaPlayer/MediaPlayer.h>

static void *MyStreamingMovieViewControllerRateObservationContext = &MyStreamingMovieViewControllerRateObservationContext;
static void *MyStreamingMovieViewControllerCurrentItemObservationContext = &MyStreamingMovieViewControllerCurrentItemObservationContext;
static void *MyStreamingMovieViewControllerPlayerItemStatusObserverContext = &MyStreamingMovieViewControllerPlayerItemStatusObserverContext;

NSString *kTracksKey		= @"tracks";
NSString *kStatusKey		= @"status";
NSString *kRateKey			= @"rate";
NSString *kCurrentItemKey	= @"currentItem";

#pragma mark -
@interface SXViewController ()

- (CMTime)playerItemDuration;
- (BOOL)isPlaying;
- (void)assetFailedToPrepareForPlayback:(NSError *)error;
- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys;

@end

@implementation SXViewController

@synthesize musicTimeControl;
@synthesize player, playerItem, timeObserver;
@synthesize toolBar, playButton, stopButton, nextButton, preButton;
@synthesize allMusicArray;

#pragma mark -
#pragma mark SXViewController methods
#pragma mark -

/* ---------------------------------------------------------
 **  Methods to handle manipulation of the music scrubber control
 ** ------------------------------------------------------- */

#pragma mark Play, Stop Buttons

/* Show the stop button in the movie player controller. */
-(void)showStopButton
{
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[toolBar items]];
    [toolbarItems replaceObjectAtIndex:2 withObject:stopButton];
    toolBar.items = toolbarItems;
}

/* Show the play button in the movie player controller. */
-(void)showPlayButton
{
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[toolBar items]];
    [toolbarItems replaceObjectAtIndex:2 withObject:playButton];
    toolBar.items = toolbarItems;
}

/* If the media is playing, show the stop button; otherwise, show the play button. */
- (void)syncPlayPauseButtons
{
	if ([self isPlaying])
	{
        NSLog(@"isPlaying");
        [self showStopButton];
	}
	else
	{
        NSLog(@"Not Playing");
        [self showPlayButton];        
	}
}

-(void)enablePlayerButtons
{
    self.playButton.enabled = YES;
    self.stopButton.enabled = YES;
    self.preButton.enabled = YES;
    self.nextButton.enabled = YES;
}

-(void)disablePlayerButtons
{
    self.playButton.enabled = NO;
    self.stopButton.enabled = NO;
    self.preButton.enabled = NO;
    self.nextButton.enabled = NO;
}

#pragma mark Scrubber control

/* Set the scrubber based on the player current time. */
- (void)syncScrubber
{
	CMTime playerDuration = [self playerItemDuration];
	if (CMTIME_IS_INVALID(playerDuration)) 
	{
		musicTimeControl.minimumValue = 0.0;
		return;
	}
	
	double duration = CMTimeGetSeconds(playerDuration);
	if (isfinite(duration) && (duration > 0))
	{
		float minValue = [musicTimeControl minimumValue];
		float maxValue = [musicTimeControl maximumValue];
		double time = CMTimeGetSeconds([player currentTime]);
		[musicTimeControl setValue:(maxValue - minValue) * time / duration + minValue];
	}
}

/* Requests invocation of a given block during media playback to update the 
 movie scrubber control. */
-(void)initScrubberTimer
{
    NSLog(@"initScrubberTimer");
	double interval = .1f;	
	
	CMTime playerDuration = [self playerItemDuration];
	if (CMTIME_IS_INVALID(playerDuration)) 
	{
		return;
	} 
	double duration = CMTimeGetSeconds(playerDuration);
	if (isfinite(duration))
	{
		CGFloat width = CGRectGetWidth([musicTimeControl bounds]);
		interval = 0.5f * duration / width;
	}
    
	/* Update the scrubber during normal playback. */
	self.timeObserver = [player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(interval, NSEC_PER_SEC) 
                                                             queue:NULL 
                                                        usingBlock:
                         ^(CMTime time) 
                         {
                             [self syncScrubber];
                         }];
}

/* Cancels the previously registered time observer. */
-(void)removePlayerTimeObserver
{
	if (self.timeObserver)
	{
        NSLog(@"removePlayerTimeObserver");
		[player removeTimeObserver:timeObserver];
		self.timeObserver = nil;
	}
}

/* The user is dragging the movie controller thumb to scrub through the movie. */
- (IBAction)beginScrubbing:(id)sender
{
    NSLog(@"beginScrubbing");
	restoreAfterScrubbingRate = [player rate];
	[player setRate:0.f];
	
	/* Remove previous timer. */
	[self removePlayerTimeObserver];
}

/* The user has released the movie thumb control to stop scrubbing through the movie. */
- (IBAction)endScrubbing:(id)sender
{
    NSLog(@"endScrubbing");
	if (!self.timeObserver)
	{
        NSLog(@"endScrubbing !timeObserver");
		CMTime playerDuration = [self playerItemDuration];
		if (CMTIME_IS_INVALID(playerDuration)) 
		{
			return;
		} 
		
		double duration = CMTimeGetSeconds(playerDuration);
		if (isfinite(duration))
		{
			CGFloat width = CGRectGetWidth([musicTimeControl bounds]);
			double tolerance = 0.5f * duration / width;
            
			self.timeObserver = [player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(tolerance, NSEC_PER_SEC) queue:dispatch_get_main_queue() usingBlock:
                                 ^(CMTime time)
                                 {
                                     [self syncScrubber];
                                 }];
		}
	}
    
	if (restoreAfterScrubbingRate)
	{
		[player setRate:restoreAfterScrubbingRate];
		restoreAfterScrubbingRate = 0.f;
	}
}

/* Set the player current time to match the scrubber position. */
- (IBAction)scrub:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
        NSLog(@"scrub");
		UISlider* slider = sender;
		
		CMTime playerDuration = [self playerItemDuration];
		if (CMTIME_IS_INVALID(playerDuration)) {
			return;
		} 
		
		double duration = CMTimeGetSeconds(playerDuration);
		if (isfinite(duration))
		{
			float minValue = [slider minimumValue];
			float maxValue = [slider maximumValue];
			float value = [slider value];
			
			double time = duration * (value - minValue) / (maxValue - minValue);
			
			[player seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC)];
		}
	}
}

- (BOOL)isScrubbing
{
	return restoreAfterScrubbingRate != 0.f;
}

-(void)enableScrubber
{
    self.musicTimeControl.enabled = YES;
}

-(void)disableScrubber
{
    self.musicTimeControl.enabled = NO;    
}

/* Prevent the slider from seeking during Ad playback. */
- (void)sliderSyncToPlayerSeekableTimeRanges
{		
	NSArray *seekableTimeRanges = [[player currentItem] seekableTimeRanges];
	if ([seekableTimeRanges count] > 0) 
	{
		NSValue *range = [seekableTimeRanges objectAtIndex:0];
		CMTimeRange timeRange = [range CMTimeRangeValue];
		float startSeconds = CMTimeGetSeconds(timeRange.start);
		float durationSeconds = CMTimeGetSeconds(timeRange.duration);
		
		/* Set the minimum and maximum values of the time slider to match the seekable time range. */
		musicTimeControl.minimumValue = startSeconds;
		musicTimeControl.maximumValue = startSeconds + durationSeconds;
	}
}

#pragma mark Button Action Methods
- (void)playOrPause:(id)sender
{
    if ([self isPlaying])
    {
        [self pause:sender];
    }
    else
    {
        [self play:sender];
    }
}

- (IBAction)play:(id)sender
{
	/* If we are at the end of the movie, we must seek to the beginning first 
     before starting playback. */
	if (YES == seekToZeroBeforePlay) 
	{
		seekToZeroBeforePlay = NO;
		[player seekToTime:kCMTimeZero];
	}
    
	[player play];
	
    [self showStopButton];  
}

- (IBAction)pause:(id)sender
{
	[player pause];
    
    [self showPlayButton];
}

- (IBAction)next:(id)sender
{
    if ([self.allMusicArray count]>0)
    {
        currentSong = (currentSong+1)%[self.allMusicArray count];
        NSURL *currenURL = [self.allMusicArray objectAtIndex:currentSong];
        [self removePlayerTimeObserver];
        [self loadPlayItemWithURL:currenURL];
        [self showStopButton];
    }
}

- (IBAction)previous:(id)sender
{
    if ([self.allMusicArray count]>0)
    {
        currentSong = (currentSong+[self.allMusicArray count]-1)%[self.allMusicArray count];
        NSURL *currenURL = [self.allMusicArray objectAtIndex:currentSong];
        [self removePlayerTimeObserver];
        [self loadPlayItemWithURL:currenURL];
        [self showStopButton]; 
    }
}

- (void)loadPlayItemWithURL:(NSURL *)url
{
    if ([url scheme])	/* Sanity check on the URL. */
    {
        /*
         Create an asset for inspection of a resource referenced by a given URL.
         Load the values for the asset keys "tracks", "playable".
         */
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
        
        NSArray *requestedKeys = [NSArray arrayWithObjects:kTracksKey, nil];
        
        /* Tells the asset to load the values of any of the specified keys that are not already loaded. */
        [asset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:
         ^{		 
             dispatch_async( dispatch_get_main_queue(), 
                            ^{
                                /* IMPORTANT: Must dispatch to main queue in order to operate on the AVPlayer and AVPlayerItem. */
                                [self prepareToPlayAsset:asset withKeys:requestedKeys];
                            });
         }];
    }
}

#pragma mark -
#pragma mark View Controller
#pragma mark -
- (void)removeAllMyObservers
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:nil];
    [self.player removeObserver:self forKeyPath:kCurrentItemKey];
    [self.player removeObserver:self forKeyPath:kRateKey];
    if (self.playerItem)
    {
        [self.playerItem removeObserver:self forKeyPath:kStatusKey];            
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:self.playerItem];
    }
}

- (void)dealloc
{
    if ([self isPlaying])
    {
        [self.player pause];
    }
    [self removePlayerTimeObserver];
    [self removeAllMyObservers];
    
    [playerItem release];
	[player release];
	[musicTimeControl release];
	[toolBar release];
	[playButton release];
	[stopButton release];
    [preButton release];
    [nextButton release];
	[allMusicArray release];
    
    [super dealloc];
}

- (void)viewDidUnload
{
    [self removePlayerTimeObserver];
    [self removeAllMyObservers];
    
    currentSong = -1;
    self.musicTimeControl = nil;
    self.allMusicArray = nil;
    self.playerItem = nil;
    
    [super viewDidUnload];
}

- (void)viewDidLoad
{    
    [super viewDidLoad];
    UIBarButtonItem *scrubberItem = [[UIBarButtonItem alloc] initWithCustomView:musicTimeControl];
    UIBarButtonItem *flexItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    toolBar.items = [NSArray arrayWithObjects:preButton, flexItem, playButton, flexItem, nextButton, flexItem, scrubberItem, nil];
    [scrubberItem release];
    [flexItem release];
    
    MPMediaQuery *allMusicQuery = [[MPMediaQuery alloc] init];
    NSLog(@"Logging items from a AnyAudio query...");
    NSNumber *musicTypeNum = [NSNumber numberWithInteger:MPMediaTypeAnyAudio];
    MPMediaPropertyPredicate *musicPredicate = [MPMediaPropertyPredicate predicateWithValue:musicTypeNum forProperty:MPMediaItemPropertyMediaType];
    [allMusicQuery addFilterPredicate: musicPredicate];
    NSArray *musicArray = [allMusicQuery items];
    NSMutableArray *allMusicModelArray = [[NSMutableArray alloc] initWithCapacity:[musicArray count]];
    for (MPMediaItem *song in musicArray)
    {
        NSURL *songUrl = [song valueForProperty: MPMediaItemPropertyAssetURL];
        if (songUrl)
        {
            [allMusicModelArray addObject:songUrl];
            NSLog(@"songUrl:%@",songUrl);
        }
    }
    //These Web music may have copy rights, please DO NOT use them in other ways.
    [allMusicModelArray addObject:[NSURL URLWithString:@"http://wdl.oppo.com/d/files/audio/2009/12/09/092244_4160615.MP3"]];
    [allMusicModelArray addObject:[NSURL URLWithString:@"http://bbs.zj60.com/uploadfile/200551614395641718.mp3?song=&wxc"]];
    NSLog(@"End of items from a AnyAudio query...");
    self.allMusicArray = allMusicModelArray;
    [allMusicModelArray release];
    [allMusicQuery release];
    currentSong = -1;
    if ([self.allMusicArray count]>0)
    {
        currentSong = 0;
        [self loadPlayItemWithURL:[allMusicArray objectAtIndex:currentSong]];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
    /* Supports all orientations. */
    return YES;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    /*Once the view has loaded then we can register to begin recieving controls and we can become the first responder*/
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    /*End recieving events*/
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
}

/*Make sure we can recieve remote control events*/
- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event
{
    /*If it is a remote control event, handle it correctly*/
    if (event.type == UIEventTypeRemoteControl)
    {
        switch (event.subtype)
        {
            case UIEventSubtypeRemoteControlPlay:
                NSLog(@"UIEventSubtypeRemoteControlPlay");
                [self play:nil];
                break;
            case UIEventSubtypeRemoteControlPause:
                NSLog(@"UIEventSubtypeRemoteControlPause");
                [self pause:nil];
                break;
            case UIEventSubtypeRemoteControlTogglePlayPause:
                NSLog(@"UIEventSubtypeRemoteControlTogglePlayPause");
                [self playOrPause:nil];
                break;
            case UIEventSubtypeRemoteControlNextTrack:
                NSLog(@"UIEventSubtypeRemoteControlNextTrack");
                [self next:nil];
                break;
            case UIEventSubtypeRemoteControlPreviousTrack:
                NSLog(@"UIEventSubtypeRemoteControlPreviousTrack");
                [self previous:nil];
                break;
            default:
                NSLog(@"UIEventSubtypeRemoteControl others");
                break;
        }
    }
}

#pragma mark - Player

/* ---------------------------------------------------------
 **  Get the duration for a AVPlayerItem. 
 ** ------------------------------------------------------- */

- (CMTime)playerItemDuration
{
	AVPlayerItem *thePlayerItem = [player currentItem];
	if (thePlayerItem.status == AVPlayerItemStatusReadyToPlay)
	{        
        /* 
         NOTE:
         Because of the dynamic nature of HTTP Live Streaming Media, the best practice 
         for obtaining the duration of an AVPlayerItem object has changed in iOS 4.3. 
         Prior to iOS 4.3, you would obtain the duration of a player item by fetching 
         the value of the duration property of its associated AVAsset object. However, 
         note that for HTTP Live Streaming Media the duration of a player item during 
         any particular playback session may differ from the duration of its asset. For 
         this reason a new key-value observable duration property has been defined on 
         AVPlayerItem.
         
         See the AV Foundation Release Notes for iOS 4.3 for more information.
         [playerItem duration] is Available since iOS 4.3, so I use [[playerItem asset] duration]
         to get item's duration
         */		
        
		return([[playerItem asset] duration]);
	}
    
	return(kCMTimeInvalid);
}

- (BOOL)isPlaying
{
	return restoreAfterScrubbingRate != 0.f || [player rate] != 0.f;
}

#pragma mark Player Notifications

/* Called when the player item has played to its end time. */
- (void) playerItemDidReachEnd:(NSNotification*) aNotification 
{
	/* Hide the 'Pause' button, show the 'Play' button in the slider control */
    [self showPlayButton];
    
	/* After the movie has played to its end time, seek back to time zero 
     to play it again */
	seekToZeroBeforePlay = YES;
    /*Play the next Song automatically*/
    [self next:nil];
}

#pragma mark - Loading the Asset Keys Asynchronously

#pragma mark - Error Handling - Preparing Assets for Playback Failed

/* --------------------------------------------------------------
 **  Called when an asset fails to prepare for playback for any of
 **  the following reasons:
 ** 
 **  1) values of asset keys did not load successfully, 
 **  2) the asset keys did load successfully, but the asset is not 
 **     playable
 **  3) the item did not become ready to play. 
 ** ----------------------------------------------------------- */
-(void)assetFailedToPrepareForPlayback:(NSError *)error
{
    [self removePlayerTimeObserver];
    [self syncScrubber];
    [self disableScrubber];
    [self disablePlayerButtons];
    
    /* Display the error. */
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
														message:[error localizedFailureReason]
													   delegate:nil
											  cancelButtonTitle:@"OK"
											  otherButtonTitles:nil];
	[alertView show];
	[alertView release];
}

#pragma mark Prepare to play asset

/*
 Invoked at the completion of the loading of the values for all keys on the asset that we require.
 Checks whether loading was successfull and whether the asset is playable.
 If so, sets up an AVPlayerItem and an AVPlayer to play the asset.
 */
- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys
{
    [self removePlayerTimeObserver];
    
    /* Stop observing our prior AVPlayerItem, if we have one. */
    if (self.playerItem)
    {
        NSLog(@"Remove existing player item key value observers");
        /* Remove existing player item key value observers and notifications. */
        [self.playerItem removeObserver:self forKeyPath:kStatusKey];            
		
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:self.playerItem];
    }
    
    NSLog(@"prepareToPlayAsset");
    /* Make sure that the value of each key has loaded successfully. */
	for (NSString *thisKey in requestedKeys)
	{
		NSError *error = nil;
		AVKeyValueStatus keyStatus = [asset statusOfValueForKey:thisKey error:&error];
		if (keyStatus == AVKeyValueStatusFailed)
		{
            if ([self isPlaying])
            {
                [self.player pause];
            }
            self.playerItem = nil;
			[self assetFailedToPrepareForPlayback:error];
            /*And skip to next song*/
            [self next:nil];
			return;
		}
		/* If you are also implementing the use of -[AVAsset cancelLoading], add your code here to bail 
         out properly in the case of cancellation. */
	}
    
    /* Use the duration property to detect whether the asset can be played. */
    if (CMTIME_IS_INVALID([asset duration])) 
    {
        /* Generate an error describing the failure. */
		NSString *localizedDescription = NSLocalizedString(@"Item cannot be played", @"Item cannot be played description");
		NSString *localizedFailureReason = NSLocalizedString(@"The assets tracks were loaded, but could not be made playable.", @"Item cannot be played failure reason");
		NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
								   localizedDescription, NSLocalizedDescriptionKey, 
								   localizedFailureReason, NSLocalizedFailureReasonErrorKey, 
								   nil];
		NSError *assetCannotBePlayedError = [NSError errorWithDomain:@"StitchedStreamPlayer" code:0 userInfo:errorDict];
        if ([self isPlaying])
        {
            [self.player pause];
        }
        self.playerItem = nil;
        /* Display the error to the user. And skip to next song*/
        [self assetFailedToPrepareForPlayback:assetCannotBePlayedError];
        [self next:nil];
        return;
    }
	
    /* Create a new instance of AVPlayerItem from the now successfully loaded AVAsset. */
    self.playerItem = [AVPlayerItem playerItemWithAsset:asset];
	
    /* Create new player, if we don't already have one. */
    if (![self player])
    {
        NSLog(@"Create new player");
        /*Set private AVAudioSession to enable background playing*/
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        NSError *setCategoryError = nil;
        BOOL success = [audioSession setCategory:AVAudioSessionCategoryPlayback error:&setCategoryError];
        if (!success)
        {
            /* handle the error condition */ 
        }
        
        NSError *activationError = nil;
        success = [audioSession setActive:YES error:&activationError];
        if (!success) 
        {
            /* handle the error condition */ 
        }
        
        /* Get a new AVPlayer initialized to play the specified player item. */
        [self setPlayer:[AVPlayer playerWithPlayerItem:self.playerItem]];
        
        /* Observe the AVPlayer "currentItem" property to find out when any 
         AVPlayer replaceCurrentItemWithPlayerItem: replacement will/did 
         occur.*/
        [self.player addObserver:self 
                      forKeyPath:kCurrentItemKey 
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:MyStreamingMovieViewControllerCurrentItemObservationContext];
        
        /* Observe the AVPlayer "rate" property to update the scrubber control. */
        [self.player addObserver:self 
                      forKeyPath:kRateKey 
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:MyStreamingMovieViewControllerRateObservationContext];
    }
    
    /* At this point we're ready to set up for playback of the asset. */
	[self initScrubberTimer];
	[self enableScrubber];
	[self enablePlayerButtons];
    
    /* Make our new AVPlayerItem the AVPlayer's current item. */
    if (self.player.currentItem != self.playerItem)
    {
        /* Replace the player item with a new player item. The item replacement occurs 
         asynchronously; observe the currentItem property to find out when the 
         replacement will/did occur*/
        NSLog(@"Replace the player item with a new player item");
        [player pause];
        [[self player] replaceCurrentItemWithPlayerItem:self.playerItem];
        [self syncPlayPauseButtons];
    }
    
    /*
    The Origin code of Apple's sample first addObservers and then make replaceCurrentItemWithPlayerItem,
    this resulting a crash when a notification for the previous item calls after that item is released.
    I changed the order to first make replaceCurrentItemWithPlayerItem and then addObservers and fix the crash bug.
    */
    seekToZeroBeforePlay = NO;
    /* Observe the player item "status" key to determine when it is ready to play. */
    [self.playerItem addObserver:self
                      forKeyPath:kStatusKey 
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:MyStreamingMovieViewControllerPlayerItemStatusObserverContext];
    /* When the player item has played to its end time we'll toggle
     the movie controller Pause button to be the Play button */
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.playerItem];
    [musicTimeControl setValue:0.0];
}

#pragma mark - Asset Key Value Observing
#pragma mark
#pragma mark Key Value Observer for player rate, currentItem, player item status

/* ---------------------------------------------------------
 **  Called when the value at the specified key path relative
 **  to the given object has changed. 
 **  Adjust the movie play and pause button controls when the 
 **  player item "status" value changes. Update the movie 
 **  scrubber control when the player item is ready to play.
 **  Adjust the movie scrubber control when the player item 
 **  "rate" value changes. For updates of the player
 **  "currentItem" property, set the AVPlayer for which the 
 **  player layer displays visual output.
 **  NOTE: this method is invoked on the main queue.
 ** ------------------------------------------------------- */

- (void)observeValueForKeyPath:(NSString*) path 
                      ofObject:(id)object 
                        change:(NSDictionary*)change 
                       context:(void*)context
{
	/* AVPlayerItem "status" property value observer. */
	if (context == MyStreamingMovieViewControllerPlayerItemStatusObserverContext)
	{
		[self syncPlayPauseButtons];
        
        AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        switch (status)
        {
                /* Indicates that the status of the player is not yet known because 
                 it has not tried to load new media resources for playback */
            case AVPlayerStatusUnknown:
            {
                NSLog(@"AVPlayerStatusUnknown");
                [self removePlayerTimeObserver];
                [self syncScrubber];
                
                [self disableScrubber];
                [self disablePlayerButtons];
            }
                break;
                
            case AVPlayerStatusReadyToPlay:
            {
                /* Once the AVPlayerItem becomes ready to play, i.e. 
                 [playerItem status] == AVPlayerItemStatusReadyToPlay,
                 its duration can be fetched from the item. */
                NSLog(@"AVPlayerStatusReadyToPlay");
                [self removePlayerTimeObserver];
                [player play];
                [self showStopButton];
                /* Show the movie slider control since the movie is now ready to play. */
                musicTimeControl.enabled = YES;
                
                [self enableScrubber];
                [self enablePlayerButtons];
                [self initScrubberTimer];
            }
                break;
                
            case AVPlayerStatusFailed:
            {
                NSLog(@"AVPlayerStatusFailed");
                AVPlayerItem *thePlayerItem = (AVPlayerItem *)object;
                [self assetFailedToPrepareForPlayback:thePlayerItem.error];
            }
                break;
        }
	}
	/* AVPlayer "rate" property value observer. */
	else if (context == MyStreamingMovieViewControllerRateObservationContext)
	{
        NSLog(@"RateObservationContext");
        [self syncPlayPauseButtons];
	}
	/* AVPlayer "currentItem" property observer. 
     Called when the AVPlayer replaceCurrentItemWithPlayerItem: 
     replacement will/did occur. */
	else if (context == MyStreamingMovieViewControllerCurrentItemObservationContext)
	{
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        NSLog(@"CurrentItemObservationContext newPlayerItem:%@", newPlayerItem);
        /* New player item null? */
        if (newPlayerItem == (id)[NSNull null])
        {
            [self disablePlayerButtons];
            [self disableScrubber];
        }
        else /* Replacement of player currentItem has occurred */
        {
            [self syncPlayPauseButtons];
        }
	}
	else
	{
		[super observeValueForKeyPath:path ofObject:object change:change context:context];
	}
    
    return;
}

@end
