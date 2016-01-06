#ifndef AIQLib_DeviceContextProvider_h
#define AIQLib_DeviceContextProvider_h

#import <Foundation/Foundation.h>

/*!
 @header DeviceContextProvider.h
 @author Marcin Lukow
 @copyright 2012 Appear Networks Systems AB
 @updated 2013-08-12
 @brief DeviceContextProvider part of the DataSync module can be used to populate client context with the device information.
 @version 1.0
 */

/*!
 @interface DeviceContextProvider
 @abstract DeviceContextProvider submodule.
 @discussion This module provides means to populate the client context with the device information. It is compliant with the
 KVO model and is meant to be used together with the @link Context @/link submodule.
 */
@interface DeviceContextProvider : NSObject

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

#endif /* AIQLib_DeviceContextProvider_h */
