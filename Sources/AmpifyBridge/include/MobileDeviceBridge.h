#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C bridge for Apple's private MobileDevice.framework (USB & Wi-Fi paired iOS/watchOS battery & health).
/// Reconstructed from REA Mach-O evidence ev_cf2e1cef2a482af18f3246a21025103591b3e348360717cda2920d03a681ad84.
@interface MobileDeviceBridge : NSObject

+ (BOOL)isAvailable;
+ (NSArray<NSDictionary<NSString *, id> *> *)readDevicesWithTimeout:(NSTimeInterval)timeout;

@end

NS_ASSUME_NONNULL_END
