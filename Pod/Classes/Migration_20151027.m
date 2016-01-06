#import "FMDBMigrationManager.h"

@interface Migration_20151027 : NSObject<FMDBMigrating>

@end

@implementation Migration_20151027

- (NSString *)name {
    return @"Fixing primary keys";
}

- (uint64_t)version {
    return 20151027;
}

- (BOOL)migrateDatabase:(FMDatabase *)db error:(out NSError *__autoreleasing *)error {
    if (! [db executeUpdate:@"CREATE TABLE documents_new ("
           "solution        TEXT    NOT NULL DEFAULT '_global',"
           "identifier      TEXT    NOT NULL,"
           "launchable      TEXT             DEFAULT NULL,"
           "type            TEXT    NOT NULL,"
           "revision        INTEGER NOT NULL DEFAULT 0,"
           "status          TINYINT NOT NULL,"
           "rejectionReason TINYINT          DEFAULT NULL,"
           "data            BLOB    NOT NULL,"
           "CONSTRAINT pk_solution_identifier PRIMARY KEY (solution, identifier))"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    if (! [db executeUpdate:@"CREATE TABLE attachments_new ("
           "solution        TEXT    NOT NULL DEFAULT '_global',"
           "identifier      TEXT    NOT NULL,"
           "name            TEXT    NOT NULL,"
           "revision        INTEGER NOT NULL DEFAULT 0,"
           "contentType     TEXT    NOT NULL,"
           "link            TEXT             DEFAULT NULL,"
           "state           TINYINT NOT NULL,"
           "status          TINYINT NOT NULL,"
           "rejectionReason TINYINT          DEFAULT NULL,"
           "CONSTRAINT pk_solution_identifier_name PRIMARY KEY (solution, identifier, name),"
           "CONSTRAINT fk_solution_identifier FOREIGN KEY (solution, identifier) REFERENCES documents_new (solution, identifier))"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    
    if (! [db executeUpdate:@"INSERT INTO documents_new (solution, identifier, launchable, type, revision, status, rejectionReason, data) "
           "SELECT solution, identifier, launchable, type, revision, status, rejectionReason, data FROM documents"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    
    if (! [db executeUpdate:@"DROP TABLE documents"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    
    if (! [db executeUpdate:@"ALTER TABLE documents_new RENAME TO documents"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    
    if (! [db executeUpdate:@"INSERT INTO attachments_new (solution, identifier, name, revision, contentType, link, state, status, rejectionReason) "
           "SELECT solution, identifier, name, revision, contentType, link, state, status, rejectionReason FROM attachments"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    
    if (! [db executeUpdate:@"DROP TABLE attachments"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    
    if (! [db executeUpdate:@"ALTER TABLE attachments_new RENAME TO attachments"]) {
        if (error) {
            *error = [db lastError];
        }
        return NO;
    }
    
    return YES;
}

@end
