#include "GetSystemInfo.h"
#include <set>
#include <fstream>
#include <string>
#include <sstream>
#include <chrono>
#include <thread>

const int GLOBAL_RESMGR = 0xFF00;
const char *TAG = "[Sample_rawfile]";

std::map<std::string, std::string> GetSystemInfo::_MemInfoMap;

std::map<std::string, std::string> GetSystemInfo::_Cpu_stat;


napi_value GetSystemInfo::GetCpuCount(napi_env env, napi_callback_info info)
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

napi_value GetSystemInfo::GetMemTotal(napi_env env, napi_callback_info info) {
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



napi_value GetSystemInfo::GetAvailableMem(napi_env env, napi_callback_info info) {
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

int GetSystemInfo::getCpuCount() {
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

std::string GetSystemInfo::parseLine(std::string line) {
    if (!line.empty()) {
        std::string res = line.substr(line.find(":") + 1);
        res.erase(0, res.find_first_not_of(" "));
        res.erase(res.find_last_not_of(" ") + 1);
        return res;
    }
    return line;
}

std::string GetSystemInfo::getMemInfoMap(std::string field) {
    
    std::ifstream meminfo("/proc/meminfo");
    if (!meminfo.is_open()) {
        LOGE("Failed to open /proc/meminfo");
        return "";
    }
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
std::string GetSystemInfo::calculateCpuUtilization(std::string& a,std::string& a_second) {
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
napi_value GetSystemInfo::GetCpu_stat_cpu(napi_env env, napi_callback_info info) {
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
//    std::string cpu0_cached0 = getCpu_stat("cpu0");
//    std::string cpu1_cached0 = getCpu_stat("cpu1");
//    std::string cpu2_cached0 = getCpu_stat("cpu2");
//    std::string cpu3_cached0 = getCpu_stat("cpu3");
//    std::string cpu4_cached0 = getCpu_stat("cpu4");
//    std::string cpu5_cached0 = getCpu_stat("cpu5");
//    std::string cpu6_cached0 = getCpu_stat("cpu6");
//    std::string cpu7_cached0 = getCpu_stat("cpu7");
    
    std::this_thread::sleep_for(std::chrono::milliseconds(100)); // 延时 100 毫秒
    
    std::string cpu_cached1 = getCpu_stat("cpu\u0020");
//    std::string cpu0_cached1 = getCpu_stat("cpu0");
//    std::string cpu1_cached1 = getCpu_stat("cpu1");
//    std::string cpu2_cached1 = getCpu_stat("cpu2");
//    std::string cpu3_cached1 = getCpu_stat("cpu3");
//    std::string cpu4_cached1 = getCpu_stat("cpu4");
//    std::string cpu5_cached1 = getCpu_stat("cpu5");
//    std::string cpu6_cached1 = getCpu_stat("cpu6");
//    std::string cpu7_cached1 = getCpu_stat("cpu7");
    
    std::string cpu = calculateCpuUtilization(cpu_cached0, cpu_cached1);
//    std::string cpu0 = calculateCpuUtilization(cpu0_cached0, cpu0_cached1);
//    std::string cpu1 = calculateCpuUtilization(cpu1_cached0, cpu1_cached1);
//    std::string cpu2 = calculateCpuUtilization(cpu2_cached0, cpu2_cached1);
//    std::string cpu3 = calculateCpuUtilization(cpu3_cached0, cpu3_cached1);
//    std::string cpu4 = calculateCpuUtilization(cpu4_cached0, cpu4_cached1);
//    std::string cpu5 = calculateCpuUtilization(cpu5_cached0, cpu5_cached1);
//    std::string cpu6 = calculateCpuUtilization(cpu6_cached0, cpu6_cached1);
//    std::string cpu7 = calculateCpuUtilization(cpu7_cached0, cpu7_cached1);
    
    std::string aaa = cpu + " " ;
    
    LOGI("GetCpu_stat_cpu success! Cached is %{public}s", aaa.c_str());
    napi_value res;
    napi_create_string_utf8(env, aaa.c_str(), strlen(aaa.c_str()), &res);
    return res;
}




std::string GetSystemInfo::getCpu_stat(std::string field) {
    LOGE("TestStatisticsInfo::GetStat");
    
    std::ifstream cpuInfo("/proc/stat");
    if (!cpuInfo.is_open()) {
        LOGE("Failed to open /proc/stat");
        return "";
    }
    std::string line;
    std::string cpuField = "cpu\u0020";
    std::string processesField = "processes"; // processes: 进程计数器统计。这个字段表示当前运行的进程数量。
    std::string procs_runningField = "procs_running"; //procs_running: 正在运行的进程计数器统计。这个字段表示当前正在运行的进程数量。
    std::string procs_blockedField = "procs_blocked";//procs_blocked: 阻塞的进程计数器统计。这个字段表示当前被阻塞的进程数量。
    std::string ctxtField = "ctxt";//上下文切换计数器统计。这个字段表示系统发生的上下文切换次数，可以用于评估系统的调度性能。
    while (getline(cpuInfo, line)) {
        LOGE("TestStatisticsInfo::GetLine");
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
        if (line.find(cpuField) != std::string::npos) {
            std::string res = line;
            _Cpu_stat[cpuField] = res;
        }
    }
    return _Cpu_stat[field];
}

/***************************************************************************************/

