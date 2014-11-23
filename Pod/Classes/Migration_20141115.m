#import "AIQDataStore.h"
#import "FMDBMigrationManager.h"

@interface Migration_20141115 : NSObject<FMDBMigrating>

@end

@implementation Migration_20141115

- (NSString *)name {
    return @"Initial migration";
}

- (uint64_t)version {
    return 20141115;
}

- (BOOL)migrateDatabase:(FMDatabase *)database error:(out NSError *__autoreleasing *)error {
    if (! [database executeUpdate:@"CREATE TABLE documents ("
           "solution              TEXT    NOT NULL,"
           "identifier            TEXT    NOT NULL,"
           "type                  TEXT    NOT NULL,"
           "revision              INTEGER NOT NULL,"
           "synchronizationStatus TINYINT NOT NULL,"
           "rejectionReason       TINYINT           DEFAULT NULL,"
           "content               BLOB    NOT NULL,"
           "CONSTRAINT pk_identifier PRIMARY KEY (identifier))"]) {
        if (error) {
            *error = [database lastError];
        }
        return NO;
    }
    
    if (! [database executeUpdate:@"CREATE TABLE attachments ("
           "solution              TEXT    NOT NULL,"
           "identifier            TEXT    NOT NULL,"
           "name                  TEXT    NOT NULL,"
           "revision              INTEGER NOT NULL DEFAULT 0,"
           "contentType           TEXT    NOT NULL,"
           "link                  TEXT             DEFAULT NULL,"
           "state                 TINYINT NOT NULL,"
           "synchronizationStatus TINYINT NOT NULL,"
           "rejectionReason       TINYINT          DEFAULT NULL,"
           "CONSTRAINT pk_identifier_name PRIMARY KEY (identifier, name),"
           "CONSTRAINT fk_identifier      FOREIGN KEY (identifier) REFERENCES documents (identifier))"]) {
        if (error) {
            *error = [database lastError];
        }
        return NO;
    }
    
    return YES;
}

@end
