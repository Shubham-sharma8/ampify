#import "MobileDeviceBridge.h"
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#import <sys/socket.h>
#import <sys/time.h>

typedef void *AMDeviceRef;
typedef void *AMDeviceNotificationRef;
typedef void *AMDServiceConnectionRef;

typedef struct {
    AMDeviceRef dev;
    unsigned int msg;
    AMDeviceNotificationRef subscription;
} AMDeviceNotificationCallbackInfo;

typedef void (*AMDeviceNotificationCallback)(AMDeviceNotificationCallbackInfo *info, void *context);

typedef int (*AMDeviceNotificationSubscribeFn)(AMDeviceNotificationCallback callback, unsigned int unused0, unsigned int unused1, void *context, AMDeviceNotificationRef *subscriptionOut);
typedef int (*AMDeviceNotificationUnsubscribeFn)(AMDeviceNotificationRef subscription);
typedef CFStringRef (*AMDeviceCopyDeviceIdentifierFn)(AMDeviceRef device);
typedef int (*AMDeviceConnectFn)(AMDeviceRef device);
typedef int (*AMDeviceDisconnectFn)(AMDeviceRef device);
typedef int (*AMDeviceIsPairedFn)(AMDeviceRef device);
typedef int (*AMDeviceValidatePairingFn)(AMDeviceRef device);
typedef int (*AMDeviceStartSessionFn)(AMDeviceRef device);
typedef int (*AMDeviceStopSessionFn)(AMDeviceRef device);
typedef CFTypeRef (*AMDeviceCopyValueFn)(AMDeviceRef device, CFStringRef _Nullable domain, CFStringRef _Nullable key);
typedef int (*AMDeviceSecureStartServiceFn)(AMDeviceRef device, CFStringRef serviceName, CFDictionaryRef _Nullable options, AMDServiceConnectionRef *connectionOut);
typedef int (*AMDServiceConnectionSendMessageFn)(AMDServiceConnectionRef connection, CFPropertyListRef message, CFPropertyListFormat format);
typedef int (*AMDServiceConnectionReceiveMessageFn)(AMDServiceConnectionRef connection, CFPropertyListRef *messageOut, CFPropertyListFormat * _Nullable formatOut);
typedef void (*AMDServiceConnectionInvalidateFn)(AMDServiceConnectionRef connection);
typedef int (*AMDServiceConnectionGetSocketFn)(AMDServiceConnectionRef connection);

static void *mobileDeviceHandle = NULL;
static AMDeviceNotificationSubscribeFn fnSubscribe = NULL;
static AMDeviceNotificationUnsubscribeFn fnUnsubscribe = NULL;
static AMDeviceCopyDeviceIdentifierFn fnCopyIdentifier = NULL;
static AMDeviceConnectFn fnConnect = NULL;
static AMDeviceDisconnectFn fnDisconnect = NULL;
static AMDeviceIsPairedFn fnIsPaired = NULL;
static AMDeviceValidatePairingFn fnValidatePairing = NULL;
static AMDeviceStartSessionFn fnStartSession = NULL;
static AMDeviceStopSessionFn fnStopSession = NULL;
static AMDeviceCopyValueFn fnCopyValue = NULL;
static AMDeviceSecureStartServiceFn fnSecureStartService = NULL;
static AMDServiceConnectionSendMessageFn fnSendMessage = NULL;
static AMDServiceConnectionReceiveMessageFn fnReceiveMessage = NULL;
static AMDServiceConnectionInvalidateFn fnInvalidate = NULL;
static AMDServiceConnectionGetSocketFn fnGetSocket = NULL;

static BOOL loadMobileDeviceFramework(void) {
    static BOOL loaded = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mobileDeviceHandle = dlopen("/Library/Apple/System/Library/PrivateFrameworks/MobileDevice.framework/MobileDevice", RTLD_LAZY);
        if (!mobileDeviceHandle) {
            mobileDeviceHandle = dlopen("/System/Library/PrivateFrameworks/MobileDevice.framework/MobileDevice", RTLD_LAZY);
        }
        if (!mobileDeviceHandle) {
            return;
        }
        fnSubscribe = (AMDeviceNotificationSubscribeFn)dlsym(mobileDeviceHandle, "AMDeviceNotificationSubscribe");
        fnUnsubscribe = (AMDeviceNotificationUnsubscribeFn)dlsym(mobileDeviceHandle, "AMDeviceNotificationUnsubscribe");
        fnCopyIdentifier = (AMDeviceCopyDeviceIdentifierFn)dlsym(mobileDeviceHandle, "AMDeviceCopyDeviceIdentifier");
        fnConnect = (AMDeviceConnectFn)dlsym(mobileDeviceHandle, "AMDeviceConnect");
        fnDisconnect = (AMDeviceDisconnectFn)dlsym(mobileDeviceHandle, "AMDeviceDisconnect");
        fnIsPaired = (AMDeviceIsPairedFn)dlsym(mobileDeviceHandle, "AMDeviceIsPaired");
        fnValidatePairing = (AMDeviceValidatePairingFn)dlsym(mobileDeviceHandle, "AMDeviceValidatePairing");
        fnStartSession = (AMDeviceStartSessionFn)dlsym(mobileDeviceHandle, "AMDeviceStartSession");
        fnStopSession = (AMDeviceStopSessionFn)dlsym(mobileDeviceHandle, "AMDeviceStopSession");
        fnCopyValue = (AMDeviceCopyValueFn)dlsym(mobileDeviceHandle, "AMDeviceCopyValue");
        fnSecureStartService = (AMDeviceSecureStartServiceFn)dlsym(mobileDeviceHandle, "AMDeviceSecureStartService");
        fnSendMessage = (AMDServiceConnectionSendMessageFn)dlsym(mobileDeviceHandle, "AMDServiceConnectionSendMessage");
        fnReceiveMessage = (AMDServiceConnectionReceiveMessageFn)dlsym(mobileDeviceHandle, "AMDServiceConnectionReceiveMessage");
        fnInvalidate = (AMDServiceConnectionInvalidateFn)dlsym(mobileDeviceHandle, "AMDServiceConnectionInvalidate");
        fnGetSocket = (AMDServiceConnectionGetSocketFn)dlsym(mobileDeviceHandle, "AMDServiceConnectionGetSocket");

        loaded = (fnSubscribe && fnUnsubscribe && fnCopyIdentifier && fnConnect && fnDisconnect &&
                  fnIsPaired && fnValidatePairing && fnStartSession && fnStopSession && fnCopyValue);
    });
    return loaded;
}

static NSDictionary * _Nullable queryServiceExchange(AMDeviceRef dev, NSString *serviceName, NSDictionary *request) {
    if (!fnSecureStartService || !fnSendMessage || !fnReceiveMessage || !fnInvalidate) {
        return nil;
    }
    AMDServiceConnectionRef conn = NULL;
    if (fnSecureStartService(dev, (__bridge CFStringRef)serviceName, NULL, &conn) != 0 || !conn) {
        return nil;
    }
    if (fnGetSocket) {
        int sock = fnGetSocket(conn);
        if (sock >= 0) {
            struct timeval tv;
            tv.tv_sec = 2;
            tv.tv_usec = 0;
            setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
            setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
        }
    }
    NSDictionary *responseDict = nil;
    if (fnSendMessage(conn, (__bridge CFPropertyListRef)request, kCFPropertyListXMLFormat_v1_0) == 0) {
        CFPropertyListRef reply = NULL;
        if (fnReceiveMessage(conn, &reply, NULL) == 0 && reply) {
            if (CFGetTypeID(reply) == CFDictionaryGetTypeID()) {
                responseDict = [(__bridge NSDictionary *)reply copy];
            }
            CFRelease(reply);
        }
    }
    fnInvalidate(conn);
    CFRelease(conn);
    return responseDict;
}

static void deviceNotificationCallback(AMDeviceNotificationCallbackInfo *info, void *context) {
    if (!info || info->msg != 1 || !info->dev || !context) {
        return;
    }
    NSMutableArray<NSDictionary *> *results = (__bridge NSMutableArray *)context;
    AMDeviceRef dev = info->dev;

    if (fnConnect(dev) != 0) return;
    if (fnIsPaired(dev) == 0) {
        fnDisconnect(dev);
        return;
    }
    if (fnValidatePairing(dev) != 0) {
        fnDisconnect(dev);
        return;
    }
    if (fnStartSession(dev) != 0) {
        fnDisconnect(dev);
        return;
    }

    NSMutableDictionary<NSString *, id> *entry = [NSMutableDictionary dictionary];

    CFStringRef cfUDID = fnCopyIdentifier(dev);
    if (cfUDID) {
        entry[@"UDID"] = (__bridge_transfer NSString *)cfUDID;
    }

    CFTypeRef nameRef = fnCopyValue(dev, NULL, CFSTR("DeviceName"));
    if (nameRef) {
        entry[@"DeviceName"] = (__bridge_transfer id)nameRef;
    }
    CFTypeRef prodRef = fnCopyValue(dev, NULL, CFSTR("ProductType"));
    if (prodRef) {
        entry[@"ProductType"] = (__bridge_transfer id)prodRef;
    }
    CFTypeRef battRef = fnCopyValue(dev, CFSTR("com.apple.mobile.battery"), NULL);
    if (battRef) {
        entry[@"BatteryDomain"] = (__bridge_transfer id)battRef;
    }

    // 1. Read AppleSmartBattery IORegistry from com.apple.mobile.diagnostics_relay
    NSDictionary *ioRegReq = @{@"Request": @"IORegistry", @"EntryName": @"AppleSmartBattery"};
    NSDictionary *ioRegReply = queryServiceExchange(dev, @"com.apple.mobile.diagnostics_relay", ioRegReq);
    if (ioRegReply) {
        entry[@"DiagnosticsReply"] = ioRegReply;
    }

    // 2. Also read GasGauge from com.apple.mobile.diagnostics_relay for FullChargeCapacity % & CycleCount
    NSDictionary *gasReq = @{@"Request": @"GasGauge"};
    NSDictionary *gasReply = queryServiceExchange(dev, @"com.apple.mobile.diagnostics_relay", gasReq);
    if (gasReply) {
        entry[@"GasGaugeReply"] = gasReply;
    }

    // 3. Query paired Apple Watches via com.apple.companion_proxy
    NSDictionary *compReq = @{@"Command": @"GetDeviceRegistry"};
    NSDictionary *compReply = queryServiceExchange(dev, @"com.apple.companion_proxy", compReq);
    NSArray *pairedWatches = [compReply[@"PairedDevicesArray"] isKindOfClass:[NSArray class]]
        ? compReply[@"PairedDevicesArray"]
        : @[];

    if (pairedWatches.count > 0) {
        NSMutableArray<NSDictionary *> *watches = [NSMutableArray array];
        NSArray<NSString *> *watchKeys = @[@"DeviceName", @"ProductType", @"BatteryCurrentCapacity", @"BatteryIsCharging"];
        for (id watchUDID in pairedWatches) {
            if (![watchUDID isKindOfClass:[NSString class]]) continue;
            NSMutableDictionary<NSString *, id> *watchDict = [NSMutableDictionary dictionaryWithObject:watchUDID forKey:@"UDID"];
            for (NSString *key in watchKeys) {
                NSDictionary *cmd = @{
                    @"Command": @"GetValueFromRegistry",
                    @"GetValueGizmoUDIDKey": watchUDID,
                    @"GetValueKeyKey": key
                };
                NSDictionary *reply = queryServiceExchange(dev, @"com.apple.companion_proxy", cmd);
                if (reply) {
                    watchDict[key] = reply;
                }
            }
            [watches addObject:watchDict];
        }
        entry[@"Watches"] = watches;
    }

    fnStopSession(dev);
    fnDisconnect(dev);

    if (entry.count > 0) {
        [results addObject:entry];
    }
}

@implementation MobileDeviceBridge

+ (BOOL)isAvailable {
    return loadMobileDeviceFramework();
}

+ (NSArray<NSDictionary<NSString *, id> *> *)readDevicesWithTimeout:(NSTimeInterval)timeout {
    if (!loadMobileDeviceFramework()) {
        return @[];
    }
    NSMutableArray<NSDictionary *> *results = [NSMutableArray array];
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    NSTimeInterval waitSeconds = timeout > 0 ? timeout : 3.5;

    [NSThread detachNewThreadWithBlock:^{
        @autoreleasepool {
            AMDeviceNotificationRef subscription = NULL;
            int err = fnSubscribe(deviceNotificationCallback, 0, 0, (__bridge void *)results, &subscription);
            if (err == 0 && subscription) {
                CFRunLoopRunInMode(kCFRunLoopDefaultMode, waitSeconds, false);
                fnUnsubscribe(subscription);
            }
            dispatch_semaphore_signal(sem);
        }
    }];

    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)((waitSeconds + 10.0) * NSEC_PER_SEC)));
    return [results copy];
}

@end
