#ifndef _PLUGIN_COMMON_H_
#define _PLUGIN_COMMON_H_

#include <stdint.h>
#include <hilog/log.h>
#include <stddef.h>

#define APP_LOG_DOMAIN 0x0001
#define APP_LOG_TAG "XComponent_Native"
#define LOGI(...) ((void)OH_LOG_Print(LOG_APP, LOG_INFO, APP_LOG_DOMAIN, APP_LOG_TAG, __VA_ARGS__))
#define LOGD(...) ((void)OH_LOG_Print(LOG_APP, LOG_DEBUG, APP_LOG_DOMAIN, APP_LOG_TAG, __VA_ARGS__))
#define LOGW(...) ((void)OH_LOG_Print(LOG_APP, LOG_WARN, APP_LOG_DOMAIN, APP_LOG_TAG, __VA_ARGS__))
#define LOGE(...) ((void)OH_LOG_Print(LOG_APP, LOG_ERROR, APP_LOG_DOMAIN, APP_LOG_TAG, __VA_ARGS__))
/**
 * Get context parameter count.
 */
const size_t GET_CONTEXT_PARAM_CNT = 1;
/**
 * Context type.
 */
enum ContextType {
    APP_LIFECYCLE = 0,
    PAGE_LIFECYCLE,
    RAW_FILE_UTILS,
};

const int32_t kMaxStringLen = 512;

#endif // _PLUGIN_COMMON_H_