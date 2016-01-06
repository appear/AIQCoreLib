#import "FMDBMigrationManager.h"

@interface Migration_20141014 : NSObject<FMDBMigrating>

@end

@implementation Migration_20141014

- (NSString *)name {
    return @"Creating tables";
}

- (uint64_t)version {
    return 20141014;
}

- (BOOL)migrateDatabase:(FMDatabase *)db error:(out NSError *__autoreleasing *)error {
    if (! [db executeUpdate:@"CREATE TABLE documents ("
                             "identifier      TEXT    NOT NULL,"
                             "launchable      TEXT             DEFAULT NULL,"
                             "type            TEXT    NOT NULL,"
                             "revision        INTEGER NOT NULL DEFAULT 0,"
                             "status          TINYINT NOT NULL,"
                             "rejectionReason TINYINT          DEFAULT NULL,"
                             "data            BLOB    NOT NULL,"
                             "CONSTRAINT pk_identifier PRIMARY KEY (identifier))"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    if (! [db executeUpdate:@"CREATE TABLE attachments ("
                             "identifier      TEXT    NOT NULL,"
                             "name            TEXT    NOT NULL,"
                             "revision        INTEGER NOT NULL DEFAULT 0,"
                             "contentType     TEXT    NOT NULL,"
                             "link            TEXT             DEFAULT NULL,"
                             "state           TINYINT NOT NULL,"
                             "status          TINYINT NOT NULL,"
                             "rejectionReason TINYINT          DEFAULT NULL,"
                             "CONSTRAINT pk_identifier_name PRIMARY KEY (identifier, name),"
                             "CONSTRAINT fk_identifier FOREIGN KEY (identifier) REFERENCES documents (identifier))"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    
    if (! [db executeUpdate:@"CREATE TABLE comessages ("
                             "orderId        INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,"
                             "identifier     TEXT    NOT NULL,"
                             "destination    TEXT    NOT NULL,"
                             "state          TINYINT NOT NULL DEFAULT 0,"
                             "payload        BLOB    NOT NULL,"
                             "created        INTEGER NOT NULL,"
                             "timeToLive     INTEGER,"
                             "response       TEXT,"
                             "responseId     TEXT,"
                             "urgent         TINYINT NOT NULL DEFAULT 0,"
                             "expectResponse TINYINT NOT NULL DEFAULT 1,"
                             "launchable TEXT)"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    if (! [db executeUpdate:@"CREATE TABLE coattachments ("
                             "identifier  TEXT NOT NULL,"
                             "name        TEXT NOT NULL,"
                             "contentType TEXT NOT NULL,"
                             "link        TEXT NOT NULL,"
                             "CONSTRAINT pk_identifier_name PRIMARY KEY (identifier, name),"
                             "CONSTRAINT fk_identifier FOREIGN KEY (identifier) REFERENCES comessages (identifier) ON DELETE CASCADE)"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    
    if (! [db executeUpdate:@"CREATE TABLE somessages ("
                             "identifier TEXT    NOT NULL,"
                             "type       TEXT    NOT NULL,"
                             "created    INTEGER NOT NULL,"
                             "activeFrom INTEGER NOT NULL,"
                             "timeToLive INTEGER NOT NULL,"
                             "read       TINYINT NOT NULL DEFAULT 0,"
                             "revision   INTEGER NOT NULL DEFAULT 1,"
                             "CONSTRAINT pk_identifier PRIMARY KEY (identifier))"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    
    if (! [db executeUpdate:@"CREATE TABLE localdocuments ("
                             "identifier TEXT NOT NULL,"
                             "type       TEXT NOT NULL,"
                             "data       BLOB NOT NULL,"
                             "CONSTRAINT pk_identifier PRIMARY KEY (identifier))"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    if (! [db executeUpdate:@"CREATE TABLE localattachments ("
                             "identifier  TEXT NOT NULL,"
                             "name        TEXT NOT NULL,"
                             "contentType TEXT NOT NULL,"
                             "CONSTRAINT pk_identifier_name PRIMARY KEY (identifier, name),"
                             "CONSTRAINT fk_identifier FOREIGN KEY (identifier) REFERENCES localdocuments (identifier) ON DELETE CASCADE)"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }

    return YES;
}

@end
