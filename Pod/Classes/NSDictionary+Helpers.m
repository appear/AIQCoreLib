#import <regex.h>

#import "AIQError.h"
#import "AIQJSON.h"
#import "NSDictionary+Helpers.h"
#import "NSString+Helpers.h"

@interface XMLReader : NSObject<NSXMLParserDelegate>

@property (nonatomic, retain) NSMutableArray *dictionaryStack;
@property (nonatomic, retain) NSMutableString *textInProgress;

@end

@implementation XMLReader

+ (NSDictionary *)dictionaryForXMLData:(NSData *)data {
    XMLReader *reader = [[XMLReader alloc] init];
    NSDictionary *rootDictionary = [reader objectWithData:data];
    return rootDictionary;
}

- (NSDictionary *)objectWithData:(NSData *)data {
    _dictionaryStack = [[NSMutableArray alloc] init];
    _textInProgress = [[NSMutableString alloc] init];
    [_dictionaryStack addObject:[NSMutableDictionary dictionary]];
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    parser.delegate = self;
    BOOL success = [parser parse];
    return (success) ? _dictionaryStack[0] : nil;
}

- (void)parser:(NSXMLParser *)parser
didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
    attributes:(NSDictionary *)attributeDict {
    NSMutableDictionary *parentDict = [_dictionaryStack lastObject];
    NSMutableDictionary *childDict = [NSMutableDictionary dictionary];
    [childDict addEntriesFromDictionary:attributeDict];
    id existingValue = parentDict[elementName];
    if (existingValue) {
        NSMutableArray *array = nil;
        if ([existingValue isKindOfClass:[NSMutableArray class]]) {
            array = (NSMutableArray *)existingValue;
        } else {
            array = [NSMutableArray array];
            [array addObject:existingValue];
            parentDict[elementName] = array;
        }
        [array addObject:childDict];
    } else {
        parentDict[elementName] = childDict;
    }
    [_dictionaryStack addObject:childDict];
}

- (void)parser:(NSXMLParser *)parser
 didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName {
    NSMutableDictionary *dictInProgress = [_dictionaryStack lastObject];
    if ([_textInProgress length] > 0) {
        [dictInProgress setObject:_textInProgress forKey:@"text"];
        _textInProgress = [[NSMutableString alloc] init];
    }
    [_dictionaryStack removeLastObject];
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    NSString *trimmed = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length > 0) {
        [_textInProgress appendString:string];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
    // do nothing
}

@end

@implementation NSDictionary (Helpers)

+ (NSDictionary *)dictionaryFromXML:(NSData *)xml {
    return [XMLReader dictionaryForXMLData:xml];
}

- (NSString *)asQuery {
    NSMutableArray *pairs = [NSMutableArray array];
    for (NSString *key in self) {
        NSString *sanitizedKey = [key URLEncode];
        id value = self[key];
        NSString *string = [[NSString stringWithFormat:@"%@", value] URLEncode];
        [pairs addObject:[NSString stringWithFormat:@"%@=%@", sanitizedKey, string]];
    }
    return [pairs componentsJoinedByString:@"&"];
}

- (BOOL)matches:(NSDictionary *)pattern error:(NSError *__autoreleasing *)error {
    return [self compare:self to:pattern error:error];
}

- (BOOL)compare:(id)source to:(id)pattern error:(NSError *__autoreleasing *)error {
    BOOL result = YES;
    if (([source isKindOfClass:[NSDictionary class]]) && ([pattern isKindOfClass:[NSDictionary class]])) {
        // inception, we have to go deeper >_<
        NSArray *keys = [pattern allKeys];
        for (NSInteger i = 0; (i < keys.count) && (result); i++) {
            id key = keys[i];
            id sourceValue = [source objectForKey:key];
            if (sourceValue) {
                id patternValue = [pattern objectForKey:key];
                result = [self compare:sourceValue to:patternValue error:error];
            } else {
                result = NO;
            }
        }
    } else if (([source isKindOfClass:[NSArray class]]) && ([pattern isKindOfClass:[NSArray class]])) {
        // match array elements
        if ([source count] == [pattern count]) {
            for (NSInteger i = 0; (i < [source count]) && ((! error) || (! *error)); i++) {
                result = [self compare:source[i] to:pattern[i] error:error];
            }
        } else {
            result = NO;
        }
    } else if (([source isKindOfClass:[NSNumber class]]) && ([pattern isKindOfClass:[NSArray class]])) {
        // texas range(r)
        NSArray *array = (NSArray *)pattern;
        if (array.count == 2) {
            BOOL leftConcrete = (array[0] != [NSNull null]);
            BOOL rightConcrete = (array[1] != [NSNull null]);
            if ((leftConcrete) && (! [array[0] isKindOfClass:[NSNumber class]])) {
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:[NSString stringWithFormat:@"Invalid range: %@", [array JSONString]]];
                }
                result = NO;
            } else if ((rightConcrete) && (! [array[1] isKindOfClass:[NSNumber class]])) {
                if (error) {
                    *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:[NSString stringWithFormat:@"Invalid range: %@", [array JSONString]]];
                }
                result = NO;
            } else {
                if (leftConcrete) {
                    NSComparisonResult comparisonResult = [(NSNumber *)source compare:(NSNumber *)array[0]];
                    result = (comparisonResult == NSOrderedSame) || (comparisonResult == NSOrderedDescending);
                }
                if ((result) && (rightConcrete)) {
                    NSComparisonResult comparisonResult = [(NSNumber *)source compare:(NSNumber *)array[1]];
                    result = (comparisonResult == NSOrderedSame) || (comparisonResult == NSOrderedAscending);
                }
            }

        } else {
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:[NSString stringWithFormat:@"Invalid range: %@", [array JSONString]]];
            }
            result = NO;
        }
    } else if (([source isKindOfClass:[NSNumber class]]) && ([pattern isKindOfClass:[NSNumber class]])) {
        // two numbers, ohai floating points!
        result = [(NSNumber *)source isEqualToNumber:(NSNumber *)pattern];
    } else {
        // two objects reduced to strings
        regex_t regex;
        int errcode = regcomp(&regex, [[pattern description] cStringUsingEncoding:NSUTF8StringEncoding], REG_EXTENDED);
        if (errcode) {
            // invalid regular expression
            if (error) {
                *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:[self stringFromRegexError:errcode forRegex:regex]];
            }
            result = NO;
        } else {
            errcode = regexec(&regex, [[source description] cStringUsingEncoding:NSUTF8StringEncoding], 0, NULL, 0);
            if (errcode) {
                result = NO;
                // invalid regular expression
                if (errcode != REG_NOMATCH) {
                    if (error) {
                        *error = [AIQError errorWithCode:AIQErrorInvalidArgument message:[self stringFromRegexError:errcode forRegex:regex]];
                    }
                }
            }
        }
        regfree(&regex);
    }
    return result;
}

- (NSString *)stringFromRegexError:(int)error forRegex:(regex_t)regex {
    char *errbuf;
    size_t errbuf_size;
    errbuf_size = regerror(error, &regex, NULL, 0);
    if (! (errbuf = (char *)malloc(errbuf_size))) {
        perror("malloc error!");
        exit(255);
    };
    regerror(error, &regex, errbuf, errbuf_size);
    NSString *result = @(errbuf);
    free(errbuf);
    return result;
}

@end
