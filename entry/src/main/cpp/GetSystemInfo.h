
#ifndef TestStatisticsInfo_H
#define TestStatisticsInfo_H

#include <string>
#include <napi/native_api.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdio.h>
#include <dirent.h>
#include <map>
#include "common/native_common.h"
#include "common/plugin_common.h"

class GetSystemInfo {
public:
    static napi_value GetCpuCount(napi_env env, napi_callback_info info);
    static napi_value GetMemTotal(napi_env env, napi_callback_info info);
    static napi_value GetAvailableMem(napi_env env, napi_callback_info info);
    static napi_value GetCpu_stat_cpu(napi_env env, napi_callback_info info);


private:
    static int getCpuCount();
    static std::string getMemInfoMap(std::string field);
    static std::string parseLine(std::string s);
    static std::string getCpu_stat(std::string field);
    static std::string calculateCpuUtilization(std::string& a, std::string& a_second);
    static std::map<std::string, std::string>_MemInfoMap;
    static std::map<std::string, std::string> _Cpu_stat;
};
#endif
