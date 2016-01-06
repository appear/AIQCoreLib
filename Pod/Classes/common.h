#ifndef AIQCoreLib_common_h
#define AIQCoreLib_common_h

#ifndef NOTIFY
    #define NOTIFY(n, o, u)                                                                    \
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{           \
            [[NSNotificationCenter defaultCenter] postNotificationName:n object:o userInfo:u]; \
        });
#endif /* NOTIFY */

#ifndef LISTEN
    #define LISTEN(o, s, n)                                     \
        [[NSNotificationCenter defaultCenter] addObserver:o     \
                                                 selector:s     \
                                                     name:n     \
                                                   object:nil];
#endif /* LISTEN */

#endif
