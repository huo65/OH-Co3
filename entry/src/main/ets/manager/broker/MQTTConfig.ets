import { MQTTClient, MQTTOptionsType } from './MQTTClient'
import deviceInfo from '@ohos.deviceInfo';
// 初始化后同步信息：ClientId
export const MQTTOption: MQTTOptionsType = {
  clientId: deviceInfo.marketName
}
