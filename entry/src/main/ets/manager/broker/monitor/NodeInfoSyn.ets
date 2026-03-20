/**
 * 节点信息同步模块
 * 负责设备节点信息的发送、接收与管理，以及网络延迟测试
 */
import { DeviceInfo } from '../../monitor/SystemProfiler'
import { MQTTClient } from '../MQTTClient'
import HashMap from '@ohos.util.HashMap'
import { systemDateTime } from '@kit.BasicServicesKit';
import { getDeviceId } from '../../config/DeviceIdentifier';

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
 * 在线设备列表对象接口
 * 用于解析在线设备列表消息
 */
interface DeviceListObj {
  aliveDevice: string[];
}

/**
 * 节点信息同步类
 * 管理设备网络中的节点信息，处理节点信息的发送与接收
 * 使用统一的设备标识管理模块获取本设备标识
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
      const ownDeviceId: string = getDeviceId();

      if (ownDeviceId != newDeviceName) {
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
        // console.info(`[HarmonyInference] [NodeInfoSyn] 新设备节点加入网络: ${newDeviceName}`);

        this.otherNodeInfo.push(newNodeInfo);
      } else {
        // console.info(`[HarmonyInference] [NodeInfoSyn] 忽略本设备自身状态广播`);
      }
    } catch (e) {
      console.error(`[HarmonyInference] [NodeInfoSyn] 解析节点信息消息失败: ${e}`);
    }
  }

  /**
   * 发送延迟测试消息
   * 发送包含当前时间戳的消息用于测试网络延迟
   */
  testLatencySend() {
    const MQTTInstance: MQTTClient = MQTTClient.getInstance()
    const timepStamp = systemDateTime.getTime(false);
    const ownDeviceId: string = getDeviceId();
    const message: string = `
    {
        "deviceName": "${ownDeviceId}",
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
      const ownDeviceId: string = getDeviceId();

      if (ownDeviceId == objDeviceName) {
        const timeStamp: number = latencyInfoObj.timeStamp;
        const newTimepStamp = systemDateTime.getTime(false);
        let latency = newTimepStamp - timeStamp;
        this.lastLatency = latency;
        console.info(`[HarmonyInference] [NodeInfoSyn] 网络延迟测试完成: ${latency}ms`);
      } else {
        // console.info(`[HarmonyInference] [NodeInfoSyn] 忽略其他设备的延迟测试响应，来源: ${objDeviceName}`);
      }
    } catch (e) {
      console.error(`[HarmonyInference] [NodeInfoSyn] 解析延迟测试消息失败: ${e}`);
    }
    return 0;
  }

  /**
   * 解析在线设备列表消息
   * 根据在线设备列表清理已离线的设备信息
   * @param message 接收到的在线设备列表消息
   * 消息格式示例：
   * {
   *   "aliveDevice": ["OH-RockchipRK366-3ea84890", "OH-RockchipRK366-8ce6f84e", "test1"]
   * }
   */
  parseDeviceListMessage(message: string): void {
    try {
      const deviceListObj: DeviceListObj = JSON.parse(message);
      const aliveDevices: string[] = deviceListObj.aliveDevice;
      const ownDeviceId: string = getDeviceId();

      if (!aliveDevices || !Array.isArray(aliveDevices)) {
        console.warn(`[HarmonyInference] [NodeInfoSyn] 在线设备列表格式无效`);
        return;
      }

      // 创建在线设备集合，便于快速查找
      const aliveDeviceSet = new Set<string>(aliveDevices);

      // 记录清理前的设备数量
      const beforeCount = this.otherNodeInfo.length;

      // 过滤掉不在在线列表中的设备
      this.otherNodeInfo = this.otherNodeInfo.filter(node => {
        const isAlive = aliveDeviceSet.has(node.deviceName);
        if (!isAlive) {
          console.info(`[HarmonyInference] [NodeInfoSyn] 清理离线设备: ${node.deviceName}`);
        }
        return isAlive;
      });

      const cleanedCount = beforeCount - this.otherNodeInfo.length;
      if (cleanedCount > 0) {
        console.info(`[HarmonyInference] [NodeInfoSyn] 设备清理完成，清理数量: ${cleanedCount}，剩余设备: ${this.otherNodeInfo.length}`);
      }
    } catch (e) {
      console.error(`[HarmonyInference] [NodeInfoSyn] 解析在线设备列表消息失败: ${e}`);
    }
  }

  /**
   * 获取当前维护的其他设备数量
   * @returns 其他设备数量
   */
  getOtherDeviceCount(): number {
    return this.otherNodeInfo.length;
  }
}
export const nodeInfoSyn = new NodeInfoSyn();