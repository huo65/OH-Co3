import batteryInfo from '@ohos.batteryInfo';
import deviceInfo from '@ohos.deviceInfo';
import statfs from '@ohos.file.statvfs';
import HashMap from '@ohos.util.HashMap';
import testStatisticsApi from 'libentry.so';
import { nodeInfoSyn } from '../broker/monitor/NodeInfoSyn';
import { MQTTOption } from '../broker/MQTTConfig';
import { hidebug } from '@kit.PerformanceAnalysisKit';

export class NodeInfo{
  // 设备产品名称
  deviceName: string
  // 电池电量百分比
  batteryLevel: number
  // 内存占用
  memoryUsage: number
  // CPU 占用率
  cpuUsage: number
  storageFree: number
  score:number

  constructor() {
    this.deviceName = "";
    this.batteryLevel = 0;
    this.memoryUsage = 0;
    this.cpuUsage = 0;
    this.storageFree = 0;
    this.score = 0;
  }

}

class SystemProfiler{
  private deviceInfos:HashMap<string,NodeInfo> = new HashMap();
  ownInfo:NodeInfo = new NodeInfo();
  getDeviceInfos():HashMap<string,NodeInfo>{
    let otherInfo:HashMap<string,NodeInfo> = this.getOtherInfo();
    let ownInfo:HashMap<string,NodeInfo> = this.getOwnInfo();
    let  combinedInfo:HashMap<string,NodeInfo> = new HashMap<string, NodeInfo>();

    otherInfo.forEach((value, key) => {
      combinedInfo.set(key, value);
    });
    ownInfo.forEach((value, key) => {
      combinedInfo.set(key, value);
    });

    return combinedInfo;
  }

  getOtherInfo():HashMap<string,NodeInfo>{
    return nodeInfoSyn.getOtherNodeInfo()
  }

  getOwnInfo():HashMap<string,NodeInfo>{
    this.getDeviceName()
    this.getCpuInfo()
    this.getmemoryInfo()
    this.getStatfsInfo()
    this.getBatteryInfo()
    this.getScore()
    nodeInfoSyn.sendOwnInfo(this.ownInfo)
    this.deviceInfos.set(this.ownInfo.deviceName,this.ownInfo)
    return this.deviceInfos
  }
  // 获取设备产品名称
  getDeviceName() {
    this.ownInfo.deviceName = MQTTOption.clientId as string
  }
  getCpuInfo() {
    //TODO 权限问题
    // this.ownInfo.cpuUsage = Number(testStatisticsApi.getCpu_stat_cpu().split(" ")[0]);
    this.ownInfo.cpuUsage = hidebug.getCpuUsage();
  }
  getmemoryInfo(){
    this.ownInfo.memoryUsage =(1 - (Number(testStatisticsApi.getAvailableMem().split(" ")[0]) / Number(testStatisticsApi.getMemTotal().split(" ")[0]))) * 100
  }

  getStatfsInfo() {
    const context = getContext()
    this.ownInfo.storageFree = statfs.getFreeSizeSync(context.filesDir) / (1000 * 1000 * 1000)
  }

  getBatteryInfo() {
    this.ownInfo.batteryLevel = batteryInfo.batterySOC
  }
  getScore(){
    // this.ownInfo.score = scheduler.calculate_score(this.ownInfo.batteryLevel,this.ownInfo.memoryUsage,this.ownInfo.cpuUsage,this.ownInfo.storageFree)
  }

}
export const systemProfiler = new SystemProfiler()
