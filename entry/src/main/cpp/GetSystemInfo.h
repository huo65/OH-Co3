
#ifndef TestStatisticsInfo_H
#define TestStatisticsInfo_H

#include <string>
#include <napi/native_api.h>
#include <map>
#include "common/native_common.h"
#include "common/plugin_common.h"

class GetSystemInfo {
public:
    static napi_value GetCpuUsage(napi_env env, napi_callback_info info);
    static napi_value GetMemUsage(napi_env env, napi_callback_info info);

private:
    static double calculateCpuUtilization();
    static double calculateMemUsage();
    static std::string getCpuStatLine(const std::string& field);
    static void parseMemInfo(long long& memTotal, long long& memAvailable);
    static long long parseMemoryValue(const std::string& line);
};
#endif
