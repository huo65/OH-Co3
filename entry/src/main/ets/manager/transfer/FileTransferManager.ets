/**
 * 文件传输管理器
 * 统一管理所有文件传输任务，自动选择传输协议，提供完整的传输管理功能
 */
import { TransferProtocolInterface, TransferState, TransferProgress, TransferConfig } from './protocol/TransferProtocolInterface';
import { ProtocolRegistry } from './protocol/ProtocolRegistry';
import { MQTTTransferProtocol } from './protocol/MQTTTransferProtocol';
import { TCPTransferProtocol } from './protocol/TCPTransferProtocol';
import { FileInfo, TransferTask, TransferOptions, TCPNotifyInfo } from './model/TransferDataModels';
import { NetworkUtils } from './utils/NetworkUtils';
import { TransferEventManager } from './event/TransferEvents';

/**
 * TCP 传输通知回调类型
 * 当 FileTransferManager 选择 TCP 协议时，通过此回调通知调用方向目标设备发送连接信息
 */
export type TCPNotifyCallback = (notifyInfo: TCPNotifyInfo) => Promise<void>;

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
   * 自动选择协议：小文件（≤sizeThreshold）使用 MQTT，大文件使用 TCP
   * @param fileData - 文件数据
   * @param fileInfo - 文件信息
   * @param targetDevice - 目标设备标识
   * @param notifyCallback - TCP 大文件传输时的通知回调，由调用方实现通过 MQTT 通知目标设备发起 TCP 连接
   * @returns 任务 ID
   */
  async transferFile(
    fileData: ArrayBuffer | string,
    fileInfo: FileInfo,
    targetDevice: string,
    notifyCallback?: TCPNotifyCallback
  ): Promise<string> {
    const taskId = `task_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const protocolName = this.selectProtocol(fileInfo.size);
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
      if (protocolName === 'TCP') {
        success = await this.transferViaTCP(
          protocol as TCPTransferProtocol,
          fileData,
          taskId,
          fileInfo,
          notifyCallback
        );
      } else {
        // MQTT 传输：直接发送原始数据
        success = await protocol.send(fileData, taskId);
      }
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
   * 通过 TCP 协议传输文件（发送端）
   * 流程：启动服务器 → 触发 notifyCallback 通知目标设备 → 等待连接 → 发送数据
   * @param protocol - TCP 协议实例
   * @param fileData - 文件数据
   * @param taskId - 任务 ID
   * @param fileInfo - 文件元数据
   * @param notifyCallback - 通知目标设备发起 TCP 连接的回调（由调用方实现）
   */
  private async transferViaTCP(
    protocol: TCPTransferProtocol,
    fileData: ArrayBuffer | string,
    taskId: string,
    fileInfo: FileInfo,
    notifyCallback?: TCPNotifyCallback
  ): Promise<boolean> {
    try {
      const localIp = NetworkUtils.getIpAddress();
      const port = this.defaultOptions.tcpPort!;

      // 启动 TCP 服务器监听（等待目标设备连接）
      if (!protocol.isConnected()) {
        const serverStarted = await protocol.startServer(port);
        if (!serverStarted) {
          throw new Error(`TCP 服务器启动失败，端口=${port}`);
        }
        console.info(`[FileTransferManager] TCP 服务器已启动，监听 ${localIp}:${port}`);
      }

      // 通过回调通知目标设备：请主动连接到 localIp:port 发起 TCP 传输
      if (notifyCallback) {
        const notifyInfo: TCPNotifyInfo = {
          taskId,
          sourceIp: localIp,
          port,
          fileInfo
          // fileHash 将在发送过程中由 TCPTransferProtocol 内部计算填充
        };
        await notifyCallback(notifyInfo);
        console.info(`[FileTransferManager] 已通知目标设备发起 TCP 连接，taskId=${taskId}`);
      } else {
        console.warn(`[FileTransferManager] 未提供 notifyCallback，目标设备可能无法得知需要发起 TCP 连接`);
      }

      // 发送文件数据（等待目标设备连接后发送）
      const config: TransferConfig = {
        chunkSize: this.defaultOptions.tcpChunkSize,
        maxRetries: this.defaultOptions.maxRetries,
        timeout: this.defaultOptions.timeout
      };

      return await protocol.send(fileData, taskId, config);
    } catch (error) {
      console.error('[FileTransferManager] TCP 传输失败:', error);
      return false;
    }
  }

  /**
   * 选择传输协议
   * @param fileSize - 文件大小（字节）
   * @returns 协议名称
   */
  private selectProtocol(fileSize: number): string {
    // const threshold = this.defaultOptions.sizeThreshold!;TODO MQTT协议统一
    //
    // if (fileSize > threshold) {
    //   console.info(`[FileTransferManager] 文件大小 ${fileSize} 字节 > ${threshold} 字节，使用 TCP 协议`);
    //   return 'TCP';
    // } else {
    //   console.info(`[FileTransferManager] 文件大小 ${fileSize} 字节 <= ${threshold} 字节，使用 MQTT协议`);
    //   return 'MQTT';
    // }
    return 'TCP';
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
