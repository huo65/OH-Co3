export const getCpuCount: () => Number;                  //获取cpu核心数
export const getMemTotal: () => String;                  //获取RAM总内存大小
export const getFreeMem: () => String;                   //获取空闲内存大小
export const getCachedMem: () => String;                 //获取缓存使用内存大小
export const getAvailableMem: () => String;              //获取可用内存大小
export const getCpuInfo: () => any;                      //获取CPU信息
export const getMemoryInfo: () => any;                   //获取RAM信息
export const getUptime: () => String;                    //读取/proc/uptime，/proc/uptime 是一个特殊的文件，它提供了当前系统的运行时间信息。文件中包含了两个数值，分别表示系统的总运行时间和空闲时间。
export const getSOCtemp: () => String;                   //获取soc-thmzone系统芯片热区 /sys/class/thermal/thermal_zone5/temp
export const getCPU_CORE_big7_thmzonetemp: () => String; //获取big7-thmzone 大核心 7 热区
export const getCPU_CORE_mid6_thmzonetemp: () => String; //获取mid6-thmzone 中核心 6 热区
export const getCPU_CORE_mid5_thmzonetemp: () => String; //获取mid6-thmzone 中核心 5 热区
export const getCPU_CORE_mid4_thmzonetemp: () => String; //获取mid6-thmzone 中核心 4 热区
export const getCPU_CORE_lit3_thmzonetemp: () => String; //获取lit3-thmzone 小核心 3 热区
export const getCPU_CORE_lit2_thmzonetemp: () => String; //获取lit2-thmzone 小核心 2 热区
export const getCPU_CORE_lit1_thmzonetemp: () => String; //获取lit1-thmzone 小核心 1 热区
export const getCPU_CORE_lit0_thmzonetemp: () => String; //获取lit0-thmzone 小核心 0 热区
export const getGPU_temp: () => String;                  //获取GPU 热区
export const getBoard_temp: () => String;                //获取主板 热区
export const getSwaps: () => String;                     //获取交换分区大小
export const getRTC_Date_temp: () => String;             //获取rtc日期
export const getKernel_version: () => String;            //获取内核信息
export const getRTC_Time_temp: () => String;             //获取rtc时间
export const getCpu_stat_cpu: () => String;              //获取cpu以及各个核利用率
export const getprocesses: () => String;                 //获取正在运行的进程数
export const getctxt: () => String;                      //获取正在运行的进程数
export const getcpuinfo_hardware: () => String;          //获取SOC型号



