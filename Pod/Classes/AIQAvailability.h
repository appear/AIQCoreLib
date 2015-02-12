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

#ifndef AIQCoreLib_AIQAvailability_h
#define AIQCoreLib_AIQAvailability_h

#define __AIQCoreLib_1_0_0 10000

#ifndef AIQ_VERSION_MIN_REQUIRED
    #define AIQ_VERSION_MIN_REQUIRED __AIQCoreLib_1_0_0
#endif

#define AIQ_VERSION [NSString stringWithFormat:@"%d.%d.%d",      \
                     (AIQ_VERSION_MIN_REQUIRED / 10000),         \
                     ((AIQ_VERSION_MIN_REQUIRED % 10000) / 100), \
                     ((AIQ_VERSION_MIN_REQUIRED % 10000) % 100)]

#endif /* AIQCoreLib_AIQAvailability_h */