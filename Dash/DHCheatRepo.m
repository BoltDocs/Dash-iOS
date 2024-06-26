//
//  Copyright (C) 2016  Kapeli
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "DHCheatRepo.h"
#import "DHCheatRepoList.h"

@implementation DHCheatRepo

static id singleton = nil;

+ (instancetype)sharedCheatRepo
{
    if(singleton)
    {
        return singleton;
    }
    id cheatRepo = [[DHAppDelegate mainStoryboard] instantiateViewControllerWithIdentifier:NSStringFromClass([self class])];
    [cheatRepo setUp];
    return cheatRepo;
}

- (void)setUp
{
    [super setUp];
    [self reloadCheatsheetsIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self reloadCheatsheetsIfNeeded];
}

- (void)reloadCheatsheetsIfNeeded
{
    UISearchBar *searchBar = self.searchController.searchBar;
    if(!self.loading && (!self.lastListLoad || (!searchBar.text.length && [[NSDate date] timeIntervalSinceDate:self.lastListLoad] > 300)))
    {
        self.loading = YES;
        BOOL shouldDelay = [self.loadingText contains:@"Retrying"];
        self.loadingText = nil;
        searchBar.userInteractionEnabled = NO;
        searchBar.alpha = 0.5;
        searchBar.placeholder = @"Loading...";
        [self.tableView reloadData];
        dispatch_queue_t queue = dispatch_queue_create([[NSString stringWithFormat:@"%u", arc4random() % 100000] UTF8String], 0);
        dispatch_async(queue, ^{
            if(shouldDelay)
            {
                [NSThread sleepForTimeInterval:1.0];
            }
            [[DHCheatRepoList sharedCheatRepoList] reload];
            NSMutableArray *feeds = [[DHCheatRepoList sharedCheatRepoList] allCheatsheets];
            dispatch_sync(dispatch_get_main_queue(), ^{
                if(feeds.count)
                {
                    NSArray *savedFeeds = [[NSUserDefaults standardUserDefaults] objectForKey:[self defaultsKey]];
                    for(NSDictionary *feedDictionary in savedFeeds)
                    {
                        DHFeed *savedFeed = [DHFeed feedWithDictionaryRepresentation:feedDictionary];
                        NSUInteger index = [feeds indexOfObject:savedFeed];
                        if(index != NSNotFound)
                        {
                            DHFeed *feed = feeds[index];
                            feed.installed = savedFeed.installed;
                            feed.installedVersion = savedFeed.installedVersion;
                            feed.size = savedFeed.size;
                        }
                    }
                    [feeds sortUsingFunction:compareFeeds context:nil];
                    
                    self.lastListLoad = [NSDate date];
                    searchBar.userInteractionEnabled = YES;
                    searchBar.alpha = 1.0;
                    searchBar.placeholder = @"Find cheat sheets to download";
                    self.loading = NO;
                    self.feeds = feeds;
                    [self.tableView reloadData];
                }
                else
                {
                    self.loadingText = @"Loading failed. Retrying...";
                    [self.tableView reloadData];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        self.loading = NO;
                        [self reloadCheatsheetsIfNeeded];
                    });
                }
            });
        });
    }
}

- (NSString *)installFeed:(DHFeed *)feed isAnUpdate:(BOOL)isAnUpdate
{
    NSObject *identifier = [[NSObject alloc] init];
    feed.identifier = identifier;
    feed.waiting = YES;
    BOOL didStallOnce = NO;
    BOOL didSetStallLabel = NO;
    while([self shouldStall] && feed.installing && feed.identifier == identifier)
    {
        if(didStallOnce && !didSetStallLabel)
        {
            didSetStallLabel = YES;
            dispatch_sync(dispatch_get_main_queue(), ^{
                [feed setDetailString:@"Waiting..."];
                [[feed cell].titleLabel setRightDetailText:@"Waiting..." adjustMainWidth:YES];
                [feed setMaxRightDetailWidth:[feed cell].titleLabel.maxRightDetailWidth];
            });
        }
        didStallOnce = YES;
        [NSThread sleepForTimeInterval:1.0f];
    }
    if(!feed.installing || feed.identifier != identifier)
    {
        return @"cancelled";
    }
    feed.waiting = NO;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *installPath = [self docsetPathForFeed:feed];
    NSString *tempPath = [self uniqueTempDirAtPath:installPath];
    NSString *tempFile = [tempPath stringByAppendingPathComponent:@"dash_temp_docset.tgz"];
    NSString *tarixFile = [tempFile stringByAppendingString:@".tarix"];
    
    __block BOOL shouldWait = NO;
    dispatch_sync(dispatch_get_main_queue(), ^{
        shouldWait = [[DHLatencyTester sharedLatency] performTests:NO];
    });
    if(shouldWait)
    {
        [NSThread sleepForTimeInterval:3.0f];
    }
    if(!feed.installing || feed.identifier != identifier)
    {
        return @"cancelled";
    }
    NSString *error = nil;
    DHFeedResult *feedResult = [self loadFeed:feed error:&error];
    if(!feed.installing || feed.identifier != identifier)
    {
        return @"cancelled";
    }
    if(feedResult && feed.installing)
    {
        feed.feedResult = feedResult;
        feedResult.feed = feed;
        NSError *downloadError = nil;
        if(feedResult.downloadURLs.count)
        {
            NSString *downloadURL = feedResult.downloadURLs[0];
            [self emptyTrashAtPath:tempPath];
            if(![fileManager createDirectoryAtPath:tempPath withIntermediateDirectories:YES attributes:nil error:nil])
            {
                return @"Couldn't create install directory.";
            }
            if([feedResult isCancelled])
            {
                [self emptyTrashAtPath:tempPath];
                return @"cancelled";
            }
            NSURL *url = [NSURL URLWithString:downloadURL];
            if(url)
            {
                BOOL result = NO;
                NSURL *tarixURL = [NSURL URLWithString:[[downloadURL stringByAppendingString:@".tarix"] stringByConvertingKapeliHttpURLToHttps]];
                feedResult.hasTarix = [NSURL URLIsFound:[tarixURL absoluteString] timeoutInterval:120.0f checkForRedirect:YES];
                downloadError = nil;
#ifdef DEBUG
                NSLog(@"Downloading %@", url);
#endif
                if([DHFileDownload downloadItemAtURL:url toFile:tempFile error:&downloadError delegate:self identifier:feedResult] && !downloadError)
                {
                    if([feedResult isCancelled])
                    {
                        [self emptyTrashAtPath:tempPath];
                        return @"cancelled";
                    }
                    
                    [feedResult setRightDetail:@"Waiting..."];
                    @synchronized([DHDocsetIndexer class])
                    {
                        if(!feedResult.hasTarix)
                        {
                            if([feedResult isCancelled])
                            {
                                [self emptyTrashAtPath:tempPath];
                                return @"cancelled";
                            }
                            [fileManager removeItemAtPath:tarixFile error:nil];
                            result = [DHUnarchiver unarchiveArchive:tempFile delegate:feedResult];
                        }
                        else
                        {
                            if([feedResult isCancelled])
                            {
                                [self emptyTrashAtPath:tempPath];
                                return @"cancelled";
                            }
                            [feedResult setRightDetail:@"Preparing..."];
                            result = [DHFileDownload downloadItemAtURL:tarixURL toFile:tarixFile error:nil delegate:nil identifier:nil];
                            if([feedResult isCancelled])
                            {
                                [self emptyTrashAtPath:tempPath];
                                return @"cancelled";
                            }
                            if(!result)
                            {
                                [self emptyTrashAtPath:tempPath];
                                return @"Couldn't download index file.";
                            }
                            if([feedResult isCancelled])
                            {
                                [self emptyTrashAtPath:tempPath];
                                return @"cancelled";
                            }
                            [feedResult setRightDetail:@"Extracting..."];
                            result = [DHUnarchiver unarchiveArchive:tarixFile delegate:nil];
                            if([feedResult isCancelled])
                            {
                                [self emptyTrashAtPath:tempPath];
                                return @"cancelled";
                            }
                            if(!result)
                            {
                                [self emptyTrashAtPath:tempPath];
                                return @"Couldn't unarchive index file.";
                            }
                            [fileManager removeItemAtPath:tarixFile error:nil];
                            tarixFile = [fileManager firstFileWithExtension:@"tarix" atPath:tempPath ignoreHidden:YES];
                            if(!tarixFile)
                            {
                                [self emptyTrashAtPath:tempPath];
                                return @"Couldn't find index file.";
                            }
                            tarixFile = [tempPath stringByAppendingPathComponent:tarixFile];
                            result = [DHUnarchiver unpackTarixDocset:tempFile tarixPath:tarixFile delegate:feedResult];
                            if([feedResult isCancelled])
                            {
                                [self emptyTrashAtPath:tempPath];
                                return @"cancelled";
                            }
                            if(!result)
                            {
                                [self emptyTrashAtPath:tempPath];
                                return @"Couldn't unarchive docset.";
                            }
                        }
                        if([feedResult isCancelled])
                        {
                            [self emptyTrashAtPath:tempPath];
                            return @"cancelled";
                        }
                        
                        if(!result)
                        {
                            [self emptyTrashAtPath:tempPath];
                            return @"Couldn't unarchive docset.";
                        }
                        
                        if(!feedResult.hasTarix)
                        {
                            [fileManager removeItemAtPath:tempFile error:nil];
                        }
                        DHDocset *docset = [DHDocset firstDocsetInsideFolder:tempPath];
                        if(!docset)
                        {
                            [self emptyTrashAtPath:tempPath];
                            return @"Couldn't install docset.";
                        }
                        else if(feedResult.hasTarix)
                        {
                            [fileManager moveItemAtPath:tarixFile toPath:docset.tarixIndexPath error:nil];
                            [fileManager moveItemAtPath:tempFile toPath:docset.tarixPath error:nil];
                        }
                        
                        [DHDocsetIndexer indexerForDocset:docset delegate:feedResult];
                        [fileManager removeItemAtPath:docset.sqlPath error:nil];
                        [fileManager removeItemAtPath:[docset.sqlPath stringByAppendingString:@"-shm"] error:nil];
                        [fileManager removeItemAtPath:[docset.sqlPath stringByAppendingString:@"-wal"] error:nil];
                        if([feedResult isCancelled])
                        {
                            [self emptyTrashAtPath:tempPath];
                            return @"cancelled";
                        }
                        
                        NSDirectoryEnumerator *dirEnum = [fileManager enumeratorAtPath:installPath];
                        NSString *file = nil;
                        while(file = [dirEnum nextObject])
                        {
                            [dirEnum skipDescendents];
                            NSString *filePath = [installPath stringByAppendingPathComponent:file];
                            if(![filePath isEqualToString:tempPath])
                            {
                                NSString *trashPath = [self uniqueTrashPath];
                                [fileManager moveItemAtPath:filePath toPath:trashPath error:nil];
                                dispatch_queue_t queue = dispatch_queue_create([[NSString stringWithFormat:@"%u", arc4random() % 100000] UTF8String], 0);
                                dispatch_async(queue, ^{
                                    [self emptyTrashAtPath:trashPath];
                                });
                            }
                        }
                        [fileManager moveItemAtPath:docset.path toPath:[installPath stringByAppendingPathComponent:[docset.path lastPathComponent]] error:nil];
                        [self emptyTrashAtPath:tempPath];
                        return nil;
                    }
                }
                else if(downloadError.code == DHDownloadCancelled)
                {
                    [self emptyTrashAtPath:tempPath];
                    return @"cancelled";
                }
                else
                {
                    [self emptyTrashAtPath:tempPath];
                }
            }
        }
        return @"Couldn't download cheat sheet.";
    }
    else
    {
        return error;
    }
    return nil;
}

- (DHFeedResult *)loadFeed:(DHFeed *)feed error:(NSString **)returnError
{
    DHFeedResult *feedResult = [[DHFeedResult alloc] init];
    DHCheatRepoList *list = [DHCheatRepoList sharedCheatRepoList];
    feedResult.downloadURLs = @[[list downloadURLForEntry:feed]];
    feedResult.version = [list versionForEntry:feed];
    return feedResult;
}

- (NSString *)docsetInstallFolderName
{
    return @"Cheat Sheets";
}

- (void)showUpdateRequestForFeeds:(NSArray *)toUpdate count:(NSInteger)feedCount docsetList:(NSString *)docsetList
{
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:[self defaultsScheduledUpdateKey]];
    [UIAlertView showWithTitle:@"Updates Found" message:[NSString stringWithFormat:@"Updates are available for %ld %@:%@%@", (long)feedCount, (feedCount > 1) ? @"cheat sheets" : @"cheat sheet", (feedCount > 1) ? @"\n\n" : @" ", docsetList] cancelButtonTitle:@"Maybe Later" otherButtonTitles:@[@"Update"] tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
        if(buttonIndex != alertView.cancelButtonIndex)
        {
            if(toUpdate)
            {
                [self updateFeeds:toUpdate];
            }
            else
            {
                [self checkForUpdatesAndShowInterface:NO updateWithoutAsking:YES];
            }
        }
    }];
}

- (IBAction)errorButtonPressed:(id)sender
{
    NSUInteger row = [sender tag];
    DHFeed *feed = [self activeFeeds][row];
    [[[UIAlertView alloc] initWithTitle:@"Cheat Sheet Install Failed" message:[NSString stringWithFormat:@"%@ Please check your Internet connection and available free space and try again.", feed.error] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

+ (id)alloc
{
    if(singleton)
    {
        return singleton;
    }
    return [super alloc];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if(singleton)
    {
        return singleton;
    }
    self = [super initWithCoder:aDecoder];
    singleton = self;
    return self;
}

@end
