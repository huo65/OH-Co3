
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

class TestStatisticsInfo {
public:
    static bool Export(napi_env env, napi_value exports);
    static napi_value GetCpuCount(napi_env env, napi_callback_info info);
    static napi_value GetMemTotal(napi_env env, napi_callback_info info);
    static napi_value GetFreeMem(napi_env env, napi_callback_info info);
    static napi_value GetCachedMem(napi_env env, napi_callback_info info);
    static napi_value GetCpuInfo(napi_env env, napi_callback_info info);
    static napi_value GetMemoryInfo(napi_env env, napi_callback_info info);
    static napi_value GetAvailableMem(napi_env env, napi_callback_info info);
    static napi_value GetUptime(napi_env env, napi_callback_info info);
    static napi_value GetSOCtemp(napi_env env, napi_callback_info info);
    static napi_value GetCPU_CORE_big7_thmzonetemp(napi_env env, napi_callback_info info);
    static napi_value GetCPU_CORE_mid6_thmzonetemp(napi_env env, napi_callback_info info);
    static napi_value GetCPU_CORE_mid5_thmzonetemp(napi_env env, napi_callback_info info);
    static napi_value GetCPU_CORE_mid4_thmzonetemp(napi_env env, napi_callback_info info);
    static napi_value GetCPU_CORE_lit3_thmzonetemp(napi_env env, napi_callback_info info);
    static napi_value GetCPU_CORE_lit2_thmzonetemp(napi_env env, napi_callback_info info);
    static napi_value GetCPU_CORE_lit1_thmzonetemp(napi_env env, napi_callback_info info);
    static napi_value GetCPU_CORE_lit0_thmzonetemp(napi_env env, napi_callback_info info);
    static napi_value GetGPU_temp(napi_env env, napi_callback_info info);
    static napi_value GetBoard_temp(napi_env env, napi_callback_info info);
    static napi_value GetSwaps(napi_env env, napi_callback_info info);
    static napi_value GetRTC_Date_temp(napi_env env, napi_callback_info info);
    static napi_value GetKernel_version(napi_env env, napi_callback_info info);
    static napi_value GetRTC_Time_temp(napi_env env, napi_callback_info info);
    static napi_value GetCpu_stat_cpu(napi_env env, napi_callback_info info);
    static napi_value Getprocesses(napi_env env, napi_callback_info info);
    static napi_value Getctxt(napi_env env, napi_callback_info info);
    static napi_value Getcpuinfo_hardware(napi_env env, napi_callback_info info);
    //
    
private:
    static bool getCpuInfo();
    static bool getMemoryInfo();
    static int getCpuCount();
    static std::string getMemInfoMap(std::string field);
    static std::string parseLine(std::string s);
    static std::string getUptime();
    static std::string getSOCtemp();
    static std::string getCPU_CORE_big7_thmzonetemp();
    static std::string getCPU_CORE_mid6_thmzonetemp();
    static std::string getCPU_CORE_mid5_thmzonetemp();
    static std::string getCPU_CORE_mid4_thmzonetemp();
    static std::string getCPU_CORE_lit3_thmzonetemp();
    static std::string getCPU_CORE_lit2_thmzonetemp();
    static std::string getCPU_CORE_lit1_thmzonetemp();
    static std::string getCPU_CORE_lit0_thmzonetemp();
    static std::string getGPU_temp();
    static std::string getBoard_temp();
    static std::string getSwaps();
    static std::string getRTC_Date_temp();
    static std::string getKernel_version();
    static std::string getRTC_Time_temp();
    static std::string getCpu_stat(std::string field);
    static std::string calculateCpuUtilization(std::string& a, std::string& a_second);
    static std::string getcpuinfo_hardware();

    static std::map<std::string, std::string>_MemInfoMap;
    static std::map<std::string, std::string> _Cpu_stat;
};
#endif //TestFileModule_H
