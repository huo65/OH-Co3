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
  sendOwnInfo(){
    MQTTInstance.pushMessage("testsend" as string,"/deviceInfo/" as string,1 as MqttQos)
  }

}
export const nodeInfoSyn = new NodeInfoSyn();