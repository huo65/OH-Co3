#include "napi/native_api.h"
#include "GetSystemInfo.h"
#include "common/plugin_common.h"


EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        { "getCpuUsage", nullptr, GetSystemInfo::GetCpuUsage, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getMemUsage", nullptr, GetSystemInfo::GetMemUsage, nullptr, nullptr, nullptr, napi_default, nullptr }
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module demoModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "entry",
    .nm_priv = ((void*)0),
    .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterEntryModule(void)
{
    napi_module_register(&demoModule);
}
