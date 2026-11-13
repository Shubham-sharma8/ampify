#import "ChargeLimitBridge.h"
#import <objc/message.h>
#import <objc/runtime.h>

@interface NSObject (PowerUISmartChargeClientPrivate)
- (instancetype)initWithClientName:(NSString *)clientName;
- (BOOL)isMCLSupported;
- (uint64_t)isMCLCurrentlyEnabled:(NSError **)error;
- (uint8_t)getMCLLimitWithError:(NSError **)error;
- (BOOL)enableMCL:(NSError **)error;
- (BOOL)disableMCL:(NSError **)error;
- (BOOL)temporarilyDisableMCL:(NSError **)error;
- (BOOL)isOBCEngaged:(BOOL *)obcEngaged
 isMaxChargeLimited:(BOOL *)maxChargeLimited
chargingOverrideAllowed:(BOOL *)overrideAllowed
          withError:(NSError **)error;
- (uint64_t)smartChargingUIState:(uint64_t *)uiState
                     chargeLimit:(uint64_t *)chargeLimit
         chargingOverrideAllowed:(BOOL *)overrideAllowed
                       withError:(NSError **)error;
@end

static id _Nullable sharedSmartChargeClient(void) {
    static id client = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *bundle = [NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/PowerUI.framework"];
        if ([bundle load]) {
            Class cls = NSClassFromString(@"PowerUISmartChargeClient");
            if (cls && [cls instancesRespondToSelector:@selector(initWithClientName:)]) {
                client = [[cls alloc] initWithClientName:@"com.cogify.ampify"];
            }
        }
    });
    return client;
}

@implementation ChargeLimitBridge

+ (BOOL)isSupported {
    id client = sharedSmartChargeClient();
    if (!client || ![client respondsToSelector:@selector(isMCLSupported)]) {
        return NO;
    }
    return [client isMCLSupported];
}

+ (nullable NSString *)unavailableReason:(NSError * _Nullable * _Nullable)error {
    NSBundle *bundle = [NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/PowerUI.framework"];
    if (!bundle) {
        return @"PowerUI.framework is missing on this macOS version";
    }
    NSError *loadErr = nil;
    if (![bundle isLoaded] && ![bundle loadAndReturnError:&loadErr]) {
        if (error) *error = loadErr;
        return [NSString stringWithFormat:@"PowerUI.framework failed to load (%@)", loadErr.localizedDescription ?: @"unknown"];
    }
    Class cls = NSClassFromString(@"PowerUISmartChargeClient");
    if (!cls) {
        return @"PowerUISmartChargeClient class is not exported by PowerUI.framework";
    }
    id client = sharedSmartChargeClient();
    if (!client) {
        return @"PowerUISmartChargeClient could not be initialized";
    }
    SEL requiredSelectors[] = {
        @selector(isMCLSupported),
        @selector(enableMCL:),
        @selector(disableMCL:),
        @selector(isMCLCurrentlyEnabled:)
    };
    for (size_t i = 0; i < sizeof(requiredSelectors) / sizeof(SEL); i++) {
        if (![client respondsToSelector:requiredSelectors[i]]) {
            return [NSString stringWithFormat:@"Missing selector: %@", NSStringFromSelector(requiredSelectors[i])];
        }
    }
    if (![client isMCLSupported]) {
        return @"PowerUISmartChargeClient reports Manual Charge Limit (MCL) is not supported on this Mac";
    }
    return nil;
}

+ (NSInteger)activeLimit {
    id client = sharedSmartChargeClient();
    if (!client || ![client respondsToSelector:@selector(isMCLCurrentlyEnabled:)]) {
        return 0;
    }
    NSError *err = nil;
    uint64_t state = [client isMCLCurrentlyEnabled:&err];
    if (err || state != 1) {
        return 0;
    }
    if ([client respondsToSelector:@selector(getMCLLimitWithError:)]) {
        NSError *limErr = nil;
        uint8_t limit = [client getMCLLimitWithError:&limErr];
        if (!limErr && limit > 0 && limit < 100) {
            return (NSInteger)limit;
        }
    }
    return 80;
}

+ (NSInteger)storedLimit {
    id client = sharedSmartChargeClient();
    if (!client || ![client respondsToSelector:@selector(getMCLLimitWithError:)]) {
        return 80;
    }
    NSError *err = nil;
    uint8_t limit = [client getMCLLimitWithError:&err];
    if (err || limit == 0) {
        return 80;
    }
    return (NSInteger)limit;
}

+ (NSDictionary<NSString *, id> *)debugInfo {
    NSMutableDictionary<NSString *, id> *info = [NSMutableDictionary dictionary];
    id client = sharedSmartChargeClient();
    if (!client) {
        return info;
    }
    if ([client respondsToSelector:@selector(isOBCEngaged:isMaxChargeLimited:chargingOverrideAllowed:withError:)]) {
        BOOL obc = NO, mcl = NO, overrideAllowed = NO;
        NSError *err = nil;
        [client isOBCEngaged:&obc isMaxChargeLimited:&mcl chargingOverrideAllowed:&overrideAllowed withError:&err];
        if (!err) {
            info[@"obcEngaged"] = @(obc);
            info[@"maxChargeLimited"] = @(mcl);
            info[@"overrideAllowed"] = @(overrideAllowed);
        }
    }
    if ([client respondsToSelector:@selector(smartChargingUIState:chargeLimit:chargingOverrideAllowed:withError:)]) {
        uint64_t uiState = 0, limit = 0;
        BOOL overrideAllowed = NO;
        NSError *err = nil;
        [client smartChargingUIState:&uiState chargeLimit:&limit chargingOverrideAllowed:&overrideAllowed withError:&err];
        if (!err) {
            info[@"smartChargingState"] = @(uiState);
            info[@"smartChargeLimit"] = @(limit);
        }
    }
    return info;
}

+ (BOOL)setEnabled:(BOOL)enabled error:(NSError * _Nullable * _Nullable)error {
    id client = sharedSmartChargeClient();
    if (!client) {
        if (error) {
            *error = [NSError errorWithDomain:@"ChargeLimitBridge"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"PowerUISmartChargeClient unavailable"}];
        }
        return NO;
    }
    NSError *localErr = nil;
    BOOL ok = enabled ? [client enableMCL:&localErr] : [client disableMCL:&localErr];
    if (error && localErr) {
        *error = localErr;
    }
    return ok && (localErr == nil);
}

+ (BOOL)beginTemporaryFullCharge:(NSError * _Nullable * _Nullable)error {
    id client = sharedSmartChargeClient();
    if (!client) {
        if (error) {
            *error = [NSError errorWithDomain:@"ChargeLimitBridge"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"PowerUISmartChargeClient unavailable"}];
        }
        return NO;
    }
    NSError *localErr = nil;
    if ([client respondsToSelector:@selector(temporarilyDisableMCL:)]) {
        BOOL ok = [client temporarilyDisableMCL:&localErr];
        if (error && localErr) *error = localErr;
        return ok && (localErr == nil);
    }
    BOOL ok = [client disableMCL:&localErr];
    if (error && localErr) *error = localErr;
    return ok && (localErr == nil);
}

@end
