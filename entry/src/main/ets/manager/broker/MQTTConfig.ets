import { MQTTClient, MQTTOptionsType } from './MQTTClient'

export const MQTTOption: MQTTOptionsType = {
  url: 'mqtt://192.168.34.159:1883',
  clientId: 'OpenHarmony 3.2',
  userName: 'root',
  password: 'admin',
  topic: '/test/123',
  qos: 1
}
