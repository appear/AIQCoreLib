/*
 The MIT License (MIT)

 Copyright (c) 2015 Appear Networks AB

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

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
