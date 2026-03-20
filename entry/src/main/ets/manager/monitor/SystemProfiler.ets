import batteryInfo from '@ohos.batteryInfo';
import statfs from '@ohos.file.statvfs';
import HashMap from '@ohos.util.HashMap';
import GetSystemInfo from 'libentry.so';
import { nodeInfoSyn } from '../broker/monitor/NodeInfoSyn';
import { getDeviceId } from '../config/DeviceIdentifier';
import { hidebug } from '@kit.PerformanceAnalysisKit';
import { taskpool } from '@kit.ArkTS';
// API12之后系统接口新增了一系列获取系统信息的接口，这里为兼容旧版本内存信息获取依旧使用NDK https://docs.openharmony.cn/pages/v6.0/zh-cn/application-dev/reference/apis-performance-analysis-kit/js-apis-hidebug.md#systemmeminfo12
export class DeviceInfo{
  // 设备产品名称
  deviceName: string
  // 电池剩余百分比
  batteryLevel: number
  // 内存占用率
  memoryUsage: number
  // CPU占用率
  cpuUsage: number
  // 存储剩余百分比
  storageFree: number
  // 网络延迟，联网前默认为1
  latency: number

  constructor() {
    this.deviceName = "";
    this.batteryLevel = 0;
    this.memoryUsage = 0;
    this.cpuUsage = 0;
    this.storageFree = 0;
    this.latency = 1;
  }

}
@Concurrent
async function getSystemCpuUsageAsync(): Promise<number> {
  try {
    return hidebug.getSystemCpuUsage();
  } catch (error) {
    throw new Error(`code: ${(error as BusinessError<Error>).code}, msg: ${(error as BusinessError<Error>).message}`);
  }
}

class SystemProfiler{
  private deviceInfos:HashMap<string,DeviceInfo> = new HashMap();
  ownInfo:DeviceInfo = new DeviceInfo();

  getDeviceInfos():HashMap<string,DeviceInfo>{
    let otherInfo:HashMap<string,DeviceInfo> = this.getOtherInfo();
    let ownInfo:HashMap<string,DeviceInfo> = this.getOwnInfo();
    let  combinedInfo:HashMap<string,DeviceInfo> = new HashMap<string, DeviceInfo>();

    try {
      otherInfo.forEach((value, key) => {
        combinedInfo.set(key, value);
      });
      ownInfo.forEach((value, key) => {
        combinedInfo.set(key, value);
      });
    } catch (error) {
      console.error(`[HarmonyInference] [SystemProfiler] 获取设备信息失败: ${error.message}`);
    }


    return combinedInfo;
  }
  // 设备清理机制已由 NodeInfoSyn.parseDeviceListMessage 实现
  // 通过接收 "/device/list" 主题的在线设备列表，自动清理离线设备
  getOtherInfo():HashMap<string,DeviceInfo>{
    return nodeInfoSyn.getOtherNodeInfo()
  }

  getOwnInfo():HashMap<string,DeviceInfo>{
    this.getDeviceName()
    this.getCpuInfo()
    this.getMemoryInfo()
    this.getStatfsInfo()
    this.getBatteryInfo()
    this.updateLatency()
    nodeInfoSyn.sendOwnInfo(this.ownInfo)
    this.deviceInfos.set(this.ownInfo.deviceName,this.ownInfo)
    return this.deviceInfos
  }
  // 获取设备唯一标识符
  // 使用统一的设备标识管理模块，确保全局一致性
  getDeviceName() {
    this.ownInfo.deviceName = getDeviceId()
  }
  async getCpuInfo() {
    try {
      const task = new taskpool.Task(getSystemCpuUsageAsync);
      const cpuUsage = await taskpool.execute(task);
      const rawValue = cpuUsage as number;
      this.ownInfo.cpuUsage = Math.round(rawValue * 10000) / 100;
    } catch (error) {
      console.error(`[HarmonyInference] [SystemProfiler] 获取CPU信息失败: ${error.message}`);
    }
  }
  getMemoryInfo(){
    const rawValue = GetSystemInfo.getMemUsage();
    this.ownInfo.memoryUsage = Math.round(rawValue * 10000) / 100;
  }

  getStatfsInfo() {
    const context = getContext()
    try {
      const rawValue = statfs.getFreeSizeSync(context.filesDir) / statfs.getTotalSizeSync(context.filesDir);
      this.ownInfo.storageFree = Math.round(rawValue * 10000) / 100;
    } catch (error) {
      console.error(`[HarmonyInference] [SystemProfiler] 获取存储信息失败: ${error.message}`);
    }
  }

  getBatteryInfo() {
    this.ownInfo.batteryLevel = batteryInfo.batterySOC
  }
  updateLatency(){
    this.ownInfo.latency = (nodeInfoSyn.lastLatency);
  }

}
export const systemProfiler = new SystemProfiler()
