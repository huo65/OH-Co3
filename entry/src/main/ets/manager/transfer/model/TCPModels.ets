/**
 * TCP 传输专用数据模型
 * 包含 TCP 协议特有的数据结构和类型定义
 */

import { TransferConfig } from '../protocol/TransferProtocolInterface';
import { FileInfo } from './TransferDataModels';

/**
 * TCP 传输通知信息
 * 发送端启动 TCP 服务器后，将此信息通过 MQTT 通知目标设备发起连接
 */
export interface TCPNotifyInfo {
  /** 任务 ID */
  taskId: string;
  /** 源设备 IP 地址 */
  sourceIp: string;
  /** TCP 监听端口 */
  port: number;
  /** 文件元数据 */
  fileInfo: FileInfo;
  /** 文件哈希值（用于校验） */
  fileHash?: string;
}

/**
 * TCP 传输通知回调类型
 * TCP 服务器就绪后调用，用于通知目标设备发起连接
 */
export type TCPNotifyCallback = (notifyInfo: TCPNotifyInfo) => Promise<void>;

/**
 * TCP 传输配置接口
 * 扩展通用 TransferConfig，添加 TCP 协议特有的配置项
 */
export interface TCPTransferConfig extends TransferConfig {
  /**
   * TCP 服务器就绪后的通知回调
   * 由 TCPTransferProtocol.send 在服务器启动后调用，调用方需实现此回调以通知目标设备发起连接
   */
  notifyCallback?: TCPNotifyCallback;
}
