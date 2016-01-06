#import "FMDBMigrationManager.h"

@interface Migration_20141104 : NSObject<FMDBMigrating>

@end

@implementation Migration_20141104

- (NSString *)name {
    return @"Adding support flag for backend mesages";
}

- (uint64_t)version {
    return 20141104;
}

- (BOOL)migrateDatabase:(FMDatabase *)db error:(out NSError *__autoreleasing *)error {
    if (! [db executeUpdate:@"ALTER TABLE somessages ADD COLUMN actual TINYINT NOT NULL DEFAULT 1"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    
    return YES;
}

@end
