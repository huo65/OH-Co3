/**
 * 文件传输管理器
 * 统一管理所有文件传输任务，由调用方显式指定传输协议，提供完整的传输管理功能
 */
import { TransferProtocolInterface, TransferState, TransferProgress, TransferConfig } from './protocol/TransferProtocolInterface';
import { ProtocolRegistry } from './protocol/ProtocolRegistry';
import { MQTTTransferProtocol } from './protocol/MQTTTransferProtocol';
import { TCPTransferProtocol } from './protocol/TCPTransferProtocol';
import { FileInfo, TransferTask, TransferOptions } from './model/TransferDataModels';
import { TCPNotifyCallback, TCPTransferConfig } from './model/TCPModels';
import { NetworkUtils } from './utils/NetworkUtils';
import { TransferEventManager } from './event/TransferEvents';

/**
 * TCP 传输通知回调类型——重新导出以保持向后兼容
 * 实际定义在 TCPModels.ets 中
 */
export { TCPNotifyCallback };

/**
 * 文件传输管理器类
 * 提供统一的文件传输管理接口
 */
export class FileTransferManager {
  private static instance: FileTransferManager;
  
  /** 协议注册中心 */
  private protocolRegistry: ProtocolRegistry;
  
  /** 事件管理器 */
  private eventManager: TransferEventManager;
  
  /** 传输任务队列 */
  private taskQueue: Map<string, TransferTask> = new Map();
  
  /** 默认配置 */
  private defaultOptions: TransferOptions = {
    sizeThreshold: 2 * 1024 * 1024, // 2MB
    tcpChunkSize: 128 * 1024,       // 128KB
    maxRetries: 3,
    timeout: 30000,
    tcpPort: 8888
  };

  private constructor() {
    this.protocolRegistry = ProtocolRegistry.getInstance();
    this.eventManager = TransferEventManager.getInstance();
    
    // 初始化时注册默认协议
    this.registerDefaultProtocols();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): FileTransferManager {
    if (!FileTransferManager.instance) {
      FileTransferManager.instance = new FileTransferManager();
    }
    return FileTransferManager.instance;
  }

  /**
   * 注册默认协议
   */
  private registerDefaultProtocols(): void {
    try {
      // 注册 MQTT协议
      const mqttProtocol = new MQTTTransferProtocol();
      this.protocolRegistry.registerProtocol('MQTT', mqttProtocol);
      
      // 注册 TCP 协议
      const tcpProtocol = new TCPTransferProtocol();
      this.protocolRegistry.registerProtocol('TCP', tcpProtocol);
      
      console.info('[FileTransferManager] 默认协议注册完成');
    } catch (error) {
      console.error('[FileTransferManager] 协议注册失败:', error);
    }
  }

  /**
   * 设置默认配置
   * @param options - 配置选项
   */
  setDefaultOptions(options: TransferOptions): void {
    if (options.sizeThreshold !== undefined) {
      this.defaultOptions.sizeThreshold = options.sizeThreshold;
    }
    if (options.tcpChunkSize !== undefined) {
      this.defaultOptions.tcpChunkSize = options.tcpChunkSize;
    }
    if (options.maxRetries !== undefined) {
      this.defaultOptions.maxRetries = options.maxRetries;
    }
    if (options.timeout !== undefined) {
      this.defaultOptions.timeout = options.timeout;
    }
    if (options.tcpPort !== undefined) {
      this.defaultOptions.tcpPort = options.tcpPort;
    }
    console.info('[FileTransferManager] 默认配置已更新');
  }

  /**
   * 发起文件传输
   * 调用方通过 protocolName 显式指定协议，如需 TCP 服务器模式传输，可将 notifyCallback 嵌入 config 传入
   * 协议内部自行处理传输全流程，FileTransferManager 层无需感知具体协议实现细节
   * @param fileData - 文件数据
   * @param fileInfo - 文件信息
   * @param targetDevice - 目标设备标识
   * @param protocolName - 指定使用的传输协议名称（需已在 ProtocolRegistry 中注册）
   * @param notifyCallback - TCP 服务器就绪后的通知回调，用于通知目标设备发起连接（如不使用 TCP 可不传）
   * @returns 任务 ID
   */
  async transferFile(
    fileData: ArrayBuffer | string,
    fileInfo: FileInfo,
    targetDevice: string,
    protocolName: string,
    notifyCallback?: TCPNotifyCallback
  ): Promise<string> {
    // 优先复用调用方传入的业务 taskId（fileInfo.fileId），避免重复生成导致追踪不一致
    const taskId = fileInfo.fileId && fileInfo.fileId.length > 0
      ? fileInfo.fileId
      : `task_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    console.info(`[FileTransferManager] 任务 ${taskId} 使用协议：${protocolName}`);

    const task: TransferTask = {
      taskId,
      fileInfo,
      sourceDevice: NetworkUtils.getIpAddress(),
      targetDevice,
      protocol: protocolName,
      state: 'pending',
      createdAt: Date.now()
    };
    this.taskQueue.set(taskId, task);

    const protocol = this.protocolRegistry.getProtocol(protocolName);
    if (!protocol) {
      task.state = 'failed';
      this.eventManager.emitTransferFailed(taskId, `协议 ${protocolName} 未找到`);
      throw new Error(`协议 ${protocolName} 未找到`);
    }

    this.eventManager.emitTransferStart(taskId, protocolName);
    task.state = 'transferring';
    task.startedAt = Date.now();

    let success = false;
    try {
      // 构造传输配置
      // 对于 TCP 协议，notifyCallback 用于通知目标设备发起连接
      // 对于 MQTT 协议，notifyCallback 会被忽略
      const sendConfig: TCPTransferConfig = {
        chunkSize: this.defaultOptions.tcpChunkSize,
        maxRetries: this.defaultOptions.maxRetries,
        timeout: this.defaultOptions.timeout,
        notifyCallback
      };
      success = await protocol.send(fileData, taskId, sendConfig);
    } catch (error) {
      const errMsg: string = error instanceof Error ? error.message : String(error);
      task.state = 'failed';
      this.eventManager.emitTransferFailed(taskId, errMsg);
      console.error('[FileTransferManager] 传输异常:', errMsg);
      throw new Error(errMsg);
    }

    if (success) {
      task.state = 'completed';
      task.completedAt = Date.now();
      interface CompleteResult {
        fileInfo: FileInfo;
        duration: number;
      }
      const completeResult: CompleteResult = {
        fileInfo,
        duration: task.completedAt - (task.startedAt ?? task.completedAt)
      };
      this.eventManager.emitTransferComplete(taskId, completeResult);
      console.info(`[FileTransferManager] 传输完成，taskId=${taskId}`);
    } else {
      task.state = 'failed';
      this.eventManager.emitTransferFailed(taskId, '传输失败');
      console.error(`[FileTransferManager] 传输失败，taskId=${taskId}`);
    }

    return taskId;
  }

  /**
   * 接收文件（接收端入口）
   * 目标设备收到 TCP 传输通知后，调用此方法主动连接源设备并接收文件数据
   * @param taskId - 任务 ID
   * @param sourceIp - 源设备 IP 地址
   * @param fileInfo - 文件元数据
   * @param options - 可选传输配置
   * @returns 接收到的文件数据
   */
  async receiveFile(
    taskId: string,
    sourceIp: string,
    fileInfo: FileInfo,
    options?: TransferOptions
  ): Promise<ArrayBuffer | string> {
    const port = options?.tcpPort ?? this.defaultOptions.tcpPort!;
    console.info(`[FileTransferManager] 开始接收文件，taskId=${taskId}, sourceIp=${sourceIp}:${port}`);

    // 记录接收任务
    const task: TransferTask = {
      taskId,
      fileInfo,
      sourceDevice: sourceIp,
      targetDevice: NetworkUtils.getIpAddress(),
      protocol: 'TCP',
      state: 'transferring',
      sourceIp,
      port,
      createdAt: Date.now(),
      startedAt: Date.now()
    };
    this.taskQueue.set(taskId, task);

    const protocol = this.protocolRegistry.getProtocol('TCP') as TCPTransferProtocol | undefined;
    if (!protocol) {
      task.state = 'failed';
      this.eventManager.emitTransferFailed(taskId, 'TCP 协议未注册');
      throw new Error('TCP 协议未注册');
    }

    this.eventManager.emitTransferStart(taskId, 'TCP');

    try {
      // 主动发起 TCP 连接到源设备
      const config: TransferConfig = {
        chunkSize: options?.tcpChunkSize ?? this.defaultOptions.tcpChunkSize,
        maxRetries: options?.maxRetries ?? this.defaultOptions.maxRetries,
        timeout: options?.timeout ?? this.defaultOptions.timeout
      };
      const connected = await protocol.connect(sourceIp, port, config);
      if (!connected) {
        throw new Error(`无法连接到源设备 ${sourceIp}:${port}`);
      }

      // 接收文件数据
      const fileData = await protocol.receive(taskId);

      task.state = 'completed';
      task.completedAt = Date.now();
      interface CompleteResult {
        fileInfo: FileInfo;
        duration: number;
      }
      const completeResult: CompleteResult = {
        fileInfo,
        duration: task.completedAt - (task.startedAt ?? task.completedAt)
      };
      this.eventManager.emitTransferComplete(taskId, completeResult);
      console.info(`[FileTransferManager] 文件接收完成，taskId=${taskId}`);

      return fileData;
    } catch (error) {
      const errMsg: string = error instanceof Error ? error.message : String(error);
      task.state = 'failed';
      this.eventManager.emitTransferFailed(taskId, errMsg);
      console.error('[FileTransferManager] 文件接收失败:', errMsg);
      throw new Error(errMsg);
    }
  }

  /**
   * 取消传输任务
   * @param taskId - 任务 ID
   * @returns 是否取消成功
   */
  async cancelTransfer(taskId: string): Promise<boolean> {
    const task = this.taskQueue.get(taskId);
    if (!task) {
      console.warn(`[FileTransferManager] 任务不存在：${taskId}`);
      return false;
    }

    try {
      // 获取协议实例
      const protocol = this.protocolRegistry.getProtocol(task.protocol);
      if (protocol) {
        await protocol.cancel(taskId);
      }
      
      // 更新任务状态
      task.state = 'cancelled';
      
      // 触发取消事件
      this.eventManager.emitTransferCancelled(taskId);
      
      console.info(`[FileTransferManager] 任务已取消，taskId=${taskId}`);
      return true;
    } catch (error) {
      console.error('[FileTransferManager] 取消任务失败:', error);
      return false;
    }
  }

  /**
   * 获取传输进度
   * @param taskId - 任务 ID
   * @returns 传输进度信息
   */
  getTransferProgress(taskId: string): TransferProgress | null {
    const task = this.taskQueue.get(taskId);
    if (!task) {
      console.warn(`[FileTransferManager] 任务不存在：${taskId}`);
      return null;
    }

    // 获取协议实例
    const protocol = this.protocolRegistry.getProtocol(task.protocol);
    if (protocol) {
      return protocol.getProgress(taskId);
    }
    
    return null;
  }

  /**
   * 获取任务状态
   * @param taskId - 任务 ID
   * @returns 任务状态
   */
  getTransferState(taskId: string): string | null {
    const task = this.taskQueue.get(taskId);
    return task ? task.state : null;
  }

  /**
   * 获取所有任务
   * @returns 任务数组
   */
  getAllTasks(): TransferTask[] {
    return Array.from(this.taskQueue.values());
  }

  /**
   * 获取活动任务
   * @returns 活动任务数组
   */
  getActiveTasks(): TransferTask[] {
    return Array.from(this.taskQueue.values()).filter(
      task => task.state === 'pending' || task.state === 'transferring'
    );
  }

  /**
   * 清理已完成的任务
   */
  cleanupCompletedTasks(): void {
    const now = Date.now();
    const oneHourAgo = 60 * 60 * 1000; // 1 小时
    
    const taskIds: string[] = Array.from(this.taskQueue.keys());
    for (let i = 0; i < taskIds.length; i++) {
      const taskId = taskIds[i];
      const task = this.taskQueue.get(taskId);
      if (!task) {
        continue;
      }
      if (task.state === 'completed' || task.state === 'cancelled' || task.state === 'failed') {
        // 超过 1 小时的任务清理掉
        if (task.completedAt && (now - task.completedAt > oneHourAgo)) {
          this.taskQueue.delete(taskId);
          console.info(`[FileTransferManager] 清理已完成任务：${taskId}`);
        }
      }
    }
  }

  /**
   * 注册自定义协议
   * @param protocolName - 协议名称
   * @param protocol - 协议实现
   */
  registerCustomProtocol(protocolName: string, protocol: TransferProtocolInterface): void {
    this.protocolRegistry.registerProtocol(protocolName, protocol);
    console.info(`[FileTransferManager] 自定义协议 ${protocolName} 注册成功`);
  }

  /**
   * 注销协议
   * @param protocolName - 协议名称
   */
  unregisterProtocol(protocolName: string): void {
    this.protocolRegistry.unregisterProtocol(protocolName);
    console.info(`[FileTransferManager] 协议 ${protocolName} 已注销`);
  }

  /**
   * 列出所有可用协议
   * @returns 协议名称数组
   */
  listProtocols(): string[] {
    return this.protocolRegistry.listProtocols();
  }
}
