/**
 * 传输协议接口定义
 * 为所有文件传输协议提供标准化的接口抽象
 */

import { FileInfo, TransferNotifyInfo } from '../model/TransferDataModels';
import { TransferResult } from '../model/TransferResult';

/**
 * 传输状态枚举
 * 描述文件传输任务的生命周期状态
 */
export enum TransferState {
  /** 空闲状态，无传输任务 */
  IDLE = 'idle',
  /** 正在建立连接 */
  CONNECTING = 'connecting',
  /** 正在传输数据 */
  TRANSFERRING = 'transferring',
  /** 传输完成 */
  COMPLETED = 'completed',
  /** 传输失败 */
  FAILED = 'failed',
  /** 传输已取消 */
  CANCELLED = 'cancelled',
  /** 等待中 */
  PENDING = 'pending'
}

/**
 * 传输配置接口
 * 用于初始化传输协议时的参数配置
 */
export interface TransferConfig {
  /** 超时时间（毫秒），默认 30000ms */
  timeout?: number;
  /** 重试次数，默认 3 次 */
  maxRetries?: number;
  /** 分块大小（字节），用于大文件分块传输 */
  chunkSize?: number;
  /** 传输就绪通知回调（可选） */
  notifyCallback?: TransferNotifyCallback;
  /** 文件信息（可选） */
  fileInfo?: FileInfo;
  /** 源设备标识（可选） */
  sourceDevice?: string;
  /** 目标设备标识（可选） */
  targetDevice?: string;
  /** 额外协议参数（用于协议特定配置） */
  protocolParams?: Record<string, Object>;
}

/**
 * 传输就绪通知回调类型
 */
export type TransferNotifyCallback = (notifyInfo: TransferNotifyInfo) => Promise<void>;

/**
 * 传输进度信息
 * 用于实时报告传输任务的执行情况
 */
export interface TransferProgress {
  /** 任务唯一标识 */
  taskId: string;
  /** 当前状态 */
  state: TransferState;
  /** 已传输字节数 */
  transferredBytes: number;
  /** 总字节数 */
  totalBytes: number;
  /** 传输进度百分比 (0-100) */
  progress: number;
  /** 传输速度（字节/秒） */
  speed?: number;
  /** 预计剩余时间（秒） */
  estimatedTimeRemaining?: number;
  /** 错误信息（仅在失败状态） */
  error?: string;
}

/**
 * 传输协议接口
 * 所有文件传输协议必须实现此接口
 */
export interface TransferProtocolInterface {
  /**
   * 获取协议名称
   * @returns 协议名称标识符
   */
  getProtocolName(): string;

  /**
   * 连接到目标设备
   * @param host - 目标主机地址
   * @param port - 目标端口
   * @param config - 传输配置
   * @returns 连接结果
   */
  connect(host: string, port: number, config?: TransferConfig): Promise<TransferResult<boolean>>;

  /**
   * 断开连接
   * @returns 断开操作结果
   */
  disconnect(): Promise<TransferResult<boolean>>;

  /**
   * 检查连接状态
   * @returns 是否已连接
   */
  isConnected(): boolean;

  /**
   * 发送数据
   * @param data - 要发送的数据
   * @param taskId - 任务 ID
   * @param transferConfig - 传输配置
   * @returns 发送结果
   */
  send(data: ArrayBuffer | string, taskId: string, transferConfig?: TransferConfig): Promise<TransferResult<boolean>>;

  /**
   * 接收数据
   * @param taskId - 任务 ID
   * @returns 接收结果，包含接收到的数据
   */
  receive(taskId: string): Promise<TransferResult<ArrayBuffer | string>>;

  /**
   * 获取当前传输进度
   * @param taskId - 任务 ID
   * @returns 传输进度信息
   */
  getProgress(taskId: string): TransferProgress;

  /**
   * 取消传输任务
   * @param taskId - 任务 ID
   * @returns 取消操作结果
   */
  cancel(taskId: string): Promise<TransferResult<boolean>>;

  /**
   * 初始化协议
   * 在协议注册后调用，用于初始化协议所需的资源
   * @returns 初始化结果
   */
  initialize?(): Promise<TransferResult<boolean>>;

  /**
   * 销毁协议
   * 在协议注销前调用，用于清理协议资源
   * @returns 销毁结果
   */
  destroy?(): Promise<TransferResult<boolean>>;
}

/**
 * 协议能力接口
 * 描述协议支持的功能特性
 */
export interface ProtocolCapabilities {
  /** 是否支持大文件传输 */
  supportsLargeFiles: boolean;
  /** 最大支持文件大小（字节），0 表示无限制 */
  maxFileSize: number;
  /** 是否支持分块传输 */
  supportsChunking: boolean;
  /** 默认分块大小（字节） */
  defaultChunkSize: number;
  /** 是否支持断点续传 */
  supportsResume: boolean;
  /** 是否支持传输进度回调 */
  supportsProgress: boolean;
  /** 是否支持取消传输 */
  supportsCancellation: boolean;
  /** 是否需要目标设备主动连接（如 TCP 服务器模式） */
  requiresActiveConnection: boolean;
}

/**
 * 可查询能力的协议接口
 */
export interface CapableProtocolInterface extends TransferProtocolInterface {
  /**
   * 获取协议能力信息
   * @returns 协议能力描述
   */
  getCapabilities(): ProtocolCapabilities;
}
