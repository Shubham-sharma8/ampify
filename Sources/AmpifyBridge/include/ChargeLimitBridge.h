#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C bridge for Apple's private PowerUI.framework (PowerUISmartChargeClient).
/// Reconstructed from REA Mach-O evidence ev_cf2e1cef2a482af18f3246a21025103591b3e348360717cda2920d03a681ad84.
@interface ChargeLimitBridge : NSObject

+ (BOOL)isSupported;
+ (nullable NSString *)unavailableReason:(NSError * _Nullable * _Nullable)error;
+ (NSInteger)activeLimit;
+ (NSInteger)storedLimit;
+ (NSDictionary<NSString *, id> *)debugInfo;
+ (BOOL)setEnabled:(BOOL)enabled error:(NSError * _Nullable * _Nullable)error;
+ (BOOL)beginTemporaryFullCharge:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
