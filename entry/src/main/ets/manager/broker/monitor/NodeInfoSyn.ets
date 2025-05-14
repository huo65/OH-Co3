import { NodeInfo, systemProfiler } from '../../monitor/SystemProfiler'
import { MQTTClient } from '../MQTTClient'
import List from '@ohos.util.List'

class NodeInfoSyn{
  // mqttClient:MQTTClient = MQTTClient.getInstance()
  ownName:String = "OpenHarmony"
  otherNodeInfo:List<NodeInfo> = new List();

  // getOtherNodeInfo(): List<NodeInfo>{
  //   return ;
  // }

}
export const nodeInfoSyn = new NodeInfoSyn();