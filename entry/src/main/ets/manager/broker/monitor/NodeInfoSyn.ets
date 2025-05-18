import { NodeInfo } from '../../monitor/SystemProfiler'
import { MQTTClient } from '../MQTTClient'
import {MQTTOption} from '../MQTTConfig'
import List from '@ohos.util.List'
import HashMap from '@ohos.util.HashMap'

const MQTTInstance: MQTTClient = MQTTClient.getFirstInstance(MQTTOption)
interface NodeInfoObj {
  deviceName: string;
  score: number;
  params: NodeInfo
}

class NodeInfoSyn{
  ownName:String = "OpenHarmony 3.2"
  otherNodeInfo:NodeInfo[] = [];


  getOtherNodeInfo():HashMap<string,NodeInfo> {
    let otherInfo:HashMap<string,NodeInfo> = new HashMap<string,NodeInfo>();
    for (let index = 0; index < this.otherNodeInfo.length; index++) {
      otherInfo.set(this.otherNodeInfo[index].deviceName,this.otherNodeInfo[index])
    }
    return otherInfo;
  }

  sendOwnInfo(nodeInfo: NodeInfo): void {
    this.ownName = nodeInfo.deviceName;
    // TODO score

    const message: string = `
    {
        "deviceName": "${nodeInfo.deviceName}",
        "score": "${nodeInfo.score}",
        "params": {
            "deviceName": "${nodeInfo.deviceName}",
            "cpuUsage": ${nodeInfo.cpuUsage},
            "memoryUsage": ${nodeInfo.memoryUsage},
            "storageFree": ${nodeInfo.storageFree},
            "batteryLevel": ${nodeInfo.batteryLevel}
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
      const deviceName:string = nodeInfoObj.deviceName;
      const score:number = nodeInfoObj.score;

      if (this.ownName !== deviceName) {
        const params:NodeInfo = nodeInfoObj.params;
        const nodeInfo: NodeInfo = {
          deviceName: deviceName,
          cpuUsage: parseFloat(params.cpuUsage.toFixed(2)),
          memoryUsage: parseFloat(params.memoryUsage.toFixed(2)),
          storageFree: parseFloat(params.storageFree.toFixed(2)),
          batteryLevel: parseFloat(params.batteryLevel.toFixed(2)),
          score: parseFloat(score.toFixed(2))
        };
        console.log("huoADD:" + deviceName);

        // Remove existing entry with the same device name if exists
        this.otherNodeInfo = this.otherNodeInfo.filter(node => node.deviceName !== deviceName);

        // Add new node info
        this.otherNodeInfo.push(nodeInfo);
      } else {
        console.log("huoNO");
      }
    } catch (e) {
      console.error("Error parsing message:", e);
    }


  }


}
export const nodeInfoSyn = new NodeInfoSyn();