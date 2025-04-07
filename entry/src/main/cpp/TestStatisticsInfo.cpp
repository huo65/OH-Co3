#include "TestStatisticsInfo.h"
#include <set>
#include <unistd.h>
#include <fstream>
#include <string>
#include <sstream>
#include <chrono>
#include <thread>

const int GLOBAL_RESMGR = 0xFF00;
const char *TAG = "[Sample_rawfile]";

std::map<std::string, std::string> TestStatisticsInfo::_MemInfoMap;

std::map<std::string, std::string> TestStatisticsInfo::_Cpu_stat;

bool TestStatisticsInfo::Export(napi_env env, napi_value exports) {
    if ((nullptr == env) || (nullptr == exports)) {
        LOGE("PluginRender::Export: env or exports is null");
        return false;
    }
    napi_property_descriptor desc[] = {
        DECLARE_NAPI_FUNCTION("getCpuCount", TestStatisticsInfo::GetCpuCount),
        DECLARE_NAPI_FUNCTION("getMemTotal", TestStatisticsInfo::GetMemTotal),
        DECLARE_NAPI_FUNCTION("getFreeMem", TestStatisticsInfo::GetFreeMem),
        DECLARE_NAPI_FUNCTION("getCachedMem", TestStatisticsInfo::GetCachedMem),
        DECLARE_NAPI_FUNCTION("getCpuInfo", TestStatisticsInfo::GetCpuInfo),
        DECLARE_NAPI_FUNCTION("getMemoryInfo", TestStatisticsInfo::GetMemoryInfo),
        DECLARE_NAPI_FUNCTION("getAvailableMem", TestStatisticsInfo::GetAvailableMem),
        DECLARE_NAPI_FUNCTION("getUptime", TestStatisticsInfo::GetUptime),
        DECLARE_NAPI_FUNCTION("getSOCtemp", TestStatisticsInfo::GetSOCtemp),
        DECLARE_NAPI_FUNCTION("getCPU_CORE_big7_thmzonetemp", TestStatisticsInfo::GetCPU_CORE_big7_thmzonetemp),
        DECLARE_NAPI_FUNCTION("getCPU_CORE_mid6_thmzonetemp", TestStatisticsInfo::GetCPU_CORE_mid6_thmzonetemp),
        DECLARE_NAPI_FUNCTION("getCPU_CORE_mid5_thmzonetemp", TestStatisticsInfo::GetCPU_CORE_mid5_thmzonetemp),
        DECLARE_NAPI_FUNCTION("getCPU_CORE_mid4_thmzonetemp", TestStatisticsInfo::GetCPU_CORE_mid4_thmzonetemp),
        DECLARE_NAPI_FUNCTION("getCPU_CORE_lit3_thmzonetemp", TestStatisticsInfo::GetCPU_CORE_lit3_thmzonetemp),
        DECLARE_NAPI_FUNCTION("getCPU_CORE_lit2_thmzonetemp", TestStatisticsInfo::GetCPU_CORE_lit2_thmzonetemp),
        DECLARE_NAPI_FUNCTION("getCPU_CORE_lit1_thmzonetemp", TestStatisticsInfo::GetCPU_CORE_lit1_thmzonetemp),
        DECLARE_NAPI_FUNCTION("getCPU_CORE_lit0_thmzonetemp", TestStatisticsInfo::GetCPU_CORE_lit0_thmzonetemp),
        DECLARE_NAPI_FUNCTION("getGPU_temp", TestStatisticsInfo::GetGPU_temp),
        DECLARE_NAPI_FUNCTION("getBoard_temp", TestStatisticsInfo::GetBoard_temp),
        DECLARE_NAPI_FUNCTION("getSwaps", TestStatisticsInfo::GetSwaps),
        DECLARE_NAPI_FUNCTION("getKernel_version", TestStatisticsInfo::GetKernel_version),
        DECLARE_NAPI_FUNCTION("getRTC_Date_temp", TestStatisticsInfo::GetRTC_Date_temp),
        DECLARE_NAPI_FUNCTION("getRTC_Time_temp", TestStatisticsInfo::GetRTC_Time_temp),
        DECLARE_NAPI_FUNCTION("getCpu_stat_cpu", TestStatisticsInfo::GetCpu_stat_cpu),
        DECLARE_NAPI_FUNCTION("getprocesses", TestStatisticsInfo::Getprocesses),
        DECLARE_NAPI_FUNCTION("getctxt", TestStatisticsInfo::Getctxt),
        DECLARE_NAPI_FUNCTION("getcpuinfo_hardware", TestStatisticsInfo::Getcpuinfo_hardware),
        
        //
    };

    if (napi_ok != napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc)) {
        LOGE("PluginRender::Export: napi_define_properties failed");
        return false;
    }
    return true;
}

napi_value TestStatisticsInfo::GetMemoryInfo(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::copyFile: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::copyFile: napi_get_cb_info fail");
        return nullptr;
    }

    if (getMemoryInfo()) {
        LOGI("getMemoryInfo success");
    }
    return nullptr;
}

napi_value TestStatisticsInfo::GetCpuInfo(napi_env env, napi_callback_info info) {
    LOGI("GetCpuInfo");
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetCpuInfo: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetCpuInfo: napi_get_cb_info fail");
        return nullptr;
    }

    if (getCpuInfo()) {
        LOGI("getCpuInfo success");
    }
    return nullptr;
}

napi_value TestStatisticsInfo::GetCpuCount(napi_env env, napi_callback_info info)
{
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetCpuCount: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetCpuCount: napi_get_cb_info fail");
        return nullptr;
    }

    int cpuCount = getCpuCount();
    if (cpuCount) {
        LOGI("getCpuCount success");
        napi_value res;
        napi_create_int32(env, cpuCount, &res);
        return res;
    }
    return nullptr;
}

napi_value TestStatisticsInfo::GetMemTotal(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetMemTotal: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetMemTotal: napi_get_cb_info fail");
        return nullptr;
    }
    
    std::string memTotal = getMemInfoMap("MemTotal");
    LOGI("getMemInfoMap MemTotal success %{public}s", memTotal.c_str());
    napi_value res;
    napi_create_string_utf8(env, memTotal.c_str(), strlen(memTotal.c_str()), &res);
    return res;
}

napi_value TestStatisticsInfo::GetFreeMem(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetFreeMem: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetFreeMem: napi_get_cb_info fail");
        return nullptr;
    }
    
    std::string FreeMem = getMemInfoMap("MemFree");
    LOGI("GetFreeMem success, MemFree is %{public}s", FreeMem.c_str());
    napi_value res;
    napi_create_string_utf8(env, FreeMem.c_str(), strlen(FreeMem.c_str()), &res);
    return res;
}

napi_value TestStatisticsInfo::GetAvailableMem(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetFreeMem: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetFreeMem: napi_get_cb_info fail");
        return nullptr;
    }

    std::string FreeMem = getMemInfoMap("MemAvailable");
    LOGI("GetFreeMem success, MemFree is %{public}s", FreeMem.c_str());
    napi_value res;
    napi_create_string_utf8(env, FreeMem.c_str(), strlen(FreeMem.c_str()), &res);
    return res;
}

napi_value TestStatisticsInfo::GetCachedMem(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetCachedMem: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetCachedMem: napi_get_cb_info fail");
        return nullptr;
    }
    std::string cached = getMemInfoMap("Cached");
    LOGI("getMemInfoMap success! Cached is %{public}s", cached.c_str());
    napi_value res;
    napi_create_string_utf8(env, cached.c_str(), strlen(cached.c_str()), &res);
    return res;
}

int TestStatisticsInfo::getCpuCount() {
    FILE *fp = fopen("/proc/cpuinfo", "r");
    if (NULL == fp) {
        LOGE("TestStatisticsInfo::getCpuInfo failed to open cpuinfo =======");
        return 0;
    }
    size_t count{};
    char buffer[1024]{};
    while (fgets(buffer, sizeof(buffer), fp) != nullptr) {
        std::string line{buffer};
        auto it = std::find_if(line.begin(), line.end(), [](char c) { return (c == ':'); });

        if (it == line.end()) {
            continue;
        }

        std::string keyLine{line.begin(), it};
        std::string key = "processor";
        if (keyLine.find(key) != std::string::npos) {
            count++;
        }
    }
    LOGE("TestStatisticsInfo::getCpuCount Cpu count is %{public}d =======", count);
    fclose(fp);
    return count;
}

std::string TestStatisticsInfo::parseLine(std::string line) {
    if (!line.empty()) {
        std::string res = line.substr(line.find(":") + 1);
        res.erase(0, res.find_first_not_of(" "));
        res.erase(res.find_last_not_of(" ") + 1);
        return res;
    }
    return line;
}

std::string TestStatisticsInfo::getMemInfoMap(std::string field) {
    
    std::ifstream meminfo("/proc/meminfo");
    std::string line;
    std::string totalField = "MemTotal";
    std::string freeField = "MemFree";
    std::string cachedField = "Cached";
    std::string memavailableField = "MemAvailable";
    while (getline(meminfo, line)) {
        if (line.find("MemTotal") != std::string::npos) {
            std::string res = parseLine(line);
            _MemInfoMap[totalField] = res;
        } else if (line.find("MemFree") != std::string::npos) {
            std::string res = parseLine(line);
            _MemInfoMap[freeField] = res;
        } else if (line.find("MemAvailable") != std::string::npos) {
            std::string res = parseLine(line);
            _MemInfoMap[memavailableField] = res;
        } else if (line.compare(0, 6, "Cached") == 0) {
            std::string res = parseLine(line);
            _MemInfoMap[cachedField] = res;
        }
    }
    return _MemInfoMap[field];
}

/***************************************************************************************/
// proc/stat 文件提供了系统中的 CPU 和其他统计数据。
//
// 以下是每行中各列的含义：
//
// cpu: 总体 CPU 统计信息
// cpu0, cpu1, cpu2, …: 每个逻辑 CPU 的统计信息
// intr: 中断统计信息
// ctxt: 上下文切换的总数
// btime: 启动时间
// processes: 启动的进程数
// procs_running: 当前运行的进程数
// procs_blocked: 被阻塞的进程数
// softirq: 软中断统计信息

//计算cpu利用率
std::string TestStatisticsInfo::calculateCpuUtilization(std::string& a,std::string& a_second) {
    std::istringstream iss_a(a);
    std::istringstream iss_a_second(a_second);

    // 提取每个字段的值
    std::string cpu_name, cpu_name_second;
    int user, nice, system, idle, iowait, irq, softirq, steal, guest, guest_nice;
    int user_second, nice_second, system_second, idle_second, iowait_second, irq_second, softirq_second, steal_second,
        guest_second, guest_nice_second;

    iss_a >> cpu_name >> user >> nice >> system >> idle >> iowait >> irq >> softirq >> steal >> guest >> guest_nice;
    iss_a_second >> cpu_name_second >> user_second >> nice_second >> system_second >> idle_second >> iowait_second >>
        irq_second >> softirq_second >> steal_second >> guest_second >> guest_nice_second;

    // 计算总的 CPU 时间和空闲 CPU 时间
    int total_time = user + nice + system + idle + iowait + irq + softirq + steal;
    int total_time_second = user_second + nice_second + system_second + idle_second + iowait_second + irq_second +
                            softirq_second + steal_second;
    int idle_time = idle + iowait;
    int idle_time_second = idle_second + iowait_second;

    // 计算 CPU 利用率
    double cpu_utilization =
        100.0 * (1.0 - (idle_time_second - idle_time) / static_cast<double>(total_time_second - total_time));
    
    return std::to_string(cpu_utilization);
}

// 计算cpu利用率
napi_value TestStatisticsInfo::GetCpu_stat_cpu(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetCachedMem: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetCpu_stat_cpu: napi_get_cb_info fail");
        return nullptr;
    }
    std::string cpu_cached0 = getCpu_stat("cpu\u0020");
    std::string cpu0_cached0 = getCpu_stat("cpu0");
    std::string cpu1_cached0 = getCpu_stat("cpu1");
    std::string cpu2_cached0 = getCpu_stat("cpu2");
    std::string cpu3_cached0 = getCpu_stat("cpu3");
    std::string cpu4_cached0 = getCpu_stat("cpu4");
    std::string cpu5_cached0 = getCpu_stat("cpu5");
    std::string cpu6_cached0 = getCpu_stat("cpu6");
    std::string cpu7_cached0 = getCpu_stat("cpu7");
    
    std::this_thread::sleep_for(std::chrono::milliseconds(100)); // 延时 100 毫秒
    
    std::string cpu_cached1 = getCpu_stat("cpu\u0020");
    std::string cpu0_cached1 = getCpu_stat("cpu0");
    std::string cpu1_cached1 = getCpu_stat("cpu1");
    std::string cpu2_cached1 = getCpu_stat("cpu2");
    std::string cpu3_cached1 = getCpu_stat("cpu3");
    std::string cpu4_cached1 = getCpu_stat("cpu4");
    std::string cpu5_cached1 = getCpu_stat("cpu5");
    std::string cpu6_cached1 = getCpu_stat("cpu6");
    std::string cpu7_cached1 = getCpu_stat("cpu7");
    
    std::string cpu = calculateCpuUtilization(cpu_cached0, cpu_cached1);
    std::string cpu0 = calculateCpuUtilization(cpu0_cached0, cpu0_cached1);
    std::string cpu1 = calculateCpuUtilization(cpu1_cached0, cpu1_cached1);
    std::string cpu2 = calculateCpuUtilization(cpu2_cached0, cpu2_cached1);
    std::string cpu3 = calculateCpuUtilization(cpu3_cached0, cpu3_cached1);
    std::string cpu4 = calculateCpuUtilization(cpu4_cached0, cpu4_cached1);
    std::string cpu5 = calculateCpuUtilization(cpu5_cached0, cpu5_cached1);
    std::string cpu6 = calculateCpuUtilization(cpu6_cached0, cpu6_cached1);
    std::string cpu7 = calculateCpuUtilization(cpu7_cached0, cpu7_cached1);
    
    std::string aaa = cpu + " " + cpu0 + " " + cpu1 + " " + cpu2 + " " + cpu3 + " " + cpu4 + " " + cpu5 + " " + cpu6 + " " + cpu7;
    
    LOGI("GetCpu_stat_cpu success! Cached is %{public}s", aaa.c_str());
    napi_value res;
    napi_create_string_utf8(env, aaa.c_str(), strlen(aaa.c_str()), &res);
    return res;
}

//获取proc/stat文件的processes: 启动的进程数
napi_value TestStatisticsInfo::Getprocesses(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::Getprocesses: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::Getprocesses: napi_get_cb_info fail");
        return nullptr;
    }
    std::string cached = getCpu_stat("processes");
    LOGI("getCpu_stat success! Cached is %{public}s", cached.c_str());
    napi_value res;
    napi_create_string_utf8(env, cached.c_str(), strlen(cached.c_str()), &res);
    return res;
}

// 获取proc/stat文件的ctxt: 上下文切换的总数
napi_value TestStatisticsInfo::Getctxt(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::Getctxt: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::Getctxt: napi_get_cb_info fail");
        return nullptr;
    }
    std::string cached = getCpu_stat("ctxt");
    LOGI("getCpu_stat success! Cached is %{public}s", cached.c_str());
    napi_value res;
    napi_create_string_utf8(env, cached.c_str(), strlen(cached.c_str()), &res);
    return res;
}

std::string TestStatisticsInfo::getCpu_stat(std::string field) {

    std::ifstream meminfo("/proc/stat");
    std::string line;
    std::string cpu0Field = "cpu0";
    std::string cpu1Field = "cpu1";
    std::string cpu2Field = "cpu2";
    std::string cpu3Field = "cpu3";
    std::string cpu4Field = "cpu4";
    std::string cpu5Field = "cpu5";
    std::string cpu6Field = "cpu6";
    std::string cpu7Field = "cpu7";
    std::string cpuField = "cpu\u0020";
    std::string processesField = "processes"; // processes: 进程计数器统计。这个字段表示当前运行的进程数量。
    std::string procs_runningField = "procs_running"; //procs_running: 正在运行的进程计数器统计。这个字段表示当前正在运行的进程数量。
    std::string procs_blockedField = "procs_blocked";//procs_blocked: 阻塞的进程计数器统计。这个字段表示当前被阻塞的进程数量。
    std::string ctxtField = "ctxt";//上下文切换计数器统计。这个字段表示系统发生的上下文切换次数，可以用于评估系统的调度性能。
    while (getline(meminfo, line)) {
        if (line.find(processesField) != std::string::npos) {
            std::string res = line;
            _Cpu_stat[processesField] = res;
        } 
        if (line.find(procs_runningField) != std::string::npos) {
            std::string res = line;
            _Cpu_stat[procs_runningField] = res;
        }
        if (line.find(procs_blockedField) != std::string::npos) {
            std::string res = line;
            _Cpu_stat[procs_blockedField] = res;
        }
        if (line.find(ctxtField) != std::string::npos) {
            std::string res = line;
            _Cpu_stat[ctxtField] = res;
        }
        if (line.find(cpu7Field) != std::string::npos) {
            std::string res = line;
            _Cpu_stat[cpu7Field] = res;
        }
        if (line.find(cpu6Field) != std::string::npos) {
            std::string res = line;
            _Cpu_stat[cpu6Field] = res;
        }
        if (line.find(cpu5Field) != std::string::npos) {
            std::string res = line;
            _Cpu_stat[cpu5Field] = res;
        }
        if (line.find(cpu4Field) != std::string::npos) {
            std::string res = line;
            _Cpu_stat[cpu4Field] = res;
        }
        if (line.find(cpu3Field) != std::string::npos) {
            std::string res = line;
            _Cpu_stat[cpu3Field] = res;
        }
        if (line.find(cpu2Field) != std::string::npos) {
            std::string res = line;
            _Cpu_stat[cpu2Field] = res;
        }
        if (line.find(cpu1Field) != std::string::npos) {
            std::string res = line;
            _Cpu_stat[cpu1Field] = res;
        }
        if (line.find(cpu0Field) != std::string::npos) {
            std::string res = line;
            _Cpu_stat[cpu0Field] = res;
        }
        if (line.find(cpuField) != std::string::npos) {
            std::string res = line;
            _Cpu_stat[cpuField] = res;
        }
    }
    return _Cpu_stat[field];
}

/***************************************************************************************/

// 获取cpu info
bool TestStatisticsInfo::getCpuInfo() {
    LOGE("TestStatisticsInfo::getCpuInfo =======");

    FILE *fp = fopen("/proc/cpuinfo", "r");
    if (NULL == fp) {
        LOGE("TestStatisticsInfo::getCpuInfo failed to open cpuinfo =======");
        return 0;
    }
    char cpuInfo[1000] = {0};
    LOGE("TestStatisticsInfo::getCpuInfo start======= ");
    while (!feof(fp)) {
        memset(cpuInfo, 0, sizeof(cpuInfo));
        fgets(cpuInfo, sizeof(cpuInfo) - 1, fp);
        printf("%s", cpuInfo);
        LOGE("TestStatisticsInfo::getCpuInfo %{public}s", cpuInfo);
    }
    LOGE("TestStatisticsInfo::getCpuInfo end~=======");
    fclose(fp);
    return 1;
}

// 获取total memory
bool TestStatisticsInfo::getMemoryInfo() {
    FILE *fp = fopen("/proc/meminfo", "r");
    if (NULL == fp) {
        LOGE("TestStatisticsInfo::getMemoryInfo failed to open meminfo =======");
        return 0;
    }
    LOGE("TestStatisticsInfo::getMemoryInfo start~=======");
    char memInfo[1000] = {0};
    while (!feof(fp)) {
        memset(memInfo, 0, sizeof(memInfo));
        fgets(memInfo, sizeof(memInfo) - 1, fp);
        LOGE("TestStatisticsInfo::getMemoryInfo %{public}s", memInfo);
    }
    LOGE("TestStatisticsInfo::getMemoryInfo end~=======");
    fclose(fp);
    return 1;
}

/***************************************************************************************/
//读取/proc/uptime，/proc/uptime 是一个特殊的文件，它提供了当前系统的运行时间信息。文件中包含了两个数值，分别表示系统的总运行时间和空闲时间。

napi_value TestStatisticsInfo::GetUptime(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetUptime: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetUptime: napi_get_cb_info fail");
        return nullptr;
    }
    std::string time = getUptime();
    LOGI("getUptime success! %{public}s", time.c_str());
    napi_value res;
    napi_create_string_utf8(env, time.c_str(), strlen(time.c_str()), &res);
    return res;
}

std::string TestStatisticsInfo::getUptime() {
    FILE *fp = fopen("/proc/uptime", "r");
    if (NULL == fp) {
        LOGE("TestStatisticsInfo::getUptime failed to open cpuinfo =======");
        return 0;
    }
    
    std::string time="";
    char buffer[1024]{};
    fgets(buffer, sizeof(buffer), fp);
    time.assign(buffer);//将buffer转换为字符串类型并赋值给time。

    LOGE("TestStatisticsInfo::getUptime %{public}d =======", buffer);
    fclose(fp);
    return time;
}
/***************************************************************************************/
// 获取soc-thmzone系统芯片热区 /sys/class/thermal/thermal_zone5/temp
napi_value TestStatisticsInfo::GetSOCtemp(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::Gettemp: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::Gettemp: napi_get_cb_info fail");
        return nullptr;
    }
    std::string time = getSOCtemp();
    LOGI("Gettemp success! Cached is %{public}s", time.c_str());
    napi_value res;
    napi_create_string_utf8(env, time.c_str(), strlen(time.c_str()), &res);
    return res;
}

// 获取soc-thmzone系统芯片热区 /sys/class/thermal/thermal_zone5/temp
std::string TestStatisticsInfo::getSOCtemp() {
    FILE *fp = fopen("/sys/class/thermal/thermal_zone5/temp", "r");
    if (NULL == fp) {
        LOGE("TestStatisticsInfo::getSOCtemp failed to open cpuinfo =======");
        return 0;
    }

    std::string SOCtemp = "";
    char buffer[1024]{};
    fgets(buffer, sizeof(buffer), fp);
    SOCtemp.assign(buffer); // 将buffer转换为字符串类型并赋值给time。

    LOGE("TestStatisticsInfo::getSOCtemp Cpu count is %{public}d =======", buffer);
    fclose(fp);
    return SOCtemp;
}
/***************************************************************************************/

// 获取big7-thmzone 大核心 7 热区
napi_value TestStatisticsInfo::GetCPU_CORE_big7_thmzonetemp(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetCPU_CORE_big7_thmzonetemp: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetCPU_CORE_big7_thmzonetemp: napi_get_cb_info fail");
        return nullptr;
    }
    std::string time = getCPU_CORE_big7_thmzonetemp();
    LOGI("getCPU_CORE_big7_thmzonetemp success! %{public}s", time.c_str());
    napi_value res;
    napi_create_string_utf8(env, time.c_str(), strlen(time.c_str()), &res);
    return res;
}

// 获取big7-thmzone 大核心 7 热区
std::string TestStatisticsInfo::getCPU_CORE_big7_thmzonetemp() {
    
    //测量big7-thmzone 大核心7热区
    FILE *fp0 = fopen("/sys/class/thermal/thermal_zone7/temp", "r");
    if (NULL == fp0) {
        LOGE("TestStatisticsInfo::getCPU_CORE_big7_thmzonetemp failed to open cpuinfo =======");
        return 0;
    }
    std::string temp0 = "";
    char buffer0[1024]{};
    fgets(buffer0, sizeof(buffer0), fp0);
    temp0.assign(buffer0); // 将buffer转换为字符串类型并赋值给time。
    LOGE("TestStatisticsInfo::getCPU_CORE_big7_thmzonetemp %{public}d =======", buffer0);
    fclose(fp0);
    
    return temp0;
}
/***************************************************************************************/

// 获取mid6-thmzone 中核心 6 热区
napi_value TestStatisticsInfo::GetCPU_CORE_mid6_thmzonetemp(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetCPU_CORE_mid6_thmzonetemp: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetCPU_CORE_mid6_thmzonetemp: napi_get_cb_info fail");
        return nullptr;
    }
    std::string time = getCPU_CORE_mid6_thmzonetemp();
    LOGI("getCPU_CORE_mid6_thmzonetemp success! is %{public}s", time.c_str());
    napi_value res;
    napi_create_string_utf8(env, time.c_str(), strlen(time.c_str()), &res);
    return res;
}

// 获取mid6-thmzone 中核心 6 热区
std::string TestStatisticsInfo::getCPU_CORE_mid6_thmzonetemp() {
    
    FILE *fp0 = fopen("/sys/class/thermal/thermal_zone11/temp", "r");
    if (NULL == fp0) {
        LOGE("TestStatisticsInfo::getCPU_CORE_mid6_thmzonetemp failed to open cpuinfo =======");
        return 0;
    }
    std::string temp0 = "";
    char buffer0[1024]{};
    fgets(buffer0, sizeof(buffer0), fp0);
    temp0.assign(buffer0); // 将buffer转换为字符串类型并赋值给time。
    LOGE("TestStatisticsInfo::getCPU_CORE_mid6_thmzonetemp %{public}d =======", buffer0);
    fclose(fp0);

    return temp0;
}
/***************************************************************************************/

// 获取mid5-thmzone 中核心 5 热区
napi_value TestStatisticsInfo::GetCPU_CORE_mid5_thmzonetemp(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetCPU_CORE_mid5_thmzonetemp: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetCPU_CORE_mid5_thmzonetemp: napi_get_cb_info fail");
        return nullptr;
    }
    std::string time = getCPU_CORE_mid5_thmzonetemp();
    LOGI("getCPU_CORE_mid5_thmzonetemp success! %{public}s", time.c_str());
    napi_value res;
    napi_create_string_utf8(env, time.c_str(), strlen(time.c_str()), &res);
    return res;
}

// 获取mid5-thmzone 中核心 5 热区
std::string TestStatisticsInfo::getCPU_CORE_mid5_thmzonetemp() {
    
    FILE *fp0 = fopen("/sys/class/thermal/thermal_zone10/temp", "r");
    if (NULL == fp0) {
        LOGE("TestStatisticsInfo::getCPU_CORE_mid5_thmzonetemp failed to open cpuinfo =======");
        return 0;
    }
    std::string temp0 = "";
    char buffer0[1024]{};
    fgets(buffer0, sizeof(buffer0), fp0);
    temp0.assign(buffer0); // 将buffer转换为字符串类型并赋值给time。
    LOGE("TestStatisticsInfo::getCPU_CORE_mid5_thmzonetemp %{public}d =======", buffer0);
    fclose(fp0);

    return temp0;
}
/***************************************************************************************/
// 获取mid4-thmzone 中核心 4 热区
napi_value TestStatisticsInfo::GetCPU_CORE_mid4_thmzonetemp(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetCPU_CORE_mid4_thmzonetemp: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetCPU_CORE_mid4_thmzonetemp: napi_get_cb_info fail");
        return nullptr;
    }
    std::string time = getCPU_CORE_mid4_thmzonetemp();
    LOGI("getCPU_CORE_mid4_thmzonetemp success! %{public}s", time.c_str());
    napi_value res;
    napi_create_string_utf8(env, time.c_str(), strlen(time.c_str()), &res);
    return res;
}

// 获取mid4-thmzone 中核心 4 热区
std::string TestStatisticsInfo::getCPU_CORE_mid4_thmzonetemp() {
    
    FILE *fp0 = fopen("/sys/class/thermal/thermal_zone9/temp", "r");
    if (NULL == fp0) {
        LOGE("TestStatisticsInfo::getCPU_CORE_mid4_thmzonetemp failed to open cpuinfo =======");
        return 0;
    }
    std::string temp0 = "";
    char buffer0[1024]{};
    fgets(buffer0, sizeof(buffer0), fp0);
    temp0.assign(buffer0); // 将buffer转换为字符串类型并赋值给time。
    LOGE("TestStatisticsInfo::getCPU_CORE_mid4_thmzonetemp %{public}d =======", buffer0);
    fclose(fp0);

    return temp0;
}
/***************************************************************************************/
// 获取lit3-thmzone 小核心 3 热区
napi_value TestStatisticsInfo::GetCPU_CORE_lit3_thmzonetemp(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetCPU_CORE_lit3_thmzonetemp: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetCPU_CORE_lit3_thmzonetemp: napi_get_cb_info fail");
        return nullptr;
    }
    std::string time = getCPU_CORE_lit3_thmzonetemp();
    LOGI("getCPU_CORE_lit3_thmzonetemp success! %{public}s", time.c_str());
    napi_value res;
    napi_create_string_utf8(env, time.c_str(), strlen(time.c_str()), &res);
    return res;
}

// 获取lit3-thmzone 小核心 3 热区
std::string TestStatisticsInfo::getCPU_CORE_lit3_thmzonetemp() {

    FILE *fp0 = fopen("/sys/class/thermal/thermal_zone16/temp", "r");
    if (NULL == fp0) {
        LOGE("TestStatisticsInfo:getCPU_CORE_lit3_thmzonetemp failed to open cpuinfo =======");
        return 0;
    }
    std::string temp0 = "";
    char buffer0[1024]{};
    fgets(buffer0, sizeof(buffer0), fp0);
    temp0.assign(buffer0); // 将buffer转换为字符串类型并赋值给time。
    LOGE("TestStatisticsInfo::getCPU_CORE_lit3_thmzonetemp %{public}d =======", buffer0);
    fclose(fp0);

    return temp0;
}
/***************************************************************************************/

// 获取lit2-thmzone 小核心 2 热区
napi_value TestStatisticsInfo::GetCPU_CORE_lit2_thmzonetemp(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetCPU_CORE_lit2_thmzonetemp: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetCPU_CORE_lit2_thmzonetemp: napi_get_cb_info fail");
        return nullptr;
    }
    std::string time = getCPU_CORE_lit2_thmzonetemp();
    LOGI("getCPU_CORE_lit2_thmzonetemp success! %{public}s", time.c_str());
    napi_value res;
    napi_create_string_utf8(env, time.c_str(), strlen(time.c_str()), &res);
    return res;
}

// 获取lit2-thmzone 小核心 2 热区
std::string TestStatisticsInfo::getCPU_CORE_lit2_thmzonetemp() {

    FILE *fp0 = fopen("/sys/class/thermal/thermal_zone15/temp", "r");
    if (NULL == fp0) {
        LOGE("TestStatisticsInfo:getCPU_CORE_lit2_thmzonetemp failed to open cpuinfo =======");
        return 0;
    }
    std::string temp0 = "";
    char buffer0[1024]{};
    fgets(buffer0, sizeof(buffer0), fp0);
    temp0.assign(buffer0); // 将buffer转换为字符串类型并赋值给time。
    LOGE("TestStatisticsInfo::getCPU_CORE_lit2_thmzonetemp %{public}d =======", buffer0);
    fclose(fp0);

    return temp0;
}
/***************************************************************************************/

// 获取lit1-thmzone 小核心 1 热区
napi_value TestStatisticsInfo::GetCPU_CORE_lit1_thmzonetemp(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetCPU_CORE_lit1_thmzonetemp: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetCPU_CORE_lit1_thmzonetemp: napi_get_cb_info fail");
        return nullptr;
    }
    std::string time = getCPU_CORE_lit1_thmzonetemp();
    LOGI("getCPU_CORE_lit1_thmzonetemp success! %{public}s", time.c_str());
    napi_value res;
    napi_create_string_utf8(env, time.c_str(), strlen(time.c_str()), &res);
    return res;
}

// 获取lit1-thmzone 小核心 1 热区
std::string TestStatisticsInfo::getCPU_CORE_lit1_thmzonetemp() {

    FILE *fp0 = fopen("/sys/class/thermal/thermal_zone14/temp", "r");
    if (NULL == fp0) {
        LOGE("TestStatisticsInfo:getCPU_CORE_lit1_thmzonetemp failed to open cpuinfo =======");
        return 0;
    }
    std::string temp0 = "";
    char buffer0[1024]{};
    fgets(buffer0, sizeof(buffer0), fp0);
    temp0.assign(buffer0); // 将buffer转换为字符串类型并赋值给time。
    LOGE("TestStatisticsInfo::getCPU_CORE_lit1_thmzonetemp %{public}d =======", buffer0);
    fclose(fp0);

    return temp0;
}
/***************************************************************************************/

// 获取lit0-thmzone 小核心 0 热区
napi_value TestStatisticsInfo::GetCPU_CORE_lit0_thmzonetemp(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetCPU_CORE_lit0_thmzonetemp: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetCPU_CORE_lit0_thmzonetemp: napi_get_cb_info fail");
        return nullptr;
    }
    std::string time = getCPU_CORE_lit0_thmzonetemp();
    LOGI("getCPU_CORE_lit0_thmzonetemp success! %{public}s", time.c_str());
    napi_value res;
    napi_create_string_utf8(env, time.c_str(), strlen(time.c_str()), &res);
    return res;
}

// 获取lit0-thmzone 小核心 0 热区
std::string TestStatisticsInfo::getCPU_CORE_lit0_thmzonetemp() {

    FILE *fp0 = fopen("/sys/class/thermal/thermal_zone13/temp", "r");
    if (NULL == fp0) {
        LOGE("TestStatisticsInfo:getCPU_CORE_lit0_thmzonetemp failed to open cpuinfo =======");
        return 0;
    }
    std::string temp0 = "";
    char buffer0[1024]{};
    fgets(buffer0, sizeof(buffer0), fp0);
    temp0.assign(buffer0); // 将buffer转换为字符串类型并赋值给time。
    LOGE("TestStatisticsInfo::getCPU_CORE_lit0_thmzonetemp %{public}d =======", buffer0);
    fclose(fp0);

    return temp0;
}
/***************************************************************************************/
// 获取GPU热区
napi_value TestStatisticsInfo::GetGPU_temp(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetGPU_temp: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetGPU_temp: napi_get_cb_info fail");
        return nullptr;
    }
    std::string time = getGPU_temp();
    LOGI("getGPU_temp success! %{public}s", time.c_str());
    napi_value res;
    napi_create_string_utf8(env, time.c_str(), strlen(time.c_str()), &res);
    return res;
}

// 获取GPU热区
std::string TestStatisticsInfo::getGPU_temp() {

    FILE *fp0 = fopen("/sys/class/thermal/thermal_zone17/temp", "r");
    if (NULL == fp0) {
        LOGE("TestStatisticsInfo:getGPU_temp failed to open cpuinfo =======");
        return 0;
    }
    std::string temp0 = "";
    char buffer0[1024]{};
    fgets(buffer0, sizeof(buffer0), fp0);
    temp0.assign(buffer0); // 将buffer转换为字符串类型并赋值给time。
    LOGE("TestStatisticsInfo::getGPU_temp %{public}d =======", buffer0);
    fclose(fp0);

    return temp0;
}
/***************************************************************************************/
// 获取主板热区
napi_value TestStatisticsInfo::GetBoard_temp(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetBoard_temp: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetBoard_temp: napi_get_cb_info fail");
        return nullptr;
    }
    std::string time = getBoard_temp();
    LOGI("getGPU_temp success! %{public}s", time.c_str());
    napi_value res;
    napi_create_string_utf8(env, time.c_str(), strlen(time.c_str()), &res);
    return res;
}

// 获取主板热区
std::string TestStatisticsInfo::getBoard_temp() {

    FILE *fp0 = fopen("/sys/class/thermal/thermal_zone27/temp", "r");
    if (NULL == fp0) {
        LOGE("TestStatisticsInfo:getBoard_temp failed to open cpuinfo =======");
        return 0;
    }
    std::string temp0 = "";
    char buffer0[1024]{};
    fgets(buffer0, sizeof(buffer0), fp0);
    temp0.assign(buffer0); // 将buffer转换为字符串类型并赋值给time。
    LOGE("TestStatisticsInfo::getBoard_temp %{public}d =======", buffer0);
    fclose(fp0);

    return temp0;
}
/***************************************************************************************/
// 交换分区大小
napi_value TestStatisticsInfo::GetSwaps(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetSwaps: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetSwaps: napi_get_cb_info fail");
        return nullptr;
    }
    std::string time = getSwaps();
    LOGI("getSwaps success! %{public}s", time.c_str());
    napi_value res;
    napi_create_string_utf8(env, time.c_str(), strlen(time.c_str()), &res);
    return res;
}

/*
# cat /proc/swaps
Filename                                Type            Size            Used            Priority
/dev/block/zram0                        partition       1048572         0               -2
*/

// 交换分区大小
std::string TestStatisticsInfo::getSwaps() {

    FILE *fp0 = fopen("/proc/swaps", "r");
    if (NULL == fp0) {
        LOGE("TestStatisticsInfo:getBoard_temp failed to open cpuinfo =======");
        return 0;
    }
    
    std::string swapsInfo = "";
    char buffer0[1024];
    while (fgets(buffer0, sizeof(buffer0), fp0) != NULL) {
        swapsInfo += buffer0;
    }

    swapsInfo.assign(buffer0); // 将buffer转换为字符串类型并赋值给time。
    LOGE("TestStatisticsInfo::getSwaps %{public}d =======", buffer0);
    fclose(fp0);

    return swapsInfo;
}
/***************************************************************************************/
// 获取系统日期
napi_value TestStatisticsInfo::GetRTC_Date_temp(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetDate_temp: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetDate_temp: napi_get_cb_info fail");
        return nullptr;
    }
    std::string time = getRTC_Date_temp();
    LOGI("getDate_temp success! %{public}s", time.c_str());
    napi_value res;
    napi_create_string_utf8(env, time.c_str(), strlen(time.c_str()), &res);
    return res;
}

// 获取系统日期
std::string TestStatisticsInfo::getRTC_Date_temp() {

    FILE *fp0 = fopen("/sys/class/rtc/rtc0/date", "r");
    if (NULL == fp0) {
        LOGE("TestStatisticsInfo:getDate_temp failed to open cpuinfo =======");
        return 0;
    }
    std::string temp0 = "";
    char buffer0[1024]{};
    fgets(buffer0, sizeof(buffer0), fp0);
    temp0.assign(buffer0); // 将buffer转换为字符串类型并赋值给time。
    LOGE("TestStatisticsInfo::getDate_temp %{public}d =======", buffer0);
    fclose(fp0);

    return temp0;
}
/***************************************************************************************/
// 获取内核信息
napi_value TestStatisticsInfo::GetKernel_version(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetKernel_version: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetKernel_version: napi_get_cb_info fail");
        return nullptr;
    }
    std::string time = getKernel_version();
    LOGI("getKernel_version success! %{public}s", time.c_str());
    napi_value res;
    napi_create_string_utf8(env, time.c_str(), strlen(time.c_str()), &res);
    return res;
}

// 获取内核信息
std::string TestStatisticsInfo::getKernel_version() {

    FILE *fp0 = fopen("/proc/version", "r");
    if (NULL == fp0) {
        LOGE("TestStatisticsInfo:getKernel_version failed to open cpuinfo =======");
        return 0;
    }
    std::string temp0 = "";
    char buffer0[1024]{};
    fgets(buffer0, sizeof(buffer0), fp0);
    temp0.assign(buffer0); // 将buffer转换为字符串类型并赋值给time。
    LOGE("TestStatisticsInfo::getKernel_version %{public}d =======", buffer0);
    fclose(fp0);

    return temp0;
}
/***************************************************************************************/

// /sys/class/rtc/rtc0/time 查看rtc时间
napi_value TestStatisticsInfo::GetRTC_Time_temp(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetRTC_Time_temp: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetRTC_Time_temp: napi_get_cb_info fail");
        return nullptr;
    }
    std::string time = getRTC_Time_temp();
    LOGI("getRTC_Time_temp success! %{public}s", time.c_str());
    napi_value res;
    napi_create_string_utf8(env, time.c_str(), strlen(time.c_str()), &res);
    return res;
}

std::string TestStatisticsInfo::getRTC_Time_temp() {

    FILE *fp0 = fopen("/sys/class/rtc/rtc0/time", "r");
    if (NULL == fp0) {
        LOGE("TestStatisticsInfo:getRTC_Time_temp failed to open cpuinfo =======");
        return 0;
    }
    std::string temp0 = "";
    char buffer0[1024]{};
    fgets(buffer0, sizeof(buffer0), fp0);
    temp0.assign(buffer0); // 将buffer转换为字符串类型并赋值给time。
    LOGE("TestStatisticsInfo::getRTC_Time_temp %{public}d =======", buffer0);
    fclose(fp0);

    return temp0;
}
/***************************************************************************************/

// proc/device-tree/cpuinfo_hardware
// 查看SOC型号
napi_value TestStatisticsInfo::Getcpuinfo_hardware(napi_env env, napi_callback_info info) {
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::Getcpuinfo_hardware: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::Getcpuinfo_hardware: napi_get_cb_info fail");
        return nullptr;
    }
    std::string time = getcpuinfo_hardware();
    LOGI("getcpuinfo_hardware success! %{public}s", time.c_str());
    napi_value res;
    napi_create_string_utf8(env, time.c_str(), strlen(time.c_str()), &res);
    return res;
}

std::string TestStatisticsInfo::getcpuinfo_hardware() {

    FILE *fp0 = fopen("proc/device-tree/cpuinfo_hardware", "r");
    if (NULL == fp0) {
        LOGE("TestStatisticsInfo:getcpuinfo_hardware failed to open cpuinfo =======");
        return 0;
    }
    std::string temp0 = "";
    char buffer0[1024]{};
    fgets(buffer0, sizeof(buffer0), fp0);
    temp0.assign(buffer0); // 将buffer转换为字符串类型并赋值给time。
    LOGE("TestStatisticsInfo::getcpuinfo_hardware %{public}d =======", buffer0);
    fclose(fp0);

    return temp0;
}


// 计划制作的功能
// /proc/swaps 交换分区大小
// /proc/uptime
// /proc/version
// /proc/uid_cputime/show_uid_stat
// /dev/cpuset/cpuset.cpus

// 获取cpu温度 /sys/class/thermal/thermal_zone*/temp 中随便选一个节点
// /sys/class/thermal/thermal_zone3/temp cpu温度,除以1000，单位摄氏度

// /sys/kernel/debug/clk/core0/clk_rate

// hwclock-- systohc矫正rtc时间
// /sys/class/rtc/rtc0/date 查看rtc日期
// /sys/class/rtc/rtc0/time 查看rtc时间

// /proc/crypto 系统上已安装的内核使用的密码算法及每个算法的详细信息列表；

// / proc / loadavg
// 保存关于CPU和磁盘I/O的负载平均值，其前三列分别表示每1秒钟、每5秒钟及每15秒的负载平均值，类似于uptime命令输出的相关信息；第四列是由斜线隔开的两个数值，前者表示当前正由内核调度的实体（进程和线程）的数目，后者表示系统当前存活的内核调度实体的数目；第五列表示此文件被查看前最近一个由内核创建的进程的PID；

// #cat / proc / net / sockstat 查看socket状态
//  sockets : used 351 TCP : inuse 6 orphan 0 tw 2 alloc 17 mem 1 UDP : inuse 2 mem 1 UDPLITE : inuse 0 RAW : inuse 0
//  FRAG
//     : inuse 0 memory 0

// cat /proc/net/dev


