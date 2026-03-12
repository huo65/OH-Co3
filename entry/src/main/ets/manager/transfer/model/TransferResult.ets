/**
 * 文件传输结果类型定义
 * 提供统一的传输结果结构和错误码体系
 */

import { FileInfo } from './TransferDataModels';
import { TransferState, TransferProgress } from '../protocol/TransferProtocolInterface';

/**
 * 传输错误码枚举
 * 定义所有可能的传输错误类型
 */
export enum TransferErrorCode {
  // 成功
  SUCCESS = 'SUCCESS',
  
  // 通用错误 (1xxx)
  UNKNOWN_ERROR = '1000',
  INVALID_PARAMETER = '1001',
  OPERATION_CANCELLED = '1002',
  TIMEOUT = '1003',
  NETWORK_ERROR = '1004',
  
  // 协议错误 (2xxx)
  PROTOCOL_NOT_FOUND = '2000',
  PROTOCOL_NOT_SUPPORTED = '2001',
  PROTOCOL_INITIALIZATION_FAILED = '2002',
  
  // 连接错误 (3xxx)
  CONNECTION_FAILED = '3000',
  CONNECTION_LOST = '3001',
  CONNECTION_TIMEOUT = '3002',
  CONNECTION_REJECTED = '3003',
  
  // 传输错误 (4xxx)
  TRANSFER_FAILED = '4000',
  TRANSFER_INTERRUPTED = '4001',
  SEND_FAILED = '4002',
  RECEIVE_FAILED = '4003',
  
  // 文件错误 (5xxx)
  FILE_NOT_FOUND = '5000',
  FILE_TOO_LARGE = '5001',
  FILE_CORRUPTED = '5002',
  FILE_HASH_MISMATCH = '5003',
  
  // 分块传输错误 (6xxx)
  CHUNK_SEND_FAILED = '6000',
  CHUNK_RECEIVE_FAILED = '6001',
  CHUNK_OUT_OF_ORDER = '6002',
  CHUNK_MISSING = '6003',
  
  // 服务器错误 (7xxx)
  SERVER_START_FAILED = '7000',
  SERVER_NOT_RUNNING = '7001',
  
  // MQTT 特定错误 (8xxx)
  MQTT_NOT_CONNECTED = '8000',
  MQTT_PUBLISH_FAILED = '8001',
  
  // TCP 特定错误 (9xxx)
  TCP_HANDSHAKE_FAILED = '9000',
  TCP_SERVER_BUSY = '9001'
}

/**
 * 传输错误信息接口
 */
export interface TransferError {
  /** 错误码 */
  code: TransferErrorCode;
  /** 错误消息 */
  message: string;
  /** 错误详情（可选） */
  details?: string;
  /** 原始错误（可选） */
  cause?: Error;
  /** 发生时间戳 */
  timestamp: number;
}

/**
 * 传输结果接口
 * 统一的传输操作返回结构
 */
export interface TransferResult<T = void> {
  /** 是否成功 */
  success: boolean;
  /** 错误信息（失败时） */
  error?: TransferError;
  /** 返回数据（成功时） */
  data?: T;
  /** 任务 ID */
  taskId: string;
  /** 传输状态 */
  state: TransferState;
  /** 操作时间戳 */
  timestamp: number;
}

/**
 * 文件传输完成结果
 */
export interface FileTransferCompleteResult {
  /** 文件信息 */
  fileInfo: FileInfo;
  /** 传输持续时间（毫秒） */
  duration: number;
  /** 传输的字节数 */
  transferredBytes: number;
  /** 平均传输速度（字节/秒） */
  averageSpeed: number;
  /** 使用的协议 */
  protocol: string;
  /** 文件哈希（如果计算了） */
  fileHash?: string;
}

/**
 * 传输任务状态信息
 */
export interface TransferTaskStatus {
  /** 任务 ID */
  taskId: string;
  /** 当前状态 */
  state: TransferState;
  /** 传输进度 */
  progress: TransferProgress;
  /** 错误信息（如果失败） */
  error?: TransferError;
  /** 开始时间 */
  startedAt?: number;
  /** 完成时间 */
  completedAt?: number;
  /** 已重试次数 */
  retryCount: number;
}

/**
 * 创建成功结果
 * @param taskId - 任务 ID
 * @param data - 返回数据
 * @returns 成功结果对象
 */
export function createSuccessResult<T>(taskId: string, data?: T): TransferResult<T> {
  return {
    success: true,
    taskId,
    data,
    state: TransferState.COMPLETED,
    timestamp: Date.now()
  };
}

/**
 * 创建失败结果
 * @param taskId - 任务 ID
 * @param code - 错误码
 * @param message - 错误消息
 * @param details - 错误详情
 * @param cause - 原始错误
 * @returns 失败结果对象
 */
export function createErrorResult(
  taskId: string,
  code: TransferErrorCode,
  message: string,
  details?: string,
  cause?: Error
): TransferResult<never> {
  return {
    success: false,
    taskId,
    error: {
      code,
      message,
      details,
      cause,
      timestamp: Date.now()
    },
    state: TransferState.FAILED,
    timestamp: Date.now()
  };
}

/**
 * 创建传输错误对象
 * @param code - 错误码
 * @param message - 错误消息
 * @param details - 错误详情
 * @param cause - 原始错误
 * @returns 传输错误对象
 */
export function createTransferError(
  code: TransferErrorCode,
  message: string,
  details?: string,
  cause?: Error
): TransferError {
  return {
    code,
    message,
    details,
    cause,
    timestamp: Date.now()
  };
}

/**
 * 从异常创建传输错误
 * @param error - 异常对象
 * @param defaultCode - 默认错误码
 * @returns 传输错误对象
 */
export function errorFromException(
  error: Error,
  defaultCode: TransferErrorCode = TransferErrorCode.UNKNOWN_ERROR
): TransferError {
  if (error instanceof Error) {
    return {
      code: defaultCode,
      message: error.message,
      cause: error,
      timestamp: Date.now()
    };
  }
  return {
    code: defaultCode,
    message: String(error),
    timestamp: Date.now()
  };
}

/**
 * 获取错误码对应的默认消息
 * @param code - 错误码
 * @returns 默认错误消息
 */
export function getDefaultErrorMessage(code: TransferErrorCode): string {
  const messages: Record<TransferErrorCode, string> = {
    [TransferErrorCode.SUCCESS]: '操作成功',
    [TransferErrorCode.UNKNOWN_ERROR]: '未知错误',
    [TransferErrorCode.INVALID_PARAMETER]: '参数无效',
    [TransferErrorCode.OPERATION_CANCELLED]: '操作已取消',
    [TransferErrorCode.TIMEOUT]: '操作超时',
    [TransferErrorCode.NETWORK_ERROR]: '网络错误',
    [TransferErrorCode.PROTOCOL_NOT_FOUND]: '协议未找到',
    [TransferErrorCode.PROTOCOL_NOT_SUPPORTED]: '协议不支持',
    [TransferErrorCode.PROTOCOL_INITIALIZATION_FAILED]: '协议初始化失败',
    [TransferErrorCode.CONNECTION_FAILED]: '连接失败',
    [TransferErrorCode.CONNECTION_LOST]: '连接丢失',
    [TransferErrorCode.CONNECTION_TIMEOUT]: '连接超时',
    [TransferErrorCode.CONNECTION_REJECTED]: '连接被拒绝',
    [TransferErrorCode.TRANSFER_FAILED]: '传输失败',
    [TransferErrorCode.TRANSFER_INTERRUPTED]: '传输中断',
    [TransferErrorCode.SEND_FAILED]: '发送失败',
    [TransferErrorCode.RECEIVE_FAILED]: '接收失败',
    [TransferErrorCode.FILE_NOT_FOUND]: '文件未找到',
    [TransferErrorCode.FILE_TOO_LARGE]: '文件过大',
    [TransferErrorCode.FILE_CORRUPTED]: '文件损坏',
    [TransferErrorCode.FILE_HASH_MISMATCH]: '文件哈希不匹配',
    [TransferErrorCode.CHUNK_SEND_FAILED]: '分块发送失败',
    [TransferErrorCode.CHUNK_RECEIVE_FAILED]: '分块接收失败',
    [TransferErrorCode.CHUNK_OUT_OF_ORDER]: '分块顺序错误',
    [TransferErrorCode.CHUNK_MISSING]: '分块缺失',
    [TransferErrorCode.SERVER_START_FAILED]: '服务器启动失败',
    [TransferErrorCode.SERVER_NOT_RUNNING]: '服务器未运行',
    [TransferErrorCode.MQTT_NOT_CONNECTED]: 'MQTT 未连接',
    [TransferErrorCode.MQTT_PUBLISH_FAILED]: 'MQTT 发布失败',
    [TransferErrorCode.TCP_HANDSHAKE_FAILED]: 'TCP 握手失败',
    [TransferErrorCode.TCP_SERVER_BUSY]: 'TCP 服务器繁忙'
  };
  return messages[code] || '未知错误';
}
