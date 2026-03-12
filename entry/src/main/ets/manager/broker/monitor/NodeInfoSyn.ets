/**
 * 节点信息同步模块
 * 负责设备节点信息的发送、接收与管理，以及网络延迟测试
 */
import { DeviceInfo } from '../../monitor/SystemProfiler'
import { MQTTClient } from '../MQTTClient'
import { MQTTOption } from '../MQTTConfig'
import HashMap from '@ohos.util.HashMap'
import { systemDateTime } from '@kit.BasicServicesKit';

/**
 * 节点信息对象接口
 * 用于解析接收到的节点信息消息
 */
interface NodeInfoObj {
  deviceName: string;
  score: number;
  params: DeviceInfo
}

/**
 * 延迟测试信息对象接口
 * 用于解析延迟测试相关消息
 */
interface LatencyInfoObj {
  deviceName: string;
  timeStamp: number;
}

/**
 * 本设备名称
 * 从MQTT配置中获取客户端ID作为设备名称
 */
const ownName: string = MQTTOption.clientId as string

/**
 * 节点信息同步类
 * 管理设备网络中的节点信息，处理节点信息的发送与接收
 */
class NodeInfoSyn{

  otherNodeInfo:DeviceInfo[] = [];
  lastLatency:number = 1;

  /**
   * 获取其他节点信息
   * 将其他节点信息数组转换为HashMap，便于快速查找
   * @returns 以设备名称为键，设备信息为值的HashMap
   */
  getOtherNodeInfo(): HashMap<string, DeviceInfo> {
    let otherInfo: HashMap<string, DeviceInfo> = new HashMap<string, DeviceInfo>();
    for (let index = 0; index < this.otherNodeInfo.length; index++) {
      otherInfo.set(this.otherNodeInfo[index].deviceName,this.otherNodeInfo[index])
    }
    return otherInfo;
  }

  /**
   * 发送本设备信息
   * 将本设备的系统信息通过MQTT发送到网络中
   * @param nodeInfo
   */
  sendOwnInfo(nodeInfo: DeviceInfo): void {
    const MQTTInstance: MQTTClient = MQTTClient.getInstance()
    const message: string = `
    {
        "deviceName": "${nodeInfo.deviceName}",
        "params": {
            "deviceName": "${nodeInfo.deviceName}",
            "cpuUsage": ${nodeInfo.cpuUsage},
            "memoryUsage": ${nodeInfo.memoryUsage},
            "storageFree": ${nodeInfo.storageFree},
            "batteryLevel": ${nodeInfo.batteryLevel},
            "latency": ${nodeInfo.latency}
        }
    }
    `.trim();

    MQTTInstance.pushMessage(message, "/device/status");
  }

  /**
   * 解析节点信息消息
   * 处理接收到的节点信息，更新或添加到其他节点信息列表
   * @param message 接收到的节点信息消息
   * 消息格式示例：
   * {
   *   "deviceName": "Lenovo TB-J607F",
   *   "score": "0.0",
   *   "params": {
   *     "deviceName": "Lenovo TB-J607F",
   *     "cpuUsage": 0.3389611,
   *     "memoryUsage": 0.5084416,
   *     "storageFree": 0.462,
   *     "batteryLevel": 0.19,
   *     "latency": 10
   *   }
   * }
   */
  parseNodeInfoMessage(message: string) {
    try {
      const nodeInfoObj: NodeInfoObj = JSON.parse(message);
      const newDeviceName: string = nodeInfoObj.deviceName;

      if (ownName != newDeviceName) {
        const params: DeviceInfo = nodeInfoObj.params;
        const newNodeInfo: DeviceInfo = {
          deviceName: newDeviceName,
          cpuUsage: parseFloat(params.cpuUsage.toFixed(2)),
          memoryUsage: parseFloat(params.memoryUsage.toFixed(2)),
          storageFree: parseFloat(params.storageFree.toFixed(2)),
          batteryLevel: parseFloat(params.batteryLevel.toFixed(2)),
          latency: parseFloat(params.latency.toFixed(2))
        };
        this.otherNodeInfo = this.otherNodeInfo.filter(node => node.deviceName !== newDeviceName);
        console.log("device ADD:" + newDeviceName);

        this.otherNodeInfo.push(newNodeInfo);
      } else {
        console.log("device self");
      }
    } catch (e) {
      console.error("Error parsing message:", e);
    }
  }

  /**
   * 发送延迟测试消息
   * 发送包含当前时间戳的消息用于测试网络延迟
   */
  testLatencySend() {
    const MQTTInstance: MQTTClient = MQTTClient.getInstance()
    const timepStamp = systemDateTime.getTime(false);
    const message: string = `
    {
        "deviceName": "${ownName}",
        "timeStamp": "${timepStamp}"
    }
    `.trim();

    MQTTInstance.pushMessage(message, "/test/latency");
  }

  /**
   * 接收延迟测试消息
   * 处理接收到的延迟测试消息，计算网络延迟
   * @param message 接收到的延迟测试消息
   * @returns 固定返回0（保留返回值以保持接口一致性）
   */
  testLatencyRec(message: string) {
    try {
      const latencyInfoObj: LatencyInfoObj = JSON.parse(message);
      const objDeviceName: string = latencyInfoObj.deviceName;

      if (ownName == objDeviceName) {
        const timeStamp: number = latencyInfoObj.timeStamp;
        const newTimepStamp = systemDateTime.getTime(false);
        console.error(`getLatencyLast: ${timeStamp}`);
        console.error(`getLatencyNew: ${newTimepStamp}`);
        let latency = newTimepStamp - timeStamp;
        this.lastLatency = latency;
      } else {
        // TODO 统一日志格式处理，规范格式
        console.log("huoNO");
      }
    } catch (e) {
      console.error("Error parsing message:", e);
    }
    return 0;
  }
}
export const nodeInfoSyn = new NodeInfoSyn();
export {ownName}