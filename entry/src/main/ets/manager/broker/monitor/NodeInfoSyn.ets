import { NodeInfo, systemProfiler } from '../../monitor/SystemProfiler'
import { MQTTClient, MQTTOptionsType } from '../MQTTClient'
import List from '@ohos.util.List'
import { MqttQos } from '@ohos/mqtt'
import {MQTTOption} from '../MQTTConfig'

const MQTTInstance: MQTTClient = MQTTClient.getFirstInstance(MQTTOption)
class NodeInfoSyn{
  ownName:String = "OpenHarmony"
  otherNodeInfo:List<NodeInfo> = new List();

  // getOtherNodeInfo(): List<NodeInfo>{
  //   return ;
  // }
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

}
export const nodeInfoSyn = new NodeInfoSyn();