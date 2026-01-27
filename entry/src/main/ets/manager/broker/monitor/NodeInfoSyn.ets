import { DeviceInfo } from '../../monitor/SystemProfiler'
import { MQTTClient } from '../MQTTClient'
import {MQTTOption} from '../MQTTConfig'
import HashMap from '@ohos.util.HashMap'
import { systemDateTime } from '@kit.BasicServicesKit';

interface NodeInfoObj {
  deviceName: string;
  score: number;
  params: DeviceInfo
}
interface LatencyInfoObj {
  deviceName: string;
  timeStamp: number;
}


const ownName: string = MQTTOption.clientId as string

class NodeInfoSyn{

  otherNodeInfo:DeviceInfo[] = [];
  lastLatency:number = 1;


  getOtherNodeInfo():HashMap<string,DeviceInfo> {
    let otherInfo:HashMap<string,DeviceInfo> = new HashMap<string,DeviceInfo>();
    for (let index = 0; index < this.otherNodeInfo.length; index++) {
      otherInfo.set(this.otherNodeInfo[index].deviceName,this.otherNodeInfo[index])
    }
    return otherInfo;
  }

  sendOwnInfo(nodeInfo: DeviceInfo): void {
    const MQTTInstance: MQTTClient = MQTTClient.getInstance()
    const message: string = `
    {
        "deviceName": "${nodeInfo.deviceName}",
        "params": {
            "deviceName": "${nodeInfo.deviceName}",
            "cpuUsage": ${nodeInfo.cpuUsage},
            "memoryUsage": ${nodeInfo.memoryUsage},
            "storageFree": ${nodeInfo.storageFree},
            "batteryLevel": ${nodeInfo.batteryLevel},
            "latency": ${nodeInfo.latency}
        }
    }
    `.trim();

    MQTTInstance.pushMessage(message,"/device/status");
  }

  /**
   * {
   "deviceName": "Lenovo TB-J607F",
   "score": "0.0",
   "params": {
   "deviceName": "Lenovo TB-J607F",
   "cpuUsage": 0.3389611,
   "memoryUsage": 0.5084416,
   "storageFree": 0.462,
   "batteryLevel": 0.19
   }
   }
   * @param message
   */
  parseNodeInfoMessage(message:string){
    try {
      const nodeInfoObj:NodeInfoObj = JSON.parse(message);
      const newDeviceName:string = nodeInfoObj.deviceName;

      if (ownName != newDeviceName) {
        const params:DeviceInfo = nodeInfoObj.params;
        const newNodeInfo: DeviceInfo = {
          deviceName: newDeviceName,
          cpuUsage: parseFloat(params.cpuUsage.toFixed(2)),
          memoryUsage: parseFloat(params.memoryUsage.toFixed(2)),
          storageFree: parseFloat(params.storageFree.toFixed(2)),
          batteryLevel: parseFloat(params.batteryLevel.toFixed(2)),
          latency: parseFloat(params.latency.toFixed(2))
        };
        this.otherNodeInfo = this.otherNodeInfo.filter(node => node.deviceName !== newDeviceName);
        console.log("device ADD:" + newDeviceName);

        this.otherNodeInfo.push(newNodeInfo);
      } else {
        console.log("device self");
      }
    } catch (e) {
      console.error("Error parsing message:", e);
    }


  }

  testLatencySend(){
    const MQTTInstance: MQTTClient = MQTTClient.getInstance()
    const timepStamp = systemDateTime.getTime(false);
    const message: string = `
    {
        "deviceName": "${ownName}",
        "timeStamp": "${timepStamp}"
    }
    `.trim();

    MQTTInstance.pushMessage(message,"/test/latency");
  }
  testLatencyRec(message:string){
    try {
      const latencyInfoObj:LatencyInfoObj = JSON.parse(message);
      const objDeviceName:string = latencyInfoObj.deviceName;

      if (ownName == objDeviceName) {
        const timeStamp:number = latencyInfoObj.timeStamp;
        const newTimepStamp = systemDateTime.getTime(false);
        console.error(`getLatencyLast: ${timeStamp}`);
        console.error(`getLatencyNew: ${newTimepStamp}`);
        let latency = newTimepStamp - timeStamp;
        this.lastLatency = latency;
      } else {
        // TODO 后期清理无用日志
        console.log("huoNO");
      }
    } catch (e) {
      console.error("Error parsing message:", e);
    }
    ;
    return 0;

  }


}
export const nodeInfoSyn = new NodeInfoSyn();
export {ownName}