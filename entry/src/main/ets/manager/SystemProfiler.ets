import batteryInfo from '@ohos.batteryInfo';
import hidebug from '@ohos.hidebug';
import deviceInfo from '@ohos.deviceInfo';
import statfs from '@ohos.file.statvfs';
import HashMap from '@ohos.util.HashMap';
import {scheduler} from './Scheduler'
import testStatisticsApi from 'libentry.so';

export class NodeInfo{
  // 设备产品名称
  deviceName: string
  // 电池电量百分比
  batteryState: number
  // 内存占用
  memorySize: number
  // CPU 占用率
  cpuUsage: number
  statfsFreeSize: number
  score:number

  constructor() {
    this.deviceName = "";
    this.batteryState = 0;
    this.memorySize = 0;
    this.cpuUsage = 0;
    this.statfsFreeSize = 0;
    this.score = 0;
  }

}

class SystemProfiler{
  private deviceInfos:HashMap<string,NodeInfo> = new HashMap();
  ownInfo:NodeInfo = new NodeInfo();

  getOtherInfo(){

  }
  getInfo(){
    // testStatisticsApi.getMemoryInfo();
    // testStatisticsApi.getCpuInfo();
    this.getDeviceInfo()
    this.getCpuInfo()
    this.getmemoryInfo()
    this.getStatfsInfo()
    this.getBatteryInfo()
    this.getScore()
    this.deviceInfos.set(this.ownInfo.deviceName,this.ownInfo)
    return this.deviceInfos
  }
  // 获取设备产品名称
  getDeviceInfo() {
    // 模拟器 emulator
    this.ownInfo.deviceName = deviceInfo.marketName
  }
  getCpuInfo() {
    this.ownInfo.cpuUsage = Number(testStatisticsApi.getCpu_stat_cpu().split(" ")[0]);
    console.log("========Cpu_stat_cpu is ",this.ownInfo.cpuUsage)
  }
  getmemoryInfo(){
    this.ownInfo.memorySize =(1 - (Number(testStatisticsApi.getAvailableMem().split(" ")[0]) / Number(testStatisticsApi.getMemTotal().split(" ")[0]))) * 100
    console.log("========availableMem is ",this.ownInfo.memorySize)
  }

  // // 获取调试信息，CPU 占用率，内存
  // getDebugInfo() {
  //   // 获取进程的CPU使用率。 如占用率为50%，则返回0.5。
  //   this.ownInfo.cpuUsage = hidebug.getCpuUsage() * 100
  //   // 获取应用进程实际使用的物理内存大小，单位为kB
  //   // 1MB = 1024KB （Windows 系统，普遍混淆）
  //   // 1MB = 1000KB （MAC 系统，手机系统，Linux 系统，U 盘、DVD 光盘、、、）
  //   this.ownInfo.memorySize = Number(hidebug.getPss()) / 1000
  // }

  getStatfsInfo() {
    const context = getContext()
    this.ownInfo.statfsFreeSize = statfs.getFreeSizeSync(context.filesDir) / (1000 * 1000 * 1000)
  }

  getBatteryInfo() {
    // 当前设备剩余电池电量百分比
    this.ownInfo.batteryState = batteryInfo.batterySOC
  }
  getScore(){
    this.ownInfo.score = scheduler.calculate_score(this.ownInfo.batteryState,this.ownInfo.memorySize,this.ownInfo.cpuUsage,this.ownInfo.statfsFreeSize)
  }

}
export const systemProfiler = new SystemProfiler()
