#include "GetSystemInfo.h"
#include <fstream>
#include <string>
#include <sstream>
#include <chrono>
#include <thread>

const char *TAG = "[Sample_rawfile]";

napi_value GetSystemInfo::GetCpuUsage(napi_env env, napi_callback_info info)
{
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetCpuUsage: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetCpuUsage: napi_get_cb_info fail");
        return nullptr;
    }

    double cpuUsage = calculateCpuUtilization();
    LOGI("GetCpuUsage success! Cpu usage is %{public}f", cpuUsage);
    
    napi_value res;
    napi_create_double(env, cpuUsage, &res);
    return res;
}

napi_value GetSystemInfo::GetMemUsage(napi_env env, napi_callback_info info)
{
    if ((nullptr == env) || (nullptr == info)) {
        LOGE("TestStatisticsInfo::GetMemUsage: env or info is null");
        return nullptr;
    }

    napi_value thisArg;
    if (napi_ok != napi_get_cb_info(env, info, nullptr, nullptr, &thisArg, nullptr)) {
        LOGE("TestStatisticsInfo::GetMemUsage: napi_get_cb_info fail");
        return nullptr;
    }

    double memUsage = calculateMemUsage();
    LOGI("GetMemUsage success! Mem usage is %{public}f", memUsage);
    
    napi_value res;
    napi_create_double(env, memUsage, &res);
    return res;
}

std::string GetSystemInfo::getCpuStatLine(const std::string& field)
{
    std::ifstream cpuInfo("/proc/stat");
    if (!cpuInfo.is_open()) {
        LOGE("Failed to open /proc/stat");
        return "";
    }
    
    std::string line;
    while (getline(cpuInfo, line)) {
        if (line.find(field) == 0) {
            cpuInfo.close();
            return line;
        }
    }
    
    cpuInfo.close();
    return "";
}

double GetSystemInfo::calculateCpuUtilization()
{
    std::string cpuLine1 = getCpuStatLine("cpu ");
    if (cpuLine1.empty()) {
        return 0.0;
    }
    
    std::this_thread::sleep_for(std::chrono::milliseconds(100));
    
    std::string cpuLine2 = getCpuStatLine("cpu ");
    if (cpuLine2.empty()) {
        return 0.0;
    }
    
    std::istringstream iss1(cpuLine1);
    std::istringstream iss2(cpuLine2);
    
    std::string cpuName1, cpuName2;
    long long user1, nice1, system1, idle1, iowait1, irq1, softirq1, steal1;
    long long user2, nice2, system2, idle2, iowait2, irq2, softirq2, steal2;
    
    iss1 >> cpuName1 >> user1 >> nice1 >> system1 >> idle1 >> iowait1 >> irq1 >> softirq1 >> steal1;
    iss2 >> cpuName2 >> user2 >> nice2 >> system2 >> idle2 >> iowait2 >> irq2 >> softirq2 >> steal2;
    
    long long totalTime1 = user1 + nice1 + system1 + idle1 + iowait1 + irq1 + softirq1 + steal1;
    long long totalTime2 = user2 + nice2 + system2 + idle2 + iowait2 + irq2 + softirq2 + steal2;
    long long idleTime1 = idle1 + iowait1;
    long long idleTime2 = idle2 + iowait2;
    
    long long totalDiff = totalTime2 - totalTime1;
    long long idleDiff = idleTime2 - idleTime1;
    
    if (totalDiff <= 0) {
        return 0.0;
    }
    
    double cpuUsage = (1.0 - static_cast<double>(idleDiff) / totalDiff);
    
    // 确保返回值在0-1范围内
    if (cpuUsage < 0.0) cpuUsage = 0.0;
    if (cpuUsage > 1.0) cpuUsage = 1.0;
    
    return cpuUsage;
}

long long GetSystemInfo::parseMemoryValue(const std::string& line)
{
    std::istringstream iss(line);
    std::string key, value, unit;
    iss >> key >> value >> unit;
    
    long long memValue = std::stoll(value);
    // 将kB转换为bytes
    if (unit == "kB") {
        memValue *= 1024;
    }
    
    return memValue;
}

void GetSystemInfo::parseMemInfo(long long& memTotal, long long& memAvailable)
{
    std::ifstream meminfo("/proc/meminfo");
    if (!meminfo.is_open()) {
        LOGE("Failed to open /proc/meminfo");
        memTotal = 0;
        memAvailable = 0;
        return;
    }
    
    std::string line;
    memTotal = 0;
    memAvailable = 0;
    
    while (getline(meminfo, line)) {
        if (line.find("MemTotal:") == 0) {
            memTotal = parseMemoryValue(line);
        } else if (line.find("MemAvailable:") == 0) {
            memAvailable = parseMemoryValue(line);
        }
        
        // 如果已经找到两个值，提前退出
        if (memTotal > 0 && memAvailable > 0) {
            break;
        }
    }
    
    meminfo.close();
}

double GetSystemInfo::calculateMemUsage()
{
    long long memTotal, memAvailable;
    parseMemInfo(memTotal, memAvailable);
    
    if (memTotal <= 0) {
        return 0.0;
    }
    
    // 计算已使用内存比例
    double memUsage = 1.0 - static_cast<double>(memAvailable) / memTotal;
    
    // 确保返回值在0-1范围内
    if (memUsage < 0.0) memUsage = 0.0;
    if (memUsage > 1.0) memUsage = 1.0;
    
    return memUsage;
}

