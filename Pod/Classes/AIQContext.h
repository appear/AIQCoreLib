#ifndef AIQCoreLib_AIQContext_h
#define AIQCoreLib_AIQContext_h

#import <Foundation/Foundation.h>

/*!
 @header AIQContext.h
 @author Marcin Lukow
 @copyright 2012 Appear Networks Systems AB
 @updated 2013-08-12
 @brief Convenience wrapper for Data Store for context operations.
 @version 1.0.0
 */

@class AIQDataStore;

EXTERN_API(NSString *) const AIQDidChangeContextValue;
EXTERN_API(NSString *) const AIQContextNameUserInfoKey;
EXTERN_API(NSString *) const AIQContextValueUserInfoKey;

/** AIQContext module.

 AIQContext module can be used to access both client and backed context documents.
 
 @since 1.0.0
 @see AIQDataStore
 */
@interface AIQContext : NSObject

/**---------------------------------------------------------------------------------------
 * @name Properties
 * ---------------------------------------------------------------------------------------
 */

/** Set of context providers.

 This is a set of context providers which are used to populate the client context document with their
 contextual data. Each context provider added to this set should be KVO compliant and expose two well known keys: name 
 being the name of the context provider (name should follow the convention of Java package names in order not to clash
 with other context providers, e.g. tld.domain.application.provider) and data which is used to populate the context
 with the information served by the context provider.
 
 @since 1.0.0
 */
@property (nonatomic, retain) NSSet *contextProviders;

/**---------------------------------------------------------------------------------------
 * @name Value management
 * ---------------------------------------------------------------------------------------
 */

/** Retrieves value for given key name.

 This method can be used to retrieve data for given content provider name. It first looks for a value in
 the client context and then, if not found, in backend context. If the same content provider name is defined in both
 contexts, client context has priority.
 
 @param name Name of the content provider for which to retrieve the data. Must not be nil.
 @param error If defined, will store an error in case of any failure. May be nil.
 @return Object value for given content provider or nil if retrieval failed, in which case the error parameter will
 contain the reason of failure.
 @since 1.0.0
 */
- (id)valueForName:(NSString *)name error:(NSError **)error;

/** Sets value for given key name.
 
 This method can be used to set a value for given content provider name in the client context.
 
 @param value Value to set for the given content provider name. May be nil, in which case JSON null value will be
 used instead.
 @param name Name of the content provider for which to set the value. Must not be nil.
 @param error If defined, will store an error in case of any failure. May be nil.
 @return YES when storing succeeded, NO otherwise, in which case the error parameter will contain the reason of 
 failure.
 @since 1.0.0
 */
- (BOOL)setValue:(id)value forName:(NSString *)name error:(NSError **)error;

- (BOOL)names:(void (^)(NSString *name, NSError **error))processor error:(NSError **)error;

- (void)close;

@end

#endif /* AIQCoreLib_AIQContext_h */
