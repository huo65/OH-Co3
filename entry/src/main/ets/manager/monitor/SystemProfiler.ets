import batteryInfo from '@ohos.batteryInfo';
import statfs from '@ohos.file.statvfs';
import HashMap from '@ohos.util.HashMap';
import testStatisticsApi from 'libentry.so';
import { nodeInfoSyn } from '../broker/monitor/NodeInfoSyn';
import { MQTTOption } from '../broker/MQTTConfig';
import { hidebug } from '@kit.PerformanceAnalysisKit';
import { taskpool } from '@kit.ArkTS';
// TODO 更新接口https://docs.openharmony.cn/pages/v6.0/zh-cn/application-dev/reference/apis-performance-analysis-kit/js-apis-hidebug.md#systemmeminfo12
export class DeviceInfo{
  // 设备产品名称
  deviceName: string
  // 电池剩余百分比
  batteryLevel: number
  // 内存占用
  memoryUsage: number
  // CPU 占用率
  cpuUsage: number
  // 存储剩余百分比
  storageFree: number

  constructor() {
    this.deviceName = "";
    this.batteryLevel = 0;
    this.memoryUsage = 0;
    this.cpuUsage = 0;
    this.storageFree = 0;
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

    otherInfo.forEach((value, key) => {
      combinedInfo.set(key, value);
    });
    ownInfo.forEach((value, key) => {
      combinedInfo.set(key, value);
    });

    return combinedInfo;
  }

  getOtherInfo():HashMap<string,DeviceInfo>{
    return nodeInfoSyn.getOtherNodeInfo()
  }

  getOwnInfo():HashMap<string,DeviceInfo>{
    this.getDeviceName()
    this.getCpuInfo()
    this.getMemoryInfo()
    this.getStatfsInfo()
    this.getBatteryInfo()
    nodeInfoSyn.sendOwnInfo(this.ownInfo)
    this.deviceInfos.set(this.ownInfo.deviceName,this.ownInfo)
    return this.deviceInfos
  }
  // 获取设备产品名称，
  getDeviceName() {
    this.ownInfo.deviceName = MQTTOption.clientId as string
  }
  async getCpuInfo() {
    try {
      const task = new taskpool.Task(getSystemCpuUsageAsync);
      const cpuUsage = await taskpool.execute(task);
      console.info(`getSystemCpuUsage: ${cpuUsage}`);
      this.ownInfo.cpuUsage = cpuUsage as number;
    } catch (error) {
      console.error(`CPU info error: ${error.message}`);
    }
  }
  getMemoryInfo(){
    this.ownInfo.memoryUsage =(1 - (Number(testStatisticsApi.getAvailableMem().split(" ")[0]) / Number(testStatisticsApi.getMemTotal().split(" ")[0]))) * 100
  }

  getStatfsInfo() {
    const context = getContext()
    this.ownInfo.storageFree = statfs.getFreeSizeSync(context.filesDir) / (1000 * 1000 * 1000)
  }

  getBatteryInfo() {
    this.ownInfo.batteryLevel = batteryInfo.batterySOC
  }

}
export const systemProfiler = new SystemProfiler()
