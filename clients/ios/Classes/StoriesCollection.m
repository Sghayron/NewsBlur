//
//  StoriesCollection.m
//  NewsBlur
//
//  Created by Samuel Clay on 2/12/14.
//  Copyright (c) 2014 NewsBlur. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "StoriesCollection.h"
#import "JSON.h"
#import "FMDatabase.h"
#import "Utilities.h"

@implementation StoriesCollection

@synthesize appDelegate;
@synthesize activeFeed;
@synthesize activeClassifiers;
@synthesize activePopularTags;
@synthesize activePopularAuthors;
@synthesize activeFolder;
@synthesize activeFolderFeeds;
@synthesize activeFeedStories;
@synthesize activeFeedStoryLocations;
@synthesize activeFeedStoryLocationIds;
@synthesize activeFeedUserProfiles;
@synthesize storyCount;
@synthesize storyLocationsCount;
@synthesize visibleUnreadCount;
@synthesize feedPage;

@synthesize isRiverView;
@synthesize isSocialView;
@synthesize isSocialRiverView;
@synthesize transferredFromDashboard;


- (id)init {
    if (self = [super init]) {
        self.visibleUnreadCount = 0;
        self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];
    }

    return self;
}

- (id)initForDashboard {
    if (self = [self init]) {
        
    }
    
    return self;
}

- (void)reset {
    [self setStories:nil];
    [self setFeedUserProfiles:nil];

    self.feedPage = 1;
    self.activeFeed = nil;
    self.activeFolder = nil;
    self.activeFolderFeeds = nil;
    self.activeClassifiers = [NSMutableDictionary dictionary];
    
    self.transferredFromDashboard = NO;
    self.isRiverView = NO;
    self.isSocialView = NO;
    self.isSocialRiverView = NO;
}

- (void)transferStoriesFromCollection:(StoriesCollection *)fromCollection {
    self.feedPage = fromCollection.feedPage;
    [self setStories:fromCollection.activeFeedStories];
    [self setFeedUserProfiles:fromCollection.activeFeedUserProfiles];
    self.activeFolderFeeds = fromCollection.activeFolderFeeds;
    self.activeClassifiers = fromCollection.activeClassifiers;
    
}

#pragma mark - Story Traversal

- (BOOL)isStoryUnread:(NSDictionary *)story {
    BOOL readStatusUnread = [[story objectForKey:@"read_status"] intValue] == 0;
    BOOL storyHashUnread = [[appDelegate.unreadStoryHashes
                             objectForKey:[story objectForKey:@"story_hash"]] boolValue];
    BOOL recentlyRead = [[appDelegate.recentlyReadStories
                          objectForKey:[story objectForKey:@"story_hash"]] boolValue];
    
    //    NSLog(@"isUnread: (%d || %d) && %d (%@ / %@)", readStatusUnread, storyHashUnread,
    //          !recentlyRead, [[story objectForKey:@"story_title"] substringToIndex:10],
    //          [story objectForKey:@"story_hash"]);
    
    return (readStatusUnread || storyHashUnread) && !recentlyRead;
}

- (void)calculateStoryLocations {
    self.visibleUnreadCount = 0;
    self.activeFeedStoryLocations = [NSMutableArray array];
    self.activeFeedStoryLocationIds = [NSMutableArray array];
    for (int i=0; i < self.storyCount; i++) {
        NSDictionary *story = [self.activeFeedStories objectAtIndex:i];
        NSInteger score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
        if (score >= appDelegate.selectedIntelligence || [[story objectForKey:@"sticky"] boolValue]) {
            NSNumber *location = [NSNumber numberWithInt:i];
            [self.activeFeedStoryLocations addObject:location];
            [self.activeFeedStoryLocationIds addObject:[story objectForKey:@"story_hash"]];
            if ([[story objectForKey:@"read_status"] intValue] == 0) {
                self.visibleUnreadCount += 1;
            }
        }
    }
    self.storyLocationsCount = [self.activeFeedStoryLocations count];
}

- (NSInteger)indexOfNextUnreadStory {
    NSInteger location = [self locationOfNextUnreadStory];
    return [self indexFromLocation:location];
}

- (NSInteger)locationOfNextUnreadStory {
    NSInteger activeLocation = [self locationOfActiveStory];
    
    for (NSInteger i=activeLocation+1; i < [self.activeFeedStoryLocations count]; i++) {
        NSInteger storyIndex = [[self.activeFeedStoryLocations objectAtIndex:i] intValue];
        NSDictionary *story = [activeFeedStories objectAtIndex:storyIndex];
        if ([self isStoryUnread:story]) {
            return i;
        }
    }
    if (activeLocation > 0) {
        for (NSInteger i=activeLocation-1; i >= 0; i--) {
            NSInteger storyIndex = [[self.activeFeedStoryLocations objectAtIndex:i] intValue];
            NSDictionary *story = [activeFeedStories objectAtIndex:storyIndex];
            if ([self isStoryUnread:story]) {
                return i;
            }
        }
    }
    return -1;
}

- (NSInteger)indexOfNextStory {
    NSInteger location = [self locationOfNextStory];
    return [self indexFromLocation:location];
}

- (NSInteger)locationOfNextStory {
    NSInteger activeLocation = [self locationOfActiveStory];
    NSInteger nextStoryLocation = activeLocation + 1;
    if (nextStoryLocation < [self.activeFeedStoryLocations count]) {
        return nextStoryLocation;
    }
    return -1;
}

- (NSInteger)indexOfActiveStory {
    for (NSInteger i=0; i < self.storyCount; i++) {
        NSDictionary *story = [activeFeedStories objectAtIndex:i];
        if ([appDelegate.activeStory objectForKey:@"story_hash"] == [story objectForKey:@"story_hash"]) {
            return i;
        }
    }
    return -1;
}

- (NSInteger)indexOfStoryId:(id)storyId {
    for (int i=0; i < self.storyCount; i++) {
        NSDictionary *story = [activeFeedStories objectAtIndex:i];
        if ([story objectForKey:@"story_hash"] == storyId) {
            return i;
        }
    }
    return -1;
}

- (NSInteger)locationOfStoryId:(id)storyId {
    for (int i=0; i < [activeFeedStoryLocations count]; i++) {
        if ([activeFeedStoryLocationIds objectAtIndex:i] == storyId) {
            return i;
        }
    }
    return -1;
}

- (NSInteger)locationOfActiveStory {
    for (int i=0; i < [activeFeedStoryLocations count]; i++) {
        if ([[activeFeedStoryLocationIds objectAtIndex:i]
             isEqualToString:[appDelegate.activeStory objectForKey:@"story_hash"]]) {
            return i;
        }
    }
    return -1;
}

- (NSInteger)indexFromLocation:(NSInteger)location {
    if (location == -1) return -1;
    return [[activeFeedStoryLocations objectAtIndex:location] intValue];
}

- (NSString *)activeOrder {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    NSString *orderPrefDefault = [userPreferences stringForKey:@"default_order"];
    NSString *orderPref = [userPreferences stringForKey:[self orderKey]];
    
    if (orderPref) {
        return orderPref;
    } else if (orderPrefDefault) {
        return orderPrefDefault;
    } else {
        return @"newest";
    }
}

- (NSString *)activeReadFilter {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    NSString *readFilterFeedPrefDefault = [userPreferences stringForKey:@"default_feed_read_filter"];
    NSString *readFilterFolderPrefDefault = [userPreferences stringForKey:@"default_folder_read_filter"];
    NSString *readFilterPref = [userPreferences stringForKey:[self readFilterKey]];
    
    if (readFilterPref) {
        return readFilterPref;
    } else if (self.activeFolder && (self.isRiverView || self.isSocialRiverView)) {
        if (readFilterFolderPrefDefault) {
            return readFilterFolderPrefDefault;
        } else {
            return @"unread";
        }
    } else {
        if (readFilterFeedPrefDefault) {
            return readFilterFeedPrefDefault;
        } else {
            return @"all";
        }
    }
}

- (NSString *)orderKey {
    if (self.isRiverView) {
        return [NSString stringWithFormat:@"folder:%@:order", self.activeFolder];
    } else {
        return [NSString stringWithFormat:@"%@:order", [self.activeFeed objectForKey:@"id"]];
    }
}

- (NSString *)readFilterKey {
    if (self.isRiverView) {
        return [NSString stringWithFormat:@"folder:%@:read_filter", self.activeFolder];
    } else {
        return [NSString stringWithFormat:@"%@:read_filter", [self.activeFeed objectForKey:@"id"]];
    }
}


#pragma mark - Story Management

- (void)addStories:(NSArray *)stories {
    self.activeFeedStories = [self.activeFeedStories arrayByAddingObjectsFromArray:stories];
    self.storyCount = [self.activeFeedStories count];
    [self calculateStoryLocations];
    self.storyLocationsCount = [self.activeFeedStoryLocations count];
}

- (void)setStories:(NSArray *)activeFeedStoriesValue {
    self.activeFeedStories = activeFeedStoriesValue;
    self.storyCount = [self.activeFeedStories count];
    appDelegate.recentlyReadFeeds = [NSMutableSet set];
    [self calculateStoryLocations];
    self.storyLocationsCount = [self.activeFeedStoryLocations count];
}

- (void)setFeedUserProfiles:(NSArray *)activeFeedUserProfilesValue{
    self.activeFeedUserProfiles = activeFeedUserProfilesValue;
}

- (void)addFeedUserProfiles:(NSArray *)activeFeedUserProfilesValue {
    self.activeFeedUserProfiles = [self.activeFeedUserProfiles arrayByAddingObjectsFromArray:activeFeedUserProfilesValue];
}

- (void)pushReadStory:(id)storyId {
    if ([appDelegate.readStories lastObject] != storyId) {
        [appDelegate.readStories addObject:storyId];
    }
}

- (id)popReadStory {
    if (storyCount == 0) {
        return nil;
    } else {
        [appDelegate.readStories removeLastObject];
        id lastStory = [appDelegate.readStories lastObject];
        return lastStory;
    }
}

#pragma mark - Story Actions

- (void)markStoryRead:(NSString *)storyId feedId:(id)feedId {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    NSDictionary *feed = [appDelegate getFeed:feedIdStr];
    NSDictionary *story = nil;
    for (NSDictionary *s in self.activeFeedStories) {
        if ([[s objectForKey:@"story_hash"] isEqualToString:storyId]) {
            story = s;
            break;
        }
    }
    [self markStoryRead:story feed:feed];
}

- (void)markStoryRead:(NSDictionary *)story feed:(NSDictionary *)feed {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [feed objectForKey:@"id"]];
    if (!feed) {
        feedIdStr = @"0";
    }
    
    NSMutableDictionary *newStory = [story mutableCopy];
    [newStory setValue:[NSNumber numberWithInt:1] forKey:@"read_status"];
    
    // make the story as read in self.activeFeedStories
    NSString *newStoryIdStr = [NSString stringWithFormat:@"%@", [newStory valueForKey:@"story_hash"]];
    NSMutableArray *newActiveFeedStories = [self.activeFeedStories mutableCopy];
    for (int i = 0; i < [newActiveFeedStories count]; i++) {
        NSMutableArray *thisStory = [[newActiveFeedStories objectAtIndex:i] mutableCopy];
        NSString *thisStoryIdStr = [NSString stringWithFormat:@"%@", [thisStory valueForKey:@"story_hash"]];
        if ([newStoryIdStr isEqualToString:thisStoryIdStr]) {
            [newActiveFeedStories replaceObjectAtIndex:i withObject:newStory];
            break;
        }
    }
    self.activeFeedStories = newActiveFeedStories;
    if ([[appDelegate.activeStory objectForKey:@"story_hash"]
         isEqualToString:[newStory objectForKey:@"story_hash"]]) {
        appDelegate.activeStory = newStory;
    }
    
    // If not a feed, then don't bother updating local feed.
    if (!feed) return;
    
    self.visibleUnreadCount -= 1;
    if (![appDelegate.recentlyReadFeeds containsObject:[newStory objectForKey:@"story_feed_id"]]) {
        [appDelegate.recentlyReadFeeds addObject:[newStory objectForKey:@"story_feed_id"]];
    }
    
    NSDictionary *unreadCounts = [appDelegate.dictUnreadCounts objectForKey:feedIdStr];
    NSMutableDictionary *newUnreadCounts = [unreadCounts mutableCopy];
    NSInteger score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
    if (score > 0) {
        int unreads = MAX(0, [[newUnreadCounts objectForKey:@"ps"] intValue] - 1);
        [newUnreadCounts setValue:[NSNumber numberWithInt:unreads] forKey:@"ps"];
    } else if (score == 0) {
        int unreads = MAX(0, [[newUnreadCounts objectForKey:@"nt"] intValue] - 1);
        [newUnreadCounts setValue:[NSNumber numberWithInt:unreads] forKey:@"nt"];
    } else if (score < 0) {
        int unreads = MAX(0, [[newUnreadCounts objectForKey:@"ng"] intValue] - 1);
        [newUnreadCounts setValue:[NSNumber numberWithInt:unreads] forKey:@"ng"];
    }
    [appDelegate.dictUnreadCounts setObject:newUnreadCounts forKey:feedIdStr];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
        [appDelegate.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
            NSString *storyHash = [newStory objectForKey:@"story_hash"];
            [db executeUpdate:@"UPDATE stories SET story_json = ? WHERE story_hash = ?",
             [newStory JSONRepresentation],
             storyHash];
            [db executeUpdate:@"DELETE FROM unread_hashes WHERE story_hash = ?",
             storyHash];
            [db executeUpdate:@"UPDATE unread_counts SET ps = ?, nt = ?, ng = ? WHERE feed_id = ?",
             [newUnreadCounts objectForKey:@"ps"],
             [newUnreadCounts objectForKey:@"nt"],
             [newUnreadCounts objectForKey:@"ng"],
             feedIdStr];
        }];
    });
    
    [appDelegate.recentlyReadStories setObject:[NSNumber numberWithBool:YES]
                                        forKey:[story objectForKey:@"story_hash"]];
    [appDelegate.unreadStoryHashes removeObjectForKey:[story objectForKey:@"story_hash"]];
    
}

- (void)markStoryUnread:(NSString *)storyId feedId:(id)feedId {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    NSDictionary *feed = [appDelegate getFeed:feedIdStr];
    NSDictionary *story = nil;
    for (NSDictionary *s in self.activeFeedStories) {
        if ([[s objectForKey:@"story_hash"] isEqualToString:storyId]) {
            story = s;
            break;
        }
    }
    [self markStoryUnread:story feed:feed];
}

- (void)markStoryUnread:(NSDictionary *)story feed:(NSDictionary *)feed {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [feed objectForKey:@"id"]];
    if (!feed) {
        feedIdStr = @"0";
    }
    
    NSMutableDictionary *newStory = [story mutableCopy];
    [newStory setValue:[NSNumber numberWithInt:0] forKey:@"read_status"];
    
    // make the story as read in self.activeFeedStories
    NSString *newStoryIdStr = [NSString stringWithFormat:@"%@", [newStory valueForKey:@"story_hash"]];
    NSMutableArray *newActiveFeedStories = [self.activeFeedStories mutableCopy];
    for (int i = 0; i < [newActiveFeedStories count]; i++) {
        NSMutableArray *thisStory = [[newActiveFeedStories objectAtIndex:i] mutableCopy];
        NSString *thisStoryIdStr = [NSString stringWithFormat:@"%@", [thisStory valueForKey:@"story_hash"]];
        if ([newStoryIdStr isEqualToString:thisStoryIdStr]) {
            [newActiveFeedStories replaceObjectAtIndex:i withObject:newStory];
            break;
        }
    }
    self.activeFeedStories = newActiveFeedStories;
    
    // If not a feed, then don't bother updating local feed.
    if (!feed) return;
    
    self.visibleUnreadCount += 1;
    //    if ([self.recentlyReadFeeds containsObject:[newStory objectForKey:@"story_feed_id"]]) {
    [appDelegate.recentlyReadFeeds removeObject:[newStory objectForKey:@"story_feed_id"]];
    //    }
    
    NSDictionary *unreadCounts = [appDelegate.dictUnreadCounts objectForKey:feedIdStr];
    NSMutableDictionary *newUnreadCounts = [unreadCounts mutableCopy];
    NSInteger score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
    if (score > 0) {
        int unreads = MAX(0, [[newUnreadCounts objectForKey:@"ps"] intValue] + 1);
        [newUnreadCounts setValue:[NSNumber numberWithInt:unreads] forKey:@"ps"];
    } else if (score == 0) {
        int unreads = MAX(0, [[newUnreadCounts objectForKey:@"nt"] intValue] + 1);
        [newUnreadCounts setValue:[NSNumber numberWithInt:unreads] forKey:@"nt"];
    } else if (score < 0) {
        int unreads = MAX(0, [[newUnreadCounts objectForKey:@"ng"] intValue] + 1);
        [newUnreadCounts setValue:[NSNumber numberWithInt:unreads] forKey:@"ng"];
    }
    [appDelegate.dictUnreadCounts setObject:newUnreadCounts forKey:feedIdStr];
    
    [appDelegate.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
        NSString *storyHash = [newStory objectForKey:@"story_hash"];
        [db executeUpdate:@"UPDATE stories SET story_json = ? WHERE story_hash = ?",
         [newStory JSONRepresentation],
         storyHash];
        [db executeUpdate:@"INSERT INTO unread_hashes "
         "(story_hash, story_feed_id, story_timestamp) VALUES (?, ?, ?)",
         storyHash, feedIdStr, [newStory objectForKey:@"story_timestamp"]];
        [db executeUpdate:@"UPDATE unread_counts SET ps = ?, nt = ?, ng = ? WHERE feed_id = ?",
         [newUnreadCounts objectForKey:@"ps"],
         [newUnreadCounts objectForKey:@"nt"],
         [newUnreadCounts objectForKey:@"ng"],
         feedIdStr];
    }];
    
    [appDelegate.recentlyReadStories removeObjectForKey:[story objectForKey:@"story_hash"]];
}

- (void)markStory:story asSaved:(BOOL)saved {
    NSMutableDictionary *newStory = [story mutableCopy];
    [newStory setValue:[NSNumber numberWithBool:saved] forKey:@"starred"];
    if (saved) {
        [newStory setValue:[Utilities formatLongDateFromTimestamp:nil] forKey:@"starred_date"];
    } else {
        [newStory removeObjectForKey:@"starred_date"];
    }
    
    if ([[newStory objectForKey:@"story_hash"]
         isEqualToString:[appDelegate.activeStory objectForKey:@"story_hash"]]) {
        appDelegate.activeStory = newStory;
    }
    
    // make the story as read in self.activeFeedStories
    NSString *newStoryIdStr = [NSString stringWithFormat:@"%@", [newStory valueForKey:@"story_hash"]];
    NSMutableArray *newActiveFeedStories = [self.activeFeedStories mutableCopy];
    for (int i = 0; i < [newActiveFeedStories count]; i++) {
        NSMutableArray *thisStory = [[newActiveFeedStories objectAtIndex:i] mutableCopy];
        NSString *thisStoryIdStr = [NSString stringWithFormat:@"%@", [thisStory valueForKey:@"story_hash"]];
        if ([newStoryIdStr isEqualToString:thisStoryIdStr]) {
            [newActiveFeedStories replaceObjectAtIndex:i withObject:newStory];
            break;
        }
    }
    self.activeFeedStories = newActiveFeedStories;
    
    if (saved) {
        appDelegate.savedStoriesCount += 1;
    } else {
        appDelegate.savedStoriesCount -= 1;
    }
}


@end