import { ownName } from './monitor/NodeInfoSyn'
import { MQTTClient, MQTTOptionsType } from './MQTTClient'
import deviceInfo from '@ohos.deviceInfo';

export const MQTTOption: MQTTOptionsType = {
  url: 'mqtt://10.123.74.159:1883',
  clientId: deviceInfo.marketName + "_" + Math.floor(Math.random() * 10000),
  userName: 'root',
  password: 'admin',
  topic: '/test/123',
  qos: 1
}
