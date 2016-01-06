#import <Foundation/Foundation.h>

/*!
 @header AIQLocationContextProvider.h
 @author Marcin Lukow
 @copyright 2014 Appear Networks Systems AB
 @updated 2014-03-31
 @brief AIQLocationContextProvider part of the DataSync module can be used to populate client context with the location information.
 @version 1.0
 */

/*!
 @interface AIQLocationContextProvider
 @abstract AIQLocationContextProvider submodule.
 @discussion This module provides means to populate the client context with the location information. It is compliant with the
 KVO model and is meant to be used together with the @link Context @/link submodule.
 */
@interface AIQLocationContextProvider : NSObject

/*!
 @property name
 @abstract Context provider name.
 @discussion This property stores the name of the context provider populated by this submodule.
 */
@property (nonatomic, readonly, getter = getName) NSString *name;

/*!
 @property data
 @abstract Context provider data.
 @discussion This property stores the data provided by this submodule.

 @note
 This property is monitored by the @link Context @/link submodule.
 */
@property (nonatomic, retain) NSDictionary *data;

@end
