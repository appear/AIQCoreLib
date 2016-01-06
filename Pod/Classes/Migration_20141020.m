#import "FMDBMigrationManager.h"

@interface Migration_20141020 : NSObject<FMDBMigrating>

@end

@implementation Migration_20141020

- (NSString *)name {
    return @"Adding solution support to datasync";
}

- (uint64_t)version {
    return 20141020;
}

- (BOOL)migrateDatabase:(FMDatabase *)db error:(out NSError *__autoreleasing *)error {
    if (! [db executeUpdate:@"ALTER TABLE documents ADD COLUMN solution TEXT NOT NULL DEFAULT '_global'"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    
    if (! [db executeUpdate:@"ALTER TABLE attachments ADD COLUMN solution TEXT NOT NULL DEFAULT '_global'"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    
    if (! [db executeUpdate:@"ALTER TABLE localdocuments ADD column solution TEXT NOT NULL DEFAULT '_global'"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    
    if (! [db executeUpdate:@"ALTER TABLE localattachments ADD column solution TEXT NOT NULL DEFAULT '_global'"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    
    if (! [db executeUpdate:@"ALTER TABLE somessages ADD column solution TEXT NOT NULL DEFAULT '_global'"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    
    if (! [db executeUpdate:@"ALTER TABLE comessages ADD column solution TEXT NOT NULL DEFAULT '_global'"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    
    if (! [db executeUpdate:@"ALTER TABLE coattachments ADD column solution TEXT NOT NULL DEFAULT '_global'"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    
    return YES;
}

@end
