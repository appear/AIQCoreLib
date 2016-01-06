#ifndef AIQCoreLib_NSDictionary_Helpers
#define AIQCoreLib_NSDictionary_Helpers

#import <Foundation/Foundation.h>

/*!
 @header NSDictionary+Helpers
 @author Marcin Lukow
 @copyright 2012 Appear Networks Systems AB
 @updated 2013-08-12
 @brief Utility extension for NSDictionary class.
 @version 1.0
 */

@interface NSDictionary (Helpers)

/** Returns dictionary representation of the given XML.

 This method can be used to construct a dictionary from the binary data containing an XML document.
 @param xml binary data containing XML document, must not be null
 @return dictionary representation of the XML document or nil if the binary data does not contain a valid XML document
 @since 1.0.0
 */
+ (NSDictionary *)dictionaryFromXML:(NSData *)xml;

/** Returns query representation of the dictionary.
 
 This method returns a string query containing JSON object constructed from the dictionary values.

 @return Query string, will not be nil
 @since 1.0.0
 */
- (NSString *)asQuery;

/** Tells whether the dictionary matches given pattern.

 This method can be used to compare the dictionary with given argument.

 @param pattern Pattern to which to compare the dictionary. All keys specified in the pattern must be present in the
 dictionary. Values can contain regular expressions. Must not be nil.
 @param error NSError instance which, in case of any failure, will be populated with the reason of that failure.
 @return YES if the dictionary matches the given pattern, NO otherwise
 @since 1.0.0
 */
- (BOOL)matches:(NSDictionary *)pattern error:(NSError **)error;

@end

#endif /* AIQCoreLib_NSDictionary_Helpers */
