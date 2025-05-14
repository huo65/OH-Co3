import { MQTTClient, MQTTOptionsType } from './MQTTClient'

export const MQTTOption: MQTTOptionsType = {
  url: 'mqtt://192.168.87.159:1883',
  clientId: 'mqtt123456@',
  userName: 'root',
  password: 'admin',
  topic: '/test/123',
  qos: 1
}
