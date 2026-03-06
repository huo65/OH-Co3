/**
 * 传输协议接口定义
 * 为所有文件传输协议提供标准化的接口抽象
 */
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
  CANCELLED = "CANCELLED"
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
}

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
   * @returns 连接是否成功
   */
  connect(host: string, port: number, config?: TransferConfig): Promise<boolean>;

  /**
   * 断开连接
   * @returns 断开操作是否成功
   */
  disconnect(): Promise<boolean>;

  /**
   * 检查连接状态
   * @returns 是否已连接
   */
  isConnected(): boolean;

  /**
   * 发送数据
   * @param data - 要发送的数据
   * @param taskId - 任务 ID
   * @returns 发送是否成功
   */
  send(data: ArrayBuffer | string, taskId: string): Promise<boolean>;

  /**
   * 接收数据
   * @param taskId - 任务 ID
   * @returns 接收到的数据
   */
  receive(taskId: string): Promise<ArrayBuffer | string>;

  /**
   * 获取当前传输进度
   * @param taskId - 任务 ID
   * @returns 传输进度信息
   */
  getProgress(taskId: string): TransferProgress;

  /**
   * 取消传输任务
   * @param taskId - 任务 ID
   * @returns 取消是否成功
   */
  cancel(taskId: string): Promise<boolean>;
}
