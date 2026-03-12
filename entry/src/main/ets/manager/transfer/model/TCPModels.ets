/**
 * TCP 传输专用数据模型
 * 包含 TCP 协议特有的数据结构和类型定义
 */

import { TransferNotifyInfo } from './TransferDataModels';
import { FileInfo, ChunkData } from './TransferDataModels';

/**
 * TCP 消息类型枚举
 * 定义 TCP 传输过程中的各类消息类型
 */
export enum TCPMessageType {
  HANDSHAKE = 'handshake',      // 握手消息
  CHUNK = 'chunk',              // 分块数据
  CHUNK_ACK = 'chunk_ack',      // 分块确认
  COMPLETE = 'complete',        // 传输完成
  ERROR = 'error'               // 错误消息
}

/**
 * TCP 传输通知信息
 * 继承通用传输通知接口，添加 TCP 协议特有字段
 * 发送端启动 TCP 服务器后，将此信息通过 MQTT 通知目标设备发起连接
 */
export interface TCPNotifyInfo extends TransferNotifyInfo {
  /** 源设备 IP 地址（TCP 特有） */
  sourceIp: string;
  /** TCP 监听端口（TCP 特有） */
  port: number;
  /** 时间戳 */
  timestamp: number;
}

/**
 * TCP 传输通知回调类型
 * TCP 服务器就绪后调用，用于通知目标设备发起连接
 * @deprecated 使用 TransferNotifyCallback 替代
 */
export type TCPNotifyCallback = (notifyInfo: TCPNotifyInfo) => Promise<void>;


/**
 * TCP 握手消息（通过 TCP 连接发送）
 * 在 TCP 连接建立后，发送端首先发送握手消息告知文件信息
 */
export interface TCPHandshakeMessage {
  type: TCPMessageType.HANDSHAKE;
  taskId: string;
  fileInfo: FileInfo;
  totalChunks: number;
  chunkSize: number;
  fileHash: string;
}

/**
 * TCP 分块消息
 * 用于传输实际的分块数据
 * data 字段可以是 ArrayBuffer（内部处理）或 string（Base64 编码，网络传输）
 */
export interface TCPChunkMessage {
  type: TCPMessageType.CHUNK;
  taskId: string;
  chunkIndex: number;
  data: ArrayBuffer | string;
  isLastChunk: boolean;
}

/**
 * TCP 分块确认消息
 * 接收端收到分块后发送确认
 */
export interface TCPChunkAckMessage {
  type: TCPMessageType.CHUNK_ACK;
  taskId: string;
  chunkIndex: number;
  success: boolean;
}

/**
 * TCP 完成消息
 * 所有分块传输完成后发送
 */
export interface TCPCompleteMessage {
  type: TCPMessageType.COMPLETE;
  taskId: string;
  fileHash: string;
}

/**
 * TCP 错误消息
 * 传输过程中发生错误时发送
 */
export interface TCPErrorMessage {
  type: TCPMessageType.ERROR;
  taskId: string;
  errorCode: string;
  errorMessage: string;
}

/**
 * TCP 消息通用接口
 */
export type TCPMessage = TCPHandshakeMessage | TCPChunkMessage | TCPChunkAckMessage | TCPCompleteMessage | TCPErrorMessage;

/**
 * 将通用通知信息转换为 TCP 通知信息
 * @param notifyInfo - 通用通知信息
 * @param sourceIp - 源 IP 地址
 * @param port - TCP 端口
 * @returns TCP 通知信息
 */
export function toTCPNotifyInfo(
  notifyInfo: TransferNotifyInfo,
  sourceIp: string,
  port: number
): TCPNotifyInfo {
  const result: TCPNotifyInfo = {
    taskId: notifyInfo.taskId,
    protocol: notifyInfo.protocol,
    sourceDevice: notifyInfo.sourceDevice,
    targetDevice: notifyInfo.targetDevice,
    fileInfo: notifyInfo.fileInfo,
    fileHash: notifyInfo.fileHash,
    sourceIp: sourceIp,
    port: port,
    timestamp: Date.now()
  };
  return result;
}

/**
 * 从 TCP 通知信息提取通用通知信息
 * @param tcpNotifyInfo - TCP 通知信息
 * @returns 通用通知信息
 */
export function fromTCPNotifyInfo(tcpNotifyInfo: TCPNotifyInfo): TransferNotifyInfo {
  const result: TransferNotifyInfo = {
    taskId: tcpNotifyInfo.taskId,
    protocol: tcpNotifyInfo.protocol,
    sourceDevice: tcpNotifyInfo.sourceDevice,
    targetDevice: tcpNotifyInfo.targetDevice,
    fileInfo: tcpNotifyInfo.fileInfo,
    fileHash: tcpNotifyInfo.fileHash
  };
  return result;
}
