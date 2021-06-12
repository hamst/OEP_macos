#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>


/**
 * block to return resulted image after processing
 * NOTE: pixelBuffer can be null if frame dropped because of queue or because of passed unsupported image format for target image
 */
typedef void (^BNBOEPImageReadyBlock)(_Nullable CVPixelBufferRef pixelBuffer);

typedef void (^BNBLoadEffectCompletionBlock)(bool result);

@interface BNBOffscreenEffectPlayer : NSObject

- (instancetype _Nonnull)init NS_UNAVAILABLE;

/**
 * effectWidth andHeight the size of the inner area where the effect is drawn
 * NOTE: There is an assumption that it is user responsibility to make sure that
 *       size of rendering area is equal to the image size passed to processImage
 */
- (instancetype _Nonnull)initWithWidth:(NSUInteger)width
                                height:(NSUInteger)height
                           manualAudio:(BOOL)manual;

// /**
//  * Async processImage method
//  */
- (void)processImage:(CVPixelBufferRef _Nonnull)pixelBuffer completion:(BNBOEPImageReadyBlock _Nonnull)completion;

// /**
//  * Load effect with specified name (used folder name)
//  * effectName - usually it is folder name with effect resources on local storage
//  */
- (void)loadEffect:(NSString* _Nonnull)effectName completion:(BNBLoadEffectCompletionBlock _Nullable)completion;

/**
 * Deactivate current effect, the same can be reached by loading effect with the empty name via loadEffect
 */
- (void)unloadEffect;

/**
 * Let you call methods defined in the active effect's script passing additional data or changing effect's behaviour
 */
- (void)callJsMethod:(NSString * _Nonnull)method withParam:(NSString * _Nonnull)param;

+ (BOOL)initializeIfNeeded:(NSString * _Nonnull)token resources:(NSArray<NSString *> *_Nonnull)resources;

@end
