#ifndef __RAYLIB_EXTRA_H__
#define __RAYLIB_EXTRA_H__

#include <stdarg.h>

typedef void (*TraceLogCallback)(int logLevel, const char *text, va_list args);
typedef void (*ExtTraceLogCallback)(int logLevel, const char *text);

ExtTraceLogCallback extTraceLogCallback = 0;

void SetTraceLogCallback(TraceLogCallback callback);

void raylib_extra_callback(int logLevel, const char *text, va_list args)
{
    if (extTraceLogCallback != 0)
    {
        char buffer[1024] = { 0 };
        vsnprintf(buffer, 1024, text, args);
        extTraceLogCallback(logLevel, buffer);
    }
}

void ExtSetTraceLogCallback(ExtTraceLogCallback cb)
{
    extTraceLogCallback = cb;
    SetTraceLogCallback(raylib_extra_callback);
}

#endif // __RAYLIB_EXTRA_H__