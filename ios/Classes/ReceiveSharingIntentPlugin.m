#import "ReceiveFileIntentPlugin.h"
#import <receive_file_intent/receive_file_intent-Swift.h>

@implementation ReceiveFileIntentPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftReceiveFileIntentPlugin registerWithRegistrar:registrar];
}
@end
