import { ownName } from './monitor/NodeInfoSyn'
import { MQTTClient, MQTTOptionsType } from './MQTTClient'
import deviceInfo from '@ohos.deviceInfo';
// TODO 后续删除这个的相关引用
export const MQTTOption: MQTTOptionsType = {
  url: 'mqtt://10.123.74.159:1883',
  clientId: deviceInfo.marketName + "_" + Math.floor(Math.random() * 10000),
  userName: 'root',
  password: 'admin',
  topic: '/test/123',
  qos: 1
}
