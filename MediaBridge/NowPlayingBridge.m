// NowPlayingBridge: loaded by /usr/bin/perl (see now-playing.pl), which macOS still allows to read
// the system-wide Now Playing state through the private MediaRemote framework (macOS 15.4+ blocks
// that for unentitled apps). Streams one JSON object per line on stdout; sends transport commands.
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <dlfcn.h>

typedef void (*MRGetInfo)(dispatch_queue_t, void (^)(CFDictionaryRef));
typedef void (*MRGetIsPlaying)(dispatch_queue_t, void (^)(Boolean));
typedef void (*MRGetClient)(dispatch_queue_t, void (^)(id));
typedef void (*MRRegister)(dispatch_queue_t);
typedef Boolean (*MRSendCommand)(int, CFDictionaryRef);
typedef void (*MRSetElapsed)(double);

static void *mr;
static MRGetInfo getInfo;
static MRGetIsPlaying getIsPlaying;
static MRGetClient getClient;
static NSUInteger lastArtworkHash;

static BOOL load(void) {
    mr = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
    if (!mr) return NO;
    getInfo = (MRGetInfo)dlsym(mr, "MRMediaRemoteGetNowPlayingInfo");
    getIsPlaying = (MRGetIsPlaying)dlsym(mr, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    getClient = (MRGetClient)dlsym(mr, "MRMediaRemoteGetNowPlayingClient");
    return getInfo != NULL;
}

static id value(NSDictionary *info, NSString *key) {
    id v = info[key];
    // Live streams and some web players report an infinite or NaN duration, which JSON cannot encode.
    if ([v isKindOfClass:[NSNumber class]] && !isfinite([v doubleValue])) return [NSNull null];
    return v ?: [NSNull null];
}

static void emit(void) {
    dispatch_queue_t q = dispatch_get_main_queue();
    getInfo(q, ^(CFDictionaryRef raw) {
        NSDictionary *info = (__bridge NSDictionary *)raw;
        void (^finish)(NSString *) = ^(NSString *bundle) {
            NSMutableDictionary *out = [NSMutableDictionary dictionary];
            if (!info || info.count == 0) {
                out[@"empty"] = @YES;
            } else {
                out[@"title"] = value(info, @"kMRMediaRemoteNowPlayingInfoTitle");
                out[@"artist"] = value(info, @"kMRMediaRemoteNowPlayingInfoArtist");
                out[@"album"] = value(info, @"kMRMediaRemoteNowPlayingInfoAlbum");
                out[@"duration"] = value(info, @"kMRMediaRemoteNowPlayingInfoDuration");
                out[@"elapsed"] = value(info, @"kMRMediaRemoteNowPlayingInfoElapsedTime");
                out[@"rate"] = value(info, @"kMRMediaRemoteNowPlayingInfoPlaybackRate");
                NSDate *stamp = info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
                out[@"timestamp"] = stamp ? @([stamp timeIntervalSince1970]) : [NSNull null];
                out[@"bundle"] = bundle ?: [NSNull null];
                NSData *art = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
                if (art.length > 0 && art.hash != lastArtworkHash) {
                    lastArtworkHash = art.hash;
                    out[@"artwork"] = [art base64EncodedStringWithOptions:0];
                } else if (art.length == 0) {
                    lastArtworkHash = 0;
                    out[@"noArtwork"] = @YES;
                }
            }
            getIsPlaying(q, ^(Boolean playing) {
                out[@"playing"] = @(playing);
                if (![NSJSONSerialization isValidJSONObject:out]) return;
                NSData *json = [NSJSONSerialization dataWithJSONObject:out options:0 error:nil];
                if (json) {
                    fwrite(json.bytes, 1, json.length, stdout);
                    fputc('\n', stdout);
                    fflush(stdout);
                }
            });
        };
        if (getClient) {
            getClient(q, ^(id client) {
                // Web content plays from helper processes (WebKit.GPU, Chrome helpers); the parent
                // application is the browser the user recognizes.
                NSString *bundle = nil;
                if (client && [client respondsToSelector:@selector(parentApplicationBundleIdentifier)]) {
                    bundle = [client performSelector:@selector(parentApplicationBundleIdentifier)];
                }
                if (!bundle && client && [client respondsToSelector:@selector(bundleIdentifier)]) {
                    bundle = [client performSelector:@selector(bundleIdentifier)];
                }
                finish(bundle);
            });
        } else {
            finish(nil);
        }
    });
}

void notchnull_stream(void) {
    @autoreleasepool {
        if (!load()) { fprintf(stdout, "{\"error\":\"MediaRemote unavailable\"}\n"); fflush(stdout); return; }
        MRRegister reg = (MRRegister)dlsym(mr, "MRMediaRemoteRegisterForNowPlayingNotifications");
        if (reg) reg(dispatch_get_main_queue());
        NSArray *names = @[
            @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
        ];
        for (NSString *name in names) {
            [[NSNotificationCenter defaultCenter] addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *n) { emit(); }];
        }
        // Periodic resync keeps elapsed time honest when an app does not post updates.
        [NSTimer scheduledTimerWithTimeInterval:3 repeats:YES block:^(NSTimer *t) { emit(); }];
        emit();
        // Exit when the parent app goes away (stdin closes).
        dispatch_source_t eof = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, STDIN_FILENO, 0, dispatch_get_main_queue());
        dispatch_source_set_event_handler(eof, ^{
            char buffer[64];
            if (read(STDIN_FILENO, buffer, sizeof buffer) <= 0) exit(0);
        });
        dispatch_resume(eof);
        [[NSRunLoop mainRunLoop] run];
    }
}

void notchnull_command(void) {
    @autoreleasepool {
        if (!load()) return;
        const char *command = getenv("NOTCHNULL_MR_COMMAND");
        const char *seek = getenv("NOTCHNULL_MR_SEEK");
        if (seek) {
            MRSetElapsed set = (MRSetElapsed)dlsym(mr, "MRMediaRemoteSetElapsedTime");
            if (set) set(atof(seek));
        } else if (command) {
            MRSendCommand send = (MRSendCommand)dlsym(mr, "MRMediaRemoteSendCommand");
            if (send) send(atoi(command), NULL);
        }
        // Give mediaremoted a moment to take the command before perl exits.
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.15]];
    }
}
