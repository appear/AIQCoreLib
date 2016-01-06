#import "AIQDataStore.h"
#import "NSDictionary+AIQAttachment.h"

@implementation NSDictionary (AIQAttachment)

- (NSString *)name {
    return self[kAIQAttachmentName];
}

- (NSString *)contentType {
    return self[kAIQAttachmentContentType];
}

- (BOOL)isAvailable {
    return [self[kAIQAttachmentState] intValue] == AIQAttachmentStateAvailable;
}

- (BOOL)isFailed {
    return [self[kAIQAttachmentState] intValue] == AIQAttachmentStateFailed;
}

- (BOOL)isLaunchable {
    NSString *contentType = self[kAIQAttachmentContentType];
    return ([contentType isEqualToString:@"application/vnd.appear.webapp"]) || ([contentType isEqualToString:@"application/pdf"]);
}

@end
