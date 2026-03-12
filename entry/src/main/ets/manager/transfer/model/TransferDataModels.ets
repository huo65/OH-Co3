/**
 * 文件传输数据模型定义
 * 包含文件信息、传输任务、进度等核心数据结构
 */

/**
 * 文件元数据信息
 * 描述待传输文件的基本属性
 */
export interface FileInfo {
  /** 文件唯一标识 */
  fileId: string;
  /** 文件名 */
  fileName: string;
  /** 文件大小（字节） */
  size: number;
  /** 文件类型（MIME 类型） */
  fileType?: string;
  /** 文件路径 */
  filePath?: string;
  /** 文件哈希值（用于校验） */
  hash?: string;
  /** 创建时间戳 */
  createdAt?: number;
  /** 最后修改时间戳 */
  modifiedAt?: number;
}

/**
 * 分块数据信息
 * 用于大文件分块传输时的数据组织
 */
export interface ChunkData {
  /** 所属任务 ID */
  taskId: string;
  /** 分块索引（从 0 开始） */
  chunkIndex: number;
  /** 总块数 */
  totalChunks: number;
  /** 当前块数据 */
  data: ArrayBuffer;
  /** 当前块大小 */
  chunkSize: number;
  /** 当前块哈希（用于校验） */
  hash?: string;
  /** 是否为最后一块 */
  isLastChunk: boolean;
}

/**
 * 传输任务状态类型
 */
export type TransferTaskState = 'pending' | 'connecting' | 'transferring' | 'completed' | 'failed' | 'cancelled';

/**
 * 传输任务信息
 * 描述一个完整的文件传输任务
 */
export interface TransferTask {
  /** 任务唯一标识 */
  taskId: string;
  /** 文件信息 */
  fileInfo: FileInfo;
  /** 源设备标识 */
  sourceDevice: string;
  /** 目标设备标识 */
  targetDevice: string;
  /** 使用的传输协议 */
  protocol: string;
  /** 当前传输状态 */
  state: TransferTaskState;
  /** 源设备 IP 地址（TCP 传输时使用） */
  sourceIp?: string;
  /** 目标设备 IP 地址（TCP 传输时使用） */
  targetIp?: string;
  /** 传输端口（TCP 传输时使用） */
  port?: number;
  /** 创建时间戳 */
  createdAt: number;
  /** 开始传输时间戳 */
  startedAt?: number;
  /** 完成时间戳 */
  completedAt?: number;
  /** 重试次数 */
  retryCount?: number;
  /** 错误信息 */
  errorMessage?: string;
}

/**
 * 传输配置选项
 */
export interface TransferOptions {
  /** 文件大小阈值（字节），超过此值使用 TCP 传输，默认 2MB */
  sizeThreshold?: number;
  /** TCP 分块大小（字节），默认 128KB */
  tcpChunkSize?: number;
  /** 最大重试次数，默认 3 次 */
  maxRetries?: number;
  /** 连接超时时间（毫秒），默认 30000ms */
  timeout?: number;
  /** TCP 监听端口，默认 8888 */
  tcpPort?: number;
}

/**
 * 传输就绪通知信息（基础接口）
 * 协议层准备就绪后，通过回调通知调用方传输通道已建立
 * 这是通用接口，各协议可通过继承扩展特有字段
 */
export interface TransferNotifyInfo {
  /** 任务唯一标识 */
  taskId: string;
  /** 协议名称（如 'TCP', 'MQTT', 'HTTP' 等） */
  protocol: string;
  /** 源设备标识（如 IP 地址或设备 ID） */
  sourceDevice: string;
  /** 目标设备标识 */
  targetDevice?: string;
  /** 文件元数据 */
  fileInfo?: FileInfo;
  /** 文件哈希值（用于校验） */
  fileHash?: string;
}

/**
 * 传输就绪通知回调类型（通用）
 * 当传输协议准备就绪后调用，用于通知目标设备可以开始接收数据
 */
export type TransferNotifyCallback = (notifyInfo: TransferNotifyInfo) => Promise<void>;

/**
 * 创建默认文件信息
 * @param fileName - 文件名
 * @param size - 文件大小
 * @returns 文件信息对象
 */
export function createFileInfo(fileName: string, size: number): FileInfo {
  return {
    fileId: generateFileId(),
    fileName,
    size,
    createdAt: Date.now()
  };
}

/**
 * 生成文件唯一标识
 * @returns 文件 ID
 */
export function generateFileId(): string {
  return `file_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

/**
 * 验证文件信息完整性
 * @param fileInfo - 文件信息
 * @returns 是否有效
 */
export function isValidFileInfo(fileInfo: FileInfo): boolean {
  return (
    fileInfo.fileId !== undefined &&
    fileInfo.fileId.length > 0 &&
    fileInfo.fileName !== undefined &&
    fileInfo.fileName.length > 0 &&
    fileInfo.size !== undefined &&
    fileInfo.size >= 0
  );
}
