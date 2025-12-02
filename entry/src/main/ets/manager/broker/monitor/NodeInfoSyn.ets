import { NodeInfo } from '../../monitor/SystemProfiler'
import { MQTTClient } from '../MQTTClient'
import {MQTTOption} from '../MQTTConfig'
import HashMap from '@ohos.util.HashMap'
import deviceInfo from '@ohos.deviceInfo';


interface NodeInfoObj {
  deviceName: string;
  score: number;
  params: NodeInfo
}

const ownName: string = MQTTOption.clientId as string

class NodeInfoSyn{

  otherNodeInfo:NodeInfo[] = [];


  getOtherNodeInfo():HashMap<string,NodeInfo> {
    let otherInfo:HashMap<string,NodeInfo> = new HashMap<string,NodeInfo>();
    for (let index = 0; index < this.otherNodeInfo.length; index++) {
      otherInfo.set(this.otherNodeInfo[index].deviceName,this.otherNodeInfo[index])
    }
    return otherInfo;
  }

  sendOwnInfo(nodeInfo: NodeInfo): void {
    const MQTTInstance: MQTTClient = MQTTClient.getInstance()
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
      const newDeviceName:string = nodeInfoObj.deviceName;
      const newScore:number = nodeInfoObj.score;

      if (ownName !== newDeviceName) {
        const params:NodeInfo = nodeInfoObj.params;
        const newNodeInfo: NodeInfo = {
          deviceName: newDeviceName,
          cpuUsage: parseFloat(params.cpuUsage.toFixed(2)),
          memoryUsage: parseFloat(params.memoryUsage.toFixed(2)),
          storageFree: parseFloat(params.storageFree.toFixed(2)),
          batteryLevel: parseFloat(params.batteryLevel.toFixed(2)),
          score: newScore
        };
        // Remove existing entry with the same device name if exists
        this.otherNodeInfo = this.otherNodeInfo.filter(node => node.deviceName !== newDeviceName);
        console.log("huoADD:" + newDeviceName);

        // Add new node info
        this.otherNodeInfo.push(newNodeInfo);
      } else {
        console.log("huoNO");
      }
    } catch (e) {
      console.error("Error parsing message:", e);
    }


  }


}
export const nodeInfoSyn = new NodeInfoSyn();
export {ownName}