#import "AIQDataStore.h"
#import "NSDictionary+AIQDocument.h"

@implementation NSDictionary (AIQDocument)

- (NSString *)identifier {
    return self[kAIQDocumentId];
}
- (NSString *)type {
    return self[kAIQDocumentType];
}

@end
