/**
 * TCP 传输专用数据模型
 * 包含 TCP 协议特有的数据结构和类型定义
 */

import { TransferConfig } from '../protocol/TransferProtocolInterface';
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
