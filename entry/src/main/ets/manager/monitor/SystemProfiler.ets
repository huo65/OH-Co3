import batteryInfo from '@ohos.batteryInfo';
import deviceInfo from '@ohos.deviceInfo';
import statfs from '@ohos.file.statvfs';
import HashMap from '@ohos.util.HashMap';
import {scheduler} from '../scheduler/Scheduler'
import testStatisticsApi from 'libentry.so';
import { nodeInfoSyn } from '../broker/monitor/NodeInfoSyn';

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
    nodeInfoSyn.getOtherNodeInfo()
  }
  getOwnInfo(){
    this.getDeviceName()
    this.getCpuInfo()
    this.getmemoryInfo()
    this.getStatfsInfo()
    this.getBatteryInfo()
    this.getScore()
    this.deviceInfos.set(this.ownInfo.deviceName,this.ownInfo)
    return this.deviceInfos
  }
  // 获取设备产品名称
  getDeviceName() {
    this.ownInfo.deviceName = deviceInfo.marketName
  }
  getCpuInfo() {
    this.ownInfo.cpuUsage = Number(testStatisticsApi.getCpu_stat_cpu().split(" ")[0]);
  }
  getmemoryInfo(){
    this.ownInfo.memorySize =(1 - (Number(testStatisticsApi.getAvailableMem().split(" ")[0]) / Number(testStatisticsApi.getMemTotal().split(" ")[0]))) * 100
  }

  getStatfsInfo() {
    const context = getContext()
    this.ownInfo.statfsFreeSize = statfs.getFreeSizeSync(context.filesDir) / (1000 * 1000 * 1000)
  }

  getBatteryInfo() {
    this.ownInfo.batteryState = batteryInfo.batterySOC
  }
  getScore(){
    this.ownInfo.score = scheduler.calculate_score(this.ownInfo.batteryState,this.ownInfo.memorySize,this.ownInfo.cpuUsage,this.ownInfo.statfsFreeSize)
  }

}
export const systemProfiler = new SystemProfiler()
